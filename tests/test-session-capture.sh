#!/usr/bin/env bash
# Validate deterministic llm-wiki session capture helper.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SESSION="$PROJECT_ROOT/scripts/llm-wiki-session"
PASS=0
FAIL=0
TOTAL=0

log_pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[32mPASS\033[0m: %s\n" "$1"; }
log_fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[31mFAIL\033[0m: %s - %s\n" "$1" "$2"; }

echo "=== Session Capture Helper ==="

if [ -x "$SESSION" ]; then
  log_pass "scripts/llm-wiki-session is executable"
else
  log_fail "scripts/llm-wiki-session is executable" "missing executable bit"
fi

if python3 -m py_compile "$SESSION"; then
  log_pass "scripts/llm-wiki-session compiles"
else
  log_fail "scripts/llm-wiki-session compiles" "py_compile failed"
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
hub="$tmpdir/wiki"
mkdir -p "$hub/topics/demo/raw/notes" "$hub/topics"
cat > "$hub/_index.md" <<'MD'
# Hub
MD
cat > "$hub/log.md" <<'MD'
# Hub Log
MD
cat > "$hub/wikis.json" <<'JSON'
{
  "default": "<HUB>",
  "wikis": {
    "hub": { "path": "<HUB>", "description": "Hub" },
    "demo": { "path": "topics/demo", "description": "Demo topic" }
  },
  "local_wikis": []
}
JSON
cat > "$hub/topics/demo/_index.md" <<'MD'
# Demo
MD
cat > "$hub/topics/demo/config.md" <<'MD'
---
title: "Demo"
---
MD
cat > "$hub/topics/demo/log.md" <<'MD'
# Demo Log
MD

default_hub="$tmpdir/default-on-wiki"
mkdir -p "$default_hub/topics"
touch "$default_hub/_index.md" "$default_hub/log.md"
echo '{"wikis":{}}' > "$default_hub/wikis.json"
printf '{"session_id":"default-on","hook_event_name":"PostToolUse","cwd":"%s","tool_name":"Bash"}' "$PWD" \
  | "$SESSION" --hub "$default_hub" hook --harness codex --if-enabled
if [ -f "$default_hub/.sessions/state/codex/default-on.json" ]; then
  log_pass "--if-enabled hook captures by default when no config exists"
else
  log_fail "--if-enabled hook captures by default when no config exists" "missing default-on state"
fi
"$SESSION" --hub "$default_hub" disable >/dev/null
printf '{"session_id":"disabled","hook_event_name":"PostToolUse","cwd":"%s","tool_name":"Bash"}' "$PWD" \
  | "$SESSION" --hub "$default_hub" hook --harness codex --if-enabled
if [ ! -f "$default_hub/.sessions/state/codex/disabled.json" ]; then
  log_pass "session disable makes --if-enabled hook no-op"
else
  log_fail "session disable makes --if-enabled hook no-op" "created disabled session state"
fi

copilot_hub="$tmpdir/copilot-wiki"
mkdir -p "$copilot_hub/topics"
printf '# Hub\n' > "$copilot_hub/_index.md"
printf '# Hub Log\n' > "$copilot_hub/log.md"
printf '{"wikis":{}}\n' > "$copilot_hub/wikis.json"
"$SESSION" --hub "$copilot_hub" enable --mode balanced >/dev/null
copilot_output="$(printf '{"session_id":"copilot-session","hook_event_name":"UserPromptSubmit","cwd":"%s","prompt":"default should be on"}' "$PWD" | "$SESSION" --hub "$copilot_hub" hook --harness copilot --if-enabled --suppress-output)"
if [ -z "$copilot_output" ] \
  && [ -f "$copilot_hub/.sessions/state/copilot/copilot-session.json" ] \
  && "$SESSION" --hub "$copilot_hub" feedback list --json | grep -q 'copilot:copilot-session'; then
  log_pass "Copilot UserPromptSubmit captures feedback without context output"
else
  log_fail "Copilot UserPromptSubmit capture-only behavior" "$copilot_output"
fi
printf '{"session_id":"copilot-session","hook_event_name":"PreCompact","cwd":"%s"}' "$PWD" \
  | "$SESSION" --hub "$copilot_hub" hook --harness copilot --if-enabled --suppress-output
copilot_start="$(printf '{"session_id":"copilot-session","hook_event_name":"SessionStart","cwd":"%s"}' "$PWD" | "$SESSION" --hub "$copilot_hub" hook --harness copilot --if-enabled)"
if python3 -c 'import json,sys; assert json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"]' <<<"$copilot_start"; then
  log_pass "Copilot SessionStart emits rehydration context"
else
  log_fail "Copilot SessionStart rehydration" "$copilot_start"
fi
printf '{"session_id":"copilot-session","hook_event_name":"SessionEnd","cwd":"%s"}' "$PWD" \
  | "$SESSION" --hub "$copilot_hub" hook --harness copilot --if-enabled --suppress-output --trigger session-end
copilot_digest="$copilot_hub/.sessions/digests/$(date +%Y)/$(date +%m)/copilot-copilot-session.md"
if [ -f "$copilot_digest" ] && grep -q 'capture_trigger: "session-end"' "$copilot_digest"; then
  log_pass "Copilot SessionEnd mapping writes final checkpoint"
else
  log_fail "Copilot SessionEnd mapping" "$copilot_digest"
fi

if "$SESSION" --hub "$hub" enable --mode balanced --tool-events 2 >/dev/null \
  && grep -q '"enabled": true' "$hub/.sessions/config.json" \
  && grep -q '"mode": "balanced"' "$hub/.sessions/config.json"; then
  log_pass "enable writes balanced config"
else
  log_fail "enable writes balanced config" "$(cat "$hub/.sessions/config.json" 2>/dev/null || true)"
fi

plugin_root_with_space="$tmpdir/plugin root"
ln -s "$PROJECT_ROOT/plugins/llm-wiki" "$plugin_root_with_space"
mkdir -p "$tmpdir/home/.config/llm-wiki"
printf '{"hub_path":"%s"}\n' "$hub" > "$tmpdir/home/.config/llm-wiki/config.json"
manifest_hook_cmd="$(python3 -c 'import json; from pathlib import Path; hooks=json.loads(Path("plugins/llm-wiki/hooks/hooks.json").read_text())["hooks"]; print(hooks["PostToolUse"][0]["hooks"][0]["command"])')"
printf '{"session_id":"manifest-space","hook_event_name":"PostToolUse","cwd":"%s","tool_name":"Bash"}' "$PWD" \
  | HOME="$tmpdir/home" PLUGIN_ROOT="$plugin_root_with_space" sh -c "$manifest_hook_cmd"
if [ -f "$hub/.sessions/state/codex/manifest-space.json" ]; then
  log_pass "Codex bundled hook command handles PLUGIN_ROOT paths with spaces"
else
  log_fail "Codex bundled hook command handles PLUGIN_ROOT paths with spaces" "$manifest_hook_cmd"
fi

claude_payload1=$(printf '{"session_id":"claude-session","hook_event_name":"PostToolUse","cwd":"%s","permission_mode":"default","transcript_path":"%s/transcript.jsonl","tool_name":"Bash","prompt":"do not store this Claude prompt","tool_response":"do not store this Claude tool response","tool_input":{"password":"super-secret-password"}}' "$PWD" "$tmpdir")
claude_payload2=$(printf '{"session_id":"claude-session","hook_event_name":"PostToolUse","cwd":"%s","permission_mode":"default","transcript_path":"%s/transcript.jsonl","tool_name":"Read"}' "$PWD" "$tmpdir")
printf '%s' "$claude_payload1" | "$SESSION" --hub "$hub" hook --if-enabled
printf '%s' "$claude_payload2" | "$SESSION" --hub "$hub" hook --if-enabled
claude_digest="$hub/.sessions/digests/$(date +%Y)/$(date +%m)/claude-claude-session.md"
if [ -f "$claude_digest" ] \
  && grep -q 'harness: "claude"' "$claude_digest" \
  && grep -q 'llm_wiki_session_id: "claude:claude-session"' "$claude_digest"; then
  log_pass "Claude-like hook payload auto-detects harness and writes digest"
else
  log_fail "Claude-like hook payload auto-detects harness and writes digest" "$claude_digest"
fi
if ! grep -R 'super-secret-password\|do not store this Claude prompt\|do not store this Claude tool response' "$hub/.sessions" >/dev/null; then
  log_pass "Claude-like hook payload redacts secrets and omits content fields"
else
  log_fail "Claude-like hook payload redacts secrets and omits content fields" "sensitive Claude payload data found under .sessions"
fi

feedback_payload=$(printf '{"session_id":"feedback-session","hook_event_name":"UserPromptSubmit","cwd":"%s","prompt":"actually default should be on, but there should be a way for people to turn the sessions feature off"}' "$PWD")
printf '%s' "$feedback_payload" | "$SESSION" --hub "$hub" hook --harness codex --if-enabled >/dev/null
feedback_json="$("$SESSION" --hub "$hub" feedback list --json 2>&1)"
feedback_id="$(python3 -c 'import json,sys; data=json.load(sys.stdin); matches=[c for c in data["feedback_candidates"] if c.get("llm_wiki_session_id")=="codex:feedback-session" and c.get("feedback_type")=="correction"]; assert matches; print(matches[0]["id"])' <<<"$feedback_json" 2>/dev/null || true)"
if [ -n "$feedback_id" ]; then
  log_pass "UserPromptSubmit feedback candidate captures correction/preference signals"
else
  log_fail "UserPromptSubmit feedback candidate captures correction/preference signals" "$feedback_json"
fi
before_ack_count="$(python3 -c 'import json,sys; data=json.load(sys.stdin); print(len(data["feedback_candidates"]))' <<<"$feedback_json")"
ack_payload=$(printf '{"session_id":"feedback-session","hook_event_name":"UserPromptSubmit","cwd":"%s","prompt":"ok"}' "$PWD")
printf '%s' "$ack_payload" | "$SESSION" --hub "$hub" hook --harness codex --if-enabled >/dev/null
after_ack_json="$("$SESSION" --hub "$hub" feedback list --json 2>&1)"
after_ack_count="$(python3 -c 'import json,sys; data=json.load(sys.stdin); print(len(data["feedback_candidates"]))' <<<"$after_ack_json")"
if [ "$before_ack_count" = "$after_ack_count" ]; then
  log_pass "Generic acknowledgements are ignored as low-signal feedback"
else
  log_fail "Generic acknowledgements are ignored as low-signal feedback" "before=$before_ack_count after=$after_ack_count"
fi
if [ -n "$feedback_id" ]; then
  feedback_promote_output="$("$SESSION" --hub "$hub" feedback promote "$feedback_id" --topic demo 2>&1)"
else
  feedback_promote_output="missing feedback id"
fi
if [ -n "$feedback_id" ] \
  && [ -f "$feedback_promote_output" ] \
  && grep -q 'Feedback Candidate Promotion' "$feedback_promote_output" \
  && grep -q 'promoted feedback candidate' "$hub/topics/demo/log.md" \
  && grep -q "$feedback_id" "$hub/.sessions/indexes/feedback.json"; then
  log_pass "feedback promote creates topic raw note and feedback index"
else
  log_fail "feedback promote creates topic raw note and feedback index" "$feedback_promote_output"
fi

payload1=$(printf '{"session_id":"test-session","hook_event_name":"PostToolUse","cwd":"%s","prompt":"do not store this raw prompt text","tool_name":"Bash","tool_input":{"api_key":"sk-12345678901234567890","command":"curl -H Authorization: Bearer abcdefghijklmnop"}}' "$PWD")
payload2=$(printf '{"session_id":"test-session","hook_event_name":"PostToolUse","cwd":"%s","tool_name":"Bash"}' "$PWD")
printf '%s' "$payload1" | "$SESSION" --hub "$hub" hook --harness codex --if-enabled
printf '%s' "$payload2" | "$SESSION" --hub "$hub" hook --harness codex --if-enabled

digest="$hub/.sessions/digests/$(date +%Y)/$(date +%m)/codex-test-session.md"
if [ -f "$digest" ] \
  && grep -q 'capture_trigger: "tool-count-2"' "$digest" \
  && grep -q 'llm_wiki_session_id: "codex:test-session"' "$digest"; then
  log_pass "tool threshold writes markdown digest"
else
  log_fail "tool threshold writes markdown digest" "missing or malformed digest at $digest"
fi

if ! grep -R 'sk-12345678901234567890\|abcdefghijklmnop\|do not store this raw prompt text' "$hub/.sessions" >/dev/null; then
  log_pass "hook event previews redact secrets and omit raw prompt text"
else
  log_fail "hook event previews redact secrets and omit raw prompt text" "secret material found under .sessions"
fi

rehydrate_output="$("$SESSION" --hub "$hub" rehydrate --session-id codex:test-session 2>&1)"
if grep -q 'llm-wiki session context' <<<"$rehydrate_output" \
  && grep -q 'codex:test-session' <<<"$rehydrate_output"; then
  log_pass "rehydrate prints compact context block"
else
  log_fail "rehydrate prints compact context block" "$rehydrate_output"
fi

session_start_output="$(printf '{"session_id":"test-session","hook_event_name":"SessionStart","cwd":"%s"}' "$PWD" | "$SESSION" --hub "$hub" hook --harness codex --if-enabled 2>&1)"
if python3 -c 'import json,sys; data=json.load(sys.stdin); assert data["hookSpecificOutput"]["additionalContext"]' <<<"$session_start_output" 2>/dev/null; then
  log_pass "balanced SessionStart hook emits additionalContext"
else
  log_fail "balanced SessionStart hook emits additionalContext" "$session_start_output"
fi

promote_output="$("$SESSION" --hub "$hub" promote codex:test-session --topic demo 2>&1)"
if [ -f "$promote_output" ] \
  && grep -q 'Session Digest Promotion: codex:test-session' "$promote_output" \
  && grep -q 'promoted session digest codex:test-session' "$hub/topics/demo/log.md" \
  && grep -q '"demo"' "$hub/.sessions/indexes/by-topic.json"; then
  log_pass "promote creates topic raw note and index topic tag"
else
  log_fail "promote creates topic raw note and index topic tag" "$promote_output"
fi

list_output="$("$SESSION" --hub "$hub" list --json 2>&1)"
if python3 -c 'import json,sys; data=json.load(sys.stdin); assert any(s.get("llm_wiki_session_id") == "codex:test-session" for s in data["sessions"])' <<<"$list_output"; then
  log_pass "list --json reports captured session"
else
  log_fail "list --json reports captured session" "$list_output"
fi

echo ""
echo "==========================================="
printf "Results: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m, %d total\n" "$PASS" "$FAIL" "$TOTAL"
echo "==========================================="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
