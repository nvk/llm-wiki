# Hermes Plugin for nvk/llm-wiki — Design Spec

- **Date:** 2026-07-08
- **Status:** Proposed (approved design, pending implementation plan)
- **Target repo:** `github.com/nvk/llm-wiki` (forked to `dfein38347g/llm-wiki`, branch `feat/hermes-plugin`)
- **Goal:** Add first-class Hermes (NousResearch/hermes-agent) plugin support that mirrors the existing Claude Code and Codex adapters, plus a net-new proactive "wiki-as-memory" injection feature.

---

## 1. Problem & Context

`nvk/llm-wiki` ships session capture + a full wiki workflow for Claude Code (native plugin), OpenAI Codex (marketplace plugin), OpenCode/Pi (instruction file), and any agent (portable `AGENTS.md`). Each harness adapter is a thin packaging layer over one shared engine (`plugins/llm-wiki/hooks/llm_wiki_session.py`) plus a shared skill (`claude-plugin/skills/wiki-manager/SKILL.md`).

Hermes is absent. Hermes invokes Python hook functions **in-process** (not via shell commands like Claude/Codex), and exposes capability through `ctx.register_hook()`, `ctx.register_tool()`, and skills (`/<skill-name>`). There is no Claude-style `commands/*.md` block.

A prior attempt built a *subprocess bridge* wrapper that bundled the upstream script verbatim and shelled out from 5 Hermes hooks. It was "useless" for two reasons this design fixes:
1. It shipped **hooks only** — no skill and no tool — so the captured sessions could never be queried, compiled, or read back inside Hermes.
2. Its payload mapping was thin and it relied on subprocess stdout parsing, so rehydration was unlikely to surface.

This design commits to **full parity** with Claude/Codex across three layers — (a) instruction-driven agentic commands, (b) deterministic CLI, (c) in-process session-capture hooks — and adds a **proactive wiki-as-memory injection** that no other harness has.

---

## 2. Requirements

### 2.1 Functional parity (must match Claude Code + Codex)
- **R1 — Session capture hooks.** Hermes must capture the same redacted session events into `HUB/.sessions/` using the *identical* shared engine, namespaced under harness `hermes`.
- **R2 — Rehydration injection.** On session start and on each user prompt, Hermes must inject the same rehydrate context (prior distilled session digests) that Claude/Codex inject, gated by the same `rehydrate.session_start` / `rehydrate.user_prompt` config.
- **R3 — Tool-event capture + digests.** Tool calls, pre-compact, and session-end must produce the same event queue, state, digest, checkpoint, and index rebuilds.
- **R4 — Feedback candidates.** User prompts must feed the same feedback-candidate classifier (`extract_user_text` → `classify_feedback_text`) so corrections/approvals are captured and promotable.
- **R5 — Deterministic CLI.** Hermes must be able to run the same deterministic checks as `@wiki` in Codex: `lint`, `schema`, `archive`, and the `session`/`feedback` helpers.
- **R6 — Agentic commands.** Hermes must be able to perform the full agentic surface (`research`, `query`, `collect`, `ingest`, `compile`, `audit`, `output`, `plan`, `thesis`, `inventory`, `dataset`, `assess`, `ll`, …) by following the *same* skill the other harnesses use.
- **R7 — Opt-out.** `session disable` / `enabled: false` must silently no-op all Hermes capture, identical to other harnesses.
- **R8 — Hub resolution parity.** Same hub resolution (`~/.config/llm-wiki/config.json` → `~/wiki` fallback), same `wikis.json` registry, same topic-isolated layout.

### 2.2 Net-new feature (Hermes-exclusive)
- **R9 — Wiki-as-memory injection.** On each user prompt (`pre_llm_call` → `UserPromptSubmit`), Hermes must proactively match the user message against the wiki's indexes and inject the top-N relevant article summaries + paths as context, so the wiki acts as passive, injectable memory. This is lightweight (index + frontmatter only, no LLM, sub-100ms) and independently toggleable.

### 2.3 Non-functional
- **R10 — Zero behavior change for Claude/Codex.** The only upstream edit is extracting a payload-based entrypoint; subprocess behavior is preserved exactly.
- **R11 — Never blocks the agent.** Every hook is wrapped so any exception degrades to a log + `None` (no injected context), never a raised error into the harness.
- **R12 — No new runtime dependencies.** Reuse the existing zero-dependency engine and the existing `scripts/llm-wiki` / `scripts/llm-wiki-session` binaries.
- **R13 — Tests.** Unit tests for the adapter + an in-process engine test + a CI runtime script mirroring `test-codex-runtime.sh`.

### 2.4 Non-goals
- Not reimplementing wiki logic in Python hooks (the engine stays the single source).
- Not adding a Stop/PostCompact Hermes hook (Hermes exposes no direct equivalent; `on_session_end` maps to `SessionEnd`).
- Not changing the Claude/Codex packaging or sync scripts.

---

## 3. Repository / Fork Setup

1. `gh` fork `nvk/llm-wiki` → `dfein38347g/llm-wiki` (authenticated as `dfein38347g`).
2. Clone the fork; create branch `feat/hermes-plugin` off `master`.
3. All implementation lives in the fork clone (`/tmp/opencode/llm-wiki-upstream` currently, will be relocated to the fork working copy).
4. Upstream PR later targets `nvk:master` from `dfein38347g:feat/hermes-plugin`.

---

## 4. Upstream Refactor (minimal, backward-compatible)

**File:** `plugins/llm-wiki/hooks/llm_wiki_session.py`

### 4.1 New public function `handle_event`
Extract the body of `run_hook` into:

```python
def handle_event(args: argparse.Namespace, payload: dict[str, Any]) -> int:
    """Record a harness hook event and return any injectable context string.

    Returns the rehydrate context (may be "") instead of printing it, so
    in-process callers (e.g. Hermes) can inject it without parsing stdout.
    """
    root = sessions_dir(resolve_hub(args))
    config = load_config(root)
    if args.if_enabled and not config.get("enabled"):
        raise HookSkip()
    ensure_layout(root)
    event = normalize_event(args, payload, root)
    append_jsonl(event_queue_path(root, event), event)
    state, is_new = update_state(root, event, config)
    maybe_record_feedback_candidate(root, state, event, payload, config)
    if is_new:
        append_jsonl(root / "registry.jsonl", {...})
    write, trigger = should_write_digest(state, event, config, force=False)
    if write:
        write_digest(root, state, trigger)
    else:
        rebuild_indexes(root)
    event_name = str(event.get("hook_event_name") or "")
    rehydrate_cfg = config.get("rehydrate") if isinstance(config.get("rehydrate"), dict) else {}
    context = ""
    if event_name == "SessionStart" and rehydrate_cfg.get("session_start"):
        context = build_rehydrate_context(root, cwd=event.get("cwd"), limit=3)
    elif event_name == "UserPromptSubmit" and rehydrate_cfg.get("user_prompt"):
        context = build_rehydrate_context(root, cwd=event.get("cwd"), limit=3)
    return context
```

### 4.2 `run_hook` becomes a thin wrapper (unchanged subprocess behavior)
```python
def run_hook(args: argparse.Namespace) -> int:
    raw = sys.stdin.read()
    payload = json.loads(raw) if raw.strip() else {}
    context = handle_event(args, payload)
    if context:
        hook_output(event_name, context)   # existing print path
    return 0
```
(Exact structure: preserve existing `SystemExit` on bad JSON; `hook_output` prints as before.)

### 4.3 Harness namespace
`detect_harness` already returns `args.harness` verbatim when `--harness` is passed; `--harness hermes` therefore namespacestate under `state/hermes/`. No change required.

**Backward compatibility proof:** Claude/Codex invoke `run_hook` exactly as today; its stdout is unchanged → identical behavior.

---

## 5. New Plugin: `plugins/llm-wiki-hermes/`

Mirrors `plugins/llm-wiki-opencode/` as a sibling packaging target. Layout:

```
plugins/llm-wiki-hermes/
├── plugin.yaml                 # manifest
├── __init__.py                 # register(ctx)
├── hooks/
│   ├── __init__.py
│   └── adapter.py              # payload mapping, hook funcs, memory retrieval
├── tools.py                    # `wiki` router tool (deterministic CLI)
└── skills/
    └── wiki-manager/
        ├── SKILL.md            # copied from claude source
        └── references/         # copied verbatim (runtime-neutral)
```

### 5.1 `plugin.yaml`
```yaml
name: llm-wiki-hermes
manifest_version: 1
version: 0.15.0
description: >
  LLM-compiled knowledge bases for the Hermes agent. Session capture + rehydration
  hooks, a wiki tool for deterministic checks, and proactive wiki-as-memory
  injection, with the full wiki-manager skill for research/query/collect/compile/audit.
author: nvk
license: MIT
hooks:
  - pre_llm_call
  - on_session_start
  - post_tool_call
  - on_session_finalize
  - on_session_end
```
Tools and skills are registered in code (`register(ctx)`), not declared here, matching Hermes' plugin model.

### 5.2 `__init__.py` — `register(ctx)`
```python
from . import adapter, tools

def register(ctx):
    ctx.register_hook("on_session_start", adapter.on_session_start)
    ctx.register_hook("pre_llm_call", adapter.pre_llm_call)
    ctx.register_hook("post_tool_call", adapter.post_tool_call)
    ctx.register_hook("on_session_finalize", adapter.on_session_finalize)
    ctx.register_hook("on_session_end", adapter.on_session_end)
    tools.register(ctx)          # registers the `wiki` router tool
    # skill is discovered from skills/wiki-manager/ by Hermes
```

### 5.3 `hooks/adapter.py` — core

#### 5.3.1 Script resolution
Locate the shared engine relative to this file:
```python
ENGINE = (Path(__file__).resolve().parents[2] / "llm-wiki" / "hooks" / "llm_wiki_session.py")
```
Import it once at module load via `importlib`/`runpy` (the engine is a standalone script with a `main()`; we import the module namespace to call `handle_event`, `resolve_hub`, `sessions_dir`, `load_config`). Fallback: if the engine module cannot be imported, every hook logs a warning to stderr and returns `None` (R11).

#### 5.3.2 Payload mapping (Hermes kwargs → upstream payload)

The upstream `normalize_event` consumes these payload keys: `session_id`/`sessionId`, `hook_event_name`, `cwd`, `model`, `tool_name`/`toolName`/`tool`, `turn_id`/`turnId`, `tool_use_id`/`toolUseId`, `user_prompt`, `tool_output`, `duration_ms`, `status`, `platform`, `reason`, `completed`, `interrupted`. We populate them fully:

| Hermes hook | Upstream event | Key Hermes kwargs → payload fields |
|---|---|---|
| `on_session_start` | `SessionStart` | `session_id`→`session_id`; `cwd` (from `platform`/`os.getcwd()`); `model`; `carry_over_context`→`user_prompt` (optional) |
| `pre_llm_call` | `UserPromptSubmit` | `session_id`→`session_id`; `turn_id`→`turn_id`; `model`; `user_message`→`user_prompt`; `is_first_turn`→`payload_preview` note; `cwd` |
| `post_tool_call` | `PostToolUse` | `session_id`; `turn_id`→`turn_id`; `tool_name`→`tool_name`; `args` (recorded in `payload_preview`); `result`→`tool_output` (truncated to 1200 chars, matching Codex); `tool_call_id`→`tool_use_id`; `duration_ms`; `status`; `error_message`→`error` note; `cwd`; `model` |
| `on_session_finalize` | `PreCompact` | `session_id`; `reason`→`reason`; `cwd`; `model` |
| `on_session_end` | `SessionEnd` | `session_id`; `completed`→`completed`; `interrupted`→`interrupted`; `reason`; `model`; `cwd` |

`cwd` is always provided explicitly (from the hook's `platform`/working dir, falling back to `os.getcwd()`) so captures are correctly scoped for rehydration-by-cwd.

#### 5.3.3 Hook functions
Each builds an `argparse.Namespace` and a `payload` dict, then calls `engine.handle_event(args, payload)`:

```python
def _args(event_name, session_id, cwd):
    return argparse.Namespace(
        harness="hermes", event_name=event_name, session_id=session_id,
        cwd=cwd, if_enabled=True, topic=None, max_event_bytes=None,
        hub=None, local=False,
    )

def pre_llm_call(session_id=None, turn_id=None, user_message="", model=None,
                 is_first_turn=False, cwd=None, **kwargs):
    try:
        cwd = cwd or os.getcwd()
        args = _args("UserPromptSubmit", session_id, cwd)
        payload = {"session_id": session_id, "turn_id": turn_id, "model": model,
                   "user_prompt": user_message or ""}
        rehydrate = engine.handle_event(args, payload) or ""
        memory = retrieve_wiki_context(cwd=cwd, query=user_message, limit=MEMORY_LIMIT)
        combined = "\n\n".join(p for p in (rehydrate, memory) if p).strip()
        return combined or None
    except Exception as exc:                      # R11
        print(f"[llm-wiki-hermes] pre_llm_call error: {exc}", file=sys.stderr)
        return None
```

`on_session_start` is analogous (returns rehydrate context only, no memory). `post_tool_call`, `on_session_finalize`, `on_session_end` call `handle_event` and return `None` (captures/files only). All wrapped identically in try/except.

#### 5.3.4 Rehydration
Reuse the upstream `build_rehydrate_context` exactly via `handle_event` (R2). The returned string is the context that Hermes injects.

### 5.4 Wiki-as-memory injection (`retrieve_wiki_context`) — R9

**Purpose:** turn the wiki into passive, injectable memory by matching the user message against the wiki indexes and returning the top-N relevant article pointers.

**Inputs:** `cwd` (to scope/weight the local topic wiki), `query` (user message text), `limit` (default 3).

**Algorithm (lightweight, no LLM):**
1. Resolve hub via `engine.resolve_hub(args)` (no `--hub`/`--local` → config or `~/wiki`).
2. Read `hub/_index.md` (topic list with summaries) to enumerate topic slugs, weighting the topic whose `cwd` matches the current working dir highest.
3. For each candidate topic, read `hub/topics/<slug>/_index.md`. Each article row yields `title`, `path` (relative markdown link), `summary`, and `tags`.
4. Tokenize `query` (lowercase, strip punctuation, drop a small English stopword list). Tokenize each article as `title` (weight ×3) + `summary` (×1) + `tags` (×2).
5. Score = number of overlapping tokens (title/tag hits dominate). Keep articles with score > 0.
6. Sort by score desc, take top-`limit`.
7. Format as a markdown block:
   ```
   llm-wiki memory — relevant notes from your knowledge base:
   - [<title>](<path>) — <summary>
   - ...
   ```
   Return `""` if nothing matches.

**Toggle / config:** read an optional `memory` section from the shared `HUB/.sessions/config.json` (the same file `load_config` reads; ignored by Claude/Codex, so R10 holds):
```json
{ "memory": { "inject": true, "limit": 3 } }
```
Default `inject: true`, `limit: 3`. Env override `LLM_WIKI_HERMES_MEMORY=0` disables.

**Latency / safety:** only reads small `_index.md` files (ms). Any exception → return `""` (R11). Never reads article bodies (deep match is explicitly out of scope, R9 lightweight only).

**Combining with rehydration:** `pre_llm_call` joins rehydrate context + memory block; if both empty, returns `None` (no injection).

### 5.5 `tools.py` — `wiki` router tool (R5)

```python
def register(ctx):
    ctx.register_tool(
        name="wiki", toolset="wiki",
        schema={ "type":"object",
            "properties": {
                "command": {"type":"string", "description":"llm-wiki subcommand: lint|schema|archive|session|feedback"},
                "args": {"type":"string", "description":"Remaining CLI args, e.g. '--fix /path/to/wiki'"}
            }, "required":["command"] },
        handler=handle_wiki,
        description="Run deterministic llm-wiki checks (lint/schema/archive) and session/feedback helpers. "
                    "For agentic work (research/query/collect/ingest/compile/audit/output/plan/thesis) follow the wiki-manager skill."
    )

def handle_wiki(params, **kwargs):
    cmd = params.get("command"); rest = params.get("args", "")
    if cmd in ("session", "feedback"):
        script = REPO / "scripts" / "llm-wiki-session"
    else:
        script = REPO / "scripts" / "llm-wiki"
    proc = subprocess.run([sys.executable, script, cmd, *shlex.split(rest)],
                          capture_output=True, text=True, timeout=120)
    return json.dumps({"success": proc.returncode == 0,
                       "output": proc.stdout, "error": proc.stderr})
```
`REPO` = the fork root, resolved as `Path(__file__).resolve().parents[2]`. The tool returns deterministic results; agentic subcommands are intentionally routed to the skill (faithful to Codex's `@wiki` behavior — agentic work is instruction-driven, not scripted).

### 5.6 `skills/wiki-manager/SKILL.md` (R6)

Copy `claude-plugin/skills/wiki-manager/SKILL.md` (the behavioral source of truth) into `plugins/llm-wiki-hermes/skills/wiki-manager/SKILL.md`, and copy `references/` verbatim (runtime-neutral). Apply the same small wording-patch convention used by the Codex/OpenCode sync scripts (e.g., note that Hermes exposes deterministic checks via the `wiki` tool). This is the file that lets the Hermes agent actually perform `research`/`query`/`collect`/etc. using its own web-search, file, and subagent tools — identical to how Claude/Codex execute those commands.

---

## 6. README / Docs Updates

- **Supported clients table:** add row — `Hermes | ~/.hermes/plugins/llm-wiki-hermes | ~3K tokens | NousResearch agent`. (Adding a Supported-clients row is safe — `test-docs-consistency.sh` only validates the `## Commands` table against `claude-plugin/commands/*.md`, not this table; see §11.3.)
- **Version consistency:** set `plugins/llm-wiki-hermes/plugin.yaml` `version:` to `0.15.0` to match the repo-wide version.
- **Install section:** add "Hermes (plugin)" — drop `plugins/llm-wiki-hermes/` into `~/.hermes/plugins/`, restart Hermes; the `wiki` tool + 5 session hooks activate automatically; the wiki-manager skill is picked up for agentic commands.
- **Session capture line (§How It Works):** extend "Codex/Claude/OpenCode/Gemini" → include "Hermes"; mention the Hermes-exclusive proactive wiki-as-memory injection.
- Note opt-out works identically via `wiki session disable`.

---

## 7. Tests

### 7.1 Unit — `plugins/llm-wiki-hermes/tests/test_adapter.py`
- Each of the 5 hooks builds the expected `hook_event_name`, `session_id`, and (for tool/user events) the correctly mapped fields; `tool_output` truncated to ≤1200 chars.
- `harness` namespace equals `"hermes"` in the written state file (`HUB/.sessions/state/hermes/<sid>.json`).
- `pre_llm_call` returns a combined string containing both rehydrate context and the memory block when fixtures exist; returns `None` when both empty.
- `retrieve_wiki_context` scores correctly: a query matching a title returns that article top; non-matching query returns `""`; `limit` is respected.
- Graceful fallback: monkeypatching `engine.handle_event` to raise yields `None` and a stderr log (R11).
- Disabled config (`enabled: false`) yields `None` (R7).

### 7.2 In-process engine — `tests/test_hermes_engine.py`
- Import the shared engine, call `handle_event(args, payload)` directly (no subprocess); assert it returns a rehydrate string for `SessionStart` and writes the expected state/digest files. Proves the refactor is callable in-process and behaves like `run_hook`.

### 7.3 CI runtime — `tests/test-hermes-runtime.sh`
Mirror `tests/test-codex-runtime.sh`: stage the plugin into a temp `HERMES_HOME/plugins/`, simulate a harness firing each of the 5 hooks (via a tiny Python driver that imports the adapter and calls the hook fns), assert capture files appear under `HUB/.sessions/state/hermes/`, assert `pre_llm_call` prints/returns injected context, and assert the `wiki` tool runs `lint` against a fixture wiki. A full Hermes binary is **not** required in CI (Hermes has no headless bootstrap like Codex); the driver imports the adapter directly. See §11.2 for wiring this into the workflow.

### 7.4 Regression guard
Run the existing Claude/Codex test suites (`test-codex-runtime.sh`, `test-opencode-sync.sh`) to confirm R10 — no behavior change.

---

## 8. Parity Checklist (Claude Code / Codex ↔ Hermes)

| Capability | Claude/Codex | Hermes |
|---|---|---|
| Session capture (redacted checkpoints) | hooks.json → script | 5 in-process hooks → same engine |
| Rehydrate context injection | SessionStart/UserPromptSubmit stdout | `on_session_start`/`pre_llm_call` return string |
| Tool-event capture + digest/checkpoint | PostToolUse/PreCompact/Stop | `post_tool_call`/`on_session_finalize`/`on_session_end` |
| Feedback candidate classification | UserPromptSubmit user_prompt | `pre_llm_call` user_prompt |
| Deterministic CLI (lint/schema/archive/session/feedback) | `@wiki` / slash | `wiki` tool (R5) |
| Agentic commands (research/query/collect/…) | commands/*.md + skill | wiki-manager skill (R6) |
| Opt-out (`session disable`) | config `enabled:false` | same shared config (R7) |
| Hub/topic layout, wikis.json | identical | identical (R8) |
| **Proactive wiki-as-memory injection** | — (not present) | **NEW** (`pre_llm_call`, R9) |

**Documented gap:** Hermes has no direct `Stop`/`PostCompact` event; `on_session_end` maps to `SessionEnd` (the closest lifecycle event). This is acceptable and noted; it does not reduce captured fidelity for the events Hermes does fire.

---

## 9. Acceptance Criteria

1. Fork branch builds; full existing Claude/Codex test suites still pass (R10).
2. Installing `plugins/llm-wiki-hermes/` in Hermes activates 5 hooks + `wiki` tool + skill with no errors.
3. A Hermes session writes redacted events to `HUB/.sessions/state/hermes/<sid>.json` and builds digests/indexes identical in shape to Claude/Codex.
4. `on_session_start` and `pre_llm_call` inject rehydrate context when `rehydrate.*` is enabled (R2).
5. `pre_llm_call` additionally injects top-N wiki-memory matches when the user message relates to captured topics (R9); toggleable via `memory.inject` / `LLM_WIKI_HERMES_MEMORY`.
6. `wiki lint --fix <wiki>` and `wiki session disable` work via the tool (R5/R7).
7. The Hermes agent can run `/wiki:research`, `/wiki:query`, etc. by following the bundled skill (R6).
8. All new unit + CI tests pass (R13).
9. Any hook exception degrades to a log + no injection (R11).

---

## 10. Open Questions / Future

- **Shared retrieval helper?** `retrieve_wiki_context` currently lives in the Hermes adapter. If upstream wants memory injection for other harnesses later, it could be promoted into `llm-wiki_session.py` as a reusable `retrieve_wiki_context`. Out of scope for this PR.
- **Sync integration:** the Codex/OpenCode sync scripts regenerate packaging from the Claude source. Hermes's `SKILL.md` is a copy; a future sync step could include it. Not required for this PR (Hermes has Hermes-specific Python that cannot be purely generated).
- **Deep memory match:** full-text article scan (R9 "deep" option) deferred; lightweight index match ships first.

---

## 11. Development Workflow & Upstream PR Acceptance Requirements

This section is the merge contract. `nvk/llm-wiki` defines its dev workflow in `CLAUDE.md` and its test layers in `tests/README.md` + `tests/ci/plugin-tests.yml`. The PR will be accepted only if it follows these and the structural suite stays green.

### 11.1 Must-pass test gate (run before declaring done)
All of the following must pass locally:
```
./tests/test-plugin-validate.sh        # manifest + command/skill frontmatter
./tests/test-docs-consistency.sh       # README command table + manifest/version drift
./tests/test-structure.sh              # wiki fixture validation (84 assertions)
./tests/test-local-cli-lint.sh         # local scripts/llm-wiki lint helper
./tests/test-session-capture.sh        # deterministic session capture helper (proves handle_event refactor is behavior-safe)
./tests/test-session-concurrency.sh    # concurrent session-state regression
./tests/test-codex-sync.sh             # Codex mirror matches Claude source (must stay green)
./tests/test-opencode-sync.sh          # OpenCode mirror matches Claude source (must stay green)
./tests/test-hermes-runtime.sh         # NEW: Hermes adapter + wiki tool (see §7.3)
```
Critical invariants:
- `plugins/llm-wiki/` and `plugins/llm-wiki-opencode/` are **generated — never hand-edit** (per `CLAUDE.md`). Our new `plugins/llm-wiki-hermes/` is a separate, non-generated sibling, so it must not alter those two dirs; the sync tests will fail otherwise.
- `test-session-capture.sh` exercises the deterministic helper our `handle_event` refactor touches. Because `run_hook` is preserved as a thin `stdin → handle_event → print` wrapper, this test (and `test-session-concurrency.sh`) must remain green — this is the proof of R10 (zero behavior change).

### 11.2 CI workflow update (`tests/ci/plugin-tests.yml`)
The current workflow's `paths:` filters cover only `claude-plugin/**`, `scripts/**`, `tests/**`, `AGENTS.md` (and for PRs the same minus `AGENTS.md`). Hermes changes under `plugins/llm-wiki-hermes/**` would NOT trigger CI. Required edits:
1. Add `plugins/llm-wiki-hermes/**` and `tests/test-hermes-runtime.sh` to both `push` and `pull_request` `paths:` filters.
2. Add a step to the `structural` job:
   ```yaml
   - name: Run Hermes plugin runtime tests
     run: chmod +x tests/test-hermes-runtime.sh && ./tests/test-hermes-runtime.sh
   ```
The behavioral Promptfoo evals (`Layer 2`) are Claude-specific (require `ANTHROPIC_API_KEY` + the Claude Agent SDK) and do **not** cover Hermes. Hermes correctness is established by the structural suite + `test-hermes-runtime.sh` only. State this honestly in the PR description.

### 11.3 Version & docs consistency
- Set `plugins/llm-wiki-hermes/plugin.yaml` `version:` = `0.15.0` (the repo-wide version in `claude-plugin/.claude-plugin/plugin.json`, `plugins/llm-wiki/.codex-plugin/plugin.json`, `.claude-plugin/marketplace.json`). Keep all three in sync when bumping.
- `test-docs-consistency.sh` validates: (a) every `claude-plugin/commands/*.md` is listed in the README `## Commands` table and vice-versa; (b) the three manifest versions agree. We add **no** new `claude-plugin/commands/*.md` files (agentic commands are skill-driven), and the Supported-clients row is outside the `## Commands` table, so the test stays green. (Extending the manifest version set to include the Hermes plugin.yaml is optional and not required for green.)

### 11.4 Extend `test-plugin-validate.sh` for Hermes
Add a "Hermes Mirror Validation" block so the new plugin is first-class-validated like the Codex/OpenCode mirrors:
- `plugins/llm-wiki-hermes/plugin.yaml` exists, parses as YAML, has `name`, `version`, and a non-empty `hooks:` list.
- `plugins/llm-wiki-hermes/skills/wiki-manager/SKILL.md` exists with leading `---` frontmatter.
- `plugins/llm-wiki-hermes/hooks/__init__.py`, `hooks/adapter.py`, and `tools.py` exist.
- Each `.py` passes a syntax check (`python3 -m py_compile` or `ast.parse`).

### 11.5 Python compatibility & dependencies
- Target **Python 3.9+** (the engine supports 3.9 / macOS system Python). Start every new `.py` with `from __future__ import annotations` and avoid 3.10+ syntax (`X | Y` unions at runtime, `match`). The upstream engine already follows this pattern.
- **No new third-party dependencies.** Use only the stdlib (`argparse`, `json`, `subprocess`, `importlib`, `pathlib`, `os`, `sys`, `shlex`). Reuse the shared engine module via import; do not reimplement wiki logic.

### 11.6 Commit & PR hygiene
- Branch `feat/hermes-plugin` off `master`; push via the `gh` HTTPS credential helper (per `CLAUDE.md`): `git -c credential.helper='!gh auth git-credential' push https://github.com/nvk/llm-wiki.git feat/hermes-plugin:master` (or a fork branch; see §3).
- Commit style matches the repo (e.g., `feat: add Hermes plugin — session hooks, wiki tool, and wiki-as-memory injection`).
- PR description must explain: (a) the three-layer parity with Claude/Codex; (b) the net-new memory-injection feature; (c) the upstream `handle_event` refactor with proof of zero behavior change (unchanged `run_hook` + green `test-session-capture.sh`); (d) the new tests and the CI `paths:` update; (e) the behavioral-eval gap (Hermes not covered by Promptfoo).

### 11.7 What NOT to do
- Do **not** edit `plugins/llm-wiki/` or `plugins/llm-wiki-opencode/` by hand (generated; `test-codex-sync.sh` / `test-opencode-sync.sh` will fail).
- Do **not** add Hermes to `.agents/plugins/marketplace.json` — that is the Codex marketplace; Hermes discovers plugins from `~/.hermes/plugins/` by directory drop-in.
- Do **not** introduce SSH remotes or new CI secrets.
- Do **not** add a `Stop`/`PostCompact` Hermes hook (no Hermes equivalent); `on_session_end` → `SessionEnd` is the documented mapping (§8 gap).
