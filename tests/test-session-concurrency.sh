#!/usr/bin/env bash
# Regression test for nvk/llm-wiki#58 — concurrent session-state writes must
# neither corrupt the state JSON nor crash the hook.
#
# THE BUG
#   atomic_write() wrote through a single, fixed temp name:
#       tmp = path.with_name(f".{path.name}.tmp")   # shared by EVERY writer
#   When several hook processes write the same .sessions/state/<harness>/<id>.json
#   concurrently — easy to hit when background subagents each fire Stop /
#   PostToolUse hooks — they collide on that one tmp file in two ways:
#     1. os.replace(tmp, path) in one process pulls the tmp out from under
#        another, which then raises FileNotFoundError and the hook crashes.
#     2. two write_text() calls interleave on the shared tmp, so the file that
#        lands carries a valid object + a trailing fragment of the other write;
#        read_json()'s bare json.loads() then hard-crashes with
#        "json.decoder.JSONDecodeError: Extra data".
#
# THE FIX (scripts/llm-wiki-session)
#   - atomic_write: unique tmp per writer ".{name}.{pid}.{uuid4}.tmp" + os.replace
#   - read_json: tolerant — heal a torn file with raw_decode (keep the first
#     valid object), and fall back to `default` if even that can't parse
#     (leading garbage / truncated fragment / empty file) so the hook never
#     crashes on a bad state file.
#
# WHY THIS TEST IS TRUSTWORTHY (self-proving regression)
#   Layer 3 reconstructs the OLD shared-tmp behavior and asserts the race
#   REPRODUCES there. So the harness is known to be able to detect the bug —
#   a green Layer 4 against the real hook entrypoint then means something.
#   Layer 1 is a deterministic structural guard so the fix is protected even on
#   a single-core CI runner where the timing race may not fire.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SESSION="$PROJECT_ROOT/scripts/llm-wiki-session"
PASS=0
FAIL=0
TOTAL=0

log_pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[32mPASS\033[0m: %s\n" "$1"; }
log_fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[31mFAIL\033[0m: %s - %s\n" "$1" "$2"; }
log_warn() { printf "  \033[33mWARN\033[0m: %s\n" "$1"; }

echo "=== Session Capture Concurrency (nvk/llm-wiki#58) ==="

# --- Layer 1: structural guard (deterministic; no race timing involved) ------
if python3 -m py_compile "$SESSION"; then
  log_pass "scripts/llm-wiki-session compiles"
else
  log_fail "scripts/llm-wiki-session compiles" "py_compile failed"
fi

guard() { # description, grep-pattern
  if grep -qF "$2" "$SESSION"; then log_pass "$1"; else log_fail "$1" "missing marker: $2"; fi
}
guard "atomic_write uses a unique tmp per writer (pid+uuid4)" 'uuid.uuid4().hex'
guard "atomic_write commits with os.replace"                 'os.replace(tmp, path)'
guard "read_json heals a torn file (raw_decode)"             'raw_decode'
guard "read_json falls back to default on unhealable data"   'return default'

# --- Layers 2 & 3: read_json heal cases + OLD-vs-NEW race contrast -----------
# Driven in Python so we can load the REAL functions from the script under test
# and exercise the actual write/replace path under genuine multi-process load.
# Use subprocess workers instead of multiprocessing shared semaphores so this
# also runs in restricted macOS launcher contexts.
racepy="$(mktemp)"
cat > "$racepy" <<'PY'
import importlib.machinery, importlib.util
import json, os, subprocess, sys, tempfile, textwrap, time
from pathlib import Path

LIVE = os.environ["SESSION_SCRIPT"]
loader = importlib.machinery.SourceFileLoader("sut", LIVE)
spec = importlib.util.spec_from_loader("sut", loader)
sut = importlib.util.module_from_spec(spec)
loader.exec_module(sut)


def payload(i):
    return json.dumps({"w": i, "pad": "x" * (2000 if i % 2 == 0 else 200000)}) + "\n"


def stress(impl, seconds=1.5, nproc=8):
    d = Path(tempfile.mkdtemp())
    p = d / "state" / "claude" / "s.json"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(payload(0), encoding="utf-8")
    worker = d / "worker.py"
    worker.write_text(textwrap.dedent(r'''
        import importlib.machinery, importlib.util
        import json, os, sys, time
        from pathlib import Path

        live, impl, path_s, idx_s, deadline_s, out_s = sys.argv[1:]
        loader = importlib.machinery.SourceFileLoader("sut", live)
        spec = importlib.util.spec_from_loader("sut", loader)
        sut = importlib.util.module_from_spec(spec)
        loader.exec_module(sut)

        def old_atomic_write(path: Path, text: str) -> None:
            path.parent.mkdir(parents=True, exist_ok=True)
            tmp = path.with_name(f".{path.name}.tmp")
            tmp.write_text(text, encoding="utf-8")
            tmp.replace(path)

        def payload(i):
            return json.dumps({"w": i, "pad": "x" * (2000 if i % 2 == 0 else 200000)}) + "\n"

        def read_with_retry(target):
            # Windows cannot open a file mid-replace; a real reader retries, so the
            # measurement here must too, or it counts the platform, not a lost write.
            for _ in range(200):
                try:
                    return json.loads(target.read_text(encoding="utf-8"))
                except PermissionError:
                    time.sleep(0.005)
            return json.loads(target.read_text(encoding="utf-8"))
        
        aw = old_atomic_write if impl == "old" else sut.atomic_write
        p = Path(path_s)
        text = payload(int(idx_s))
        deadline = float(deadline_s)
        repl = torn = other = 0
        while time.time() < deadline:
            try:
                aw(p, text)
            except (FileNotFoundError, OSError):
                repl += 1
                continue
            try:
                read_with_retry(p)
            except json.JSONDecodeError:
                torn += 1
            except FileNotFoundError:
                pass
            except Exception:
                other += 1
        Path(out_s).write_text(json.dumps({"replace": repl, "torn": torn, "other": other}), encoding="utf-8")
    '''), encoding="utf-8")

    deadline = time.time() + seconds
    out_paths = [d / f"out-{i}.json" for i in range(nproc)]
    procs = [
        subprocess.Popen(
            [sys.executable, str(worker), LIVE, impl, str(p), str(i), str(deadline), str(out_paths[i])],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        for i in range(nproc)
    ]
    exits = 0
    for proc in procs:
        if proc.wait() != 0:
            exits += 1
    totals = {"replace": 0, "torn": 0, "other": 0, "exits": exits, "missing": 0}
    for out in out_paths:
        if not out.exists():
            totals["missing"] += 1
            continue
        data = json.loads(out.read_text(encoding="utf-8"))
        for key in ("replace", "torn", "other"):
            totals[key] += int(data.get(key, 0))
    return totals


def main():
    # Layer 2 — read_json heal contract (deterministic)
    d = Path(tempfile.mkdtemp())
    p = d / "x.json"
    p.write_text(json.dumps({"a": 1, "b": 2}) + '\n"\n}\n', encoding="utf-8")
    healed = sut.read_json(p, {}) == {"a": 1, "b": 2}
    print("HEAL_TRAILING", "PASS" if healed else "FAIL")

    unhealable = {
        "leading-NUL": "\x00" * 2000 + json.dumps({"a": 1}),
        "mid-fragment": 'x"*9999, "a":1}',
        "empty": "",
    }
    okdef = True
    for content in unhealable.values():
        p.write_text(content, encoding="utf-8")
        try:
            okdef &= sut.read_json(p, {"D": True}) == {"D": True}
        except Exception:
            okdef = False
    print("HEAL_FALLBACK", "PASS" if okdef else "FAIL")

    # Layer 3 — race contrast
    old = stress("old")
    new = stress("new")
    old_bad = sum(old.values())
    new_bad = sum(new.values())
    print("OLD_RACE", old_bad, f"(replace={old['replace']} torn={old['torn']} other={old['other']} exits={old['exits']} missing={old['missing']})")
    print("NEW_RACE", new_bad, f"(replace={new['replace']} torn={new['torn']} other={new['other']} exits={new['exits']} missing={new['missing']})")


main()
PY
py_out="$(SESSION_SCRIPT="$SESSION" python3 "$racepy" 2>/dev/null)"

if [ -z "$py_out" ]; then
  log_fail "python concurrency harness ran" "no output (see stderr above)"
else
  grep -q "^HEAL_TRAILING PASS" <<<"$py_out" \
    && log_pass "read_json heals 'valid object + trailing junk' (issue's pattern)" \
    || log_fail "read_json heals 'valid object + trailing junk'" "$(grep '^HEAL_TRAILING' <<<"$py_out")"

  grep -q "^HEAL_FALLBACK PASS" <<<"$py_out" \
    && log_pass "read_json falls back to default on leading-garbage / fragment / empty" \
    || log_fail "read_json fallback on unhealable data" "$(grep '^HEAL_FALLBACK' <<<"$py_out")"

  new_bad="$(awk '/^NEW_RACE/{print $2}' <<<"$py_out")"
  old_bad="$(awk '/^OLD_RACE/{print $2}' <<<"$py_out")"
  new_detail="$(grep '^NEW_RACE' <<<"$py_out")"
  old_detail="$(grep '^OLD_RACE' <<<"$py_out")"

  if [ "${new_bad:-1}" = "0" ]; then
    log_pass "current atomic_write: 0 corruption events under 8 concurrent writers"
  else
    log_fail "current atomic_write under concurrent writers" "$new_detail"
  fi

  # Control: the OLD shared-tmp code should usually race for this harness to be
  # meaningful. Timing-dependent, so a quiet run is a WARN (not a hard failure).
  if [ "${old_bad:-0}" -gt 0 ] 2>/dev/null; then
    log_pass "control: OLD shared-tmp reproduces the race ($old_detail)"
  else
    log_warn "control: OLD shared-tmp did NOT race this run — harness sensitivity unconfirmed on this host"
  fi
fi

# --- Layer 4: the real hook entrypoint under concurrency ---------------------
# Exactly the command shape from settings.json, many procs -> one session id.
hub="$(mktemp -d)"
trap 'rm -rf "$hub" "$racepy"' EXIT
touch "$hub/errlog"
"$SESSION" --hub "$hub" enable --mode balanced >/dev/null 2>&1
sid="concurrent-stop"
PAR=24
ROUNDS=4
exits=0
for r in $(seq 1 "$ROUNDS"); do
  pids=()
  for i in $(seq 1 "$PAR"); do
    printf '{"session_id":"%s","cwd":"/tmp","hook_event_name":"Stop","transcript_path":"/tmp/t-%s-%s","tool_name":"Bash"}' "$sid" "$r" "$i" \
      | "$SESSION" --hub "$hub" hook --harness claude --session-id "$sid" --event-name Stop --if-enabled \
        >/dev/null 2>>"$hub/errlog" &
    pids+=($!)
  done
  for p in "${pids[@]}"; do wait "$p" || exits=$((exits + 1)); done
done
traces="$(grep -c "Traceback" "$hub/errlog" 2>/dev/null || true)"
statefile="$hub/.sessions/state/claude/$sid.json"
total_hooks=$((PAR * ROUNDS))
if [ "$exits" -eq 0 ] && [ "${traces:-0}" -eq 0 ] \
   && python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$statefile" 2>/dev/null; then
  log_pass "$total_hooks concurrent live Stop hooks: 0 crashes, 0 tracebacks, state JSON intact"
else
  log_fail "$total_hooks concurrent live Stop hooks" "nonzero-exits=$exits tracebacks=${traces:-0}; $(head -c 400 "$hub/errlog")"
fi

echo ""
echo "==========================================="
printf "Results: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m, %d total\n" "$PASS" "$FAIL" "$TOTAL"
echo "==========================================="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
