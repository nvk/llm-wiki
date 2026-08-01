#!/bin/bash
# Validate plugin manifest and command/skill frontmatter
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PLUGIN_DIR="$PROJECT_ROOT/claude-plugin"
PLUGIN_JSON="$PLUGIN_DIR/.claude-plugin/plugin.json"
PASS=0
FAIL=0
TOTAL=0
REFERENCE_NAMES="archive audit command-prelude compilation datasets feedback hub-resolution indexing ingestion inventory librarian linting projects query-lite research-infrastructure sessions wiki-structure"

log_pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[32mPASS\033[0m: %s\n" "$1"; }
log_fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[31mFAIL\033[0m: %s — %s\n" "$1" "$2"; }

echo "=== Plugin Validation ==="

# plugin.json
if [ -f "$PLUGIN_JSON" ]; then
  log_pass "plugin.json exists"
  if python3 -c "import json; json.load(open('$PLUGIN_JSON'))" 2>/dev/null; then
    log_pass "plugin.json is valid JSON"
  else
    log_fail "plugin.json is invalid JSON" "parse error"
  fi
else
  log_fail "plugin.json not found at $PLUGIN_JSON" "missing file"
fi

# Every command .md has frontmatter (starts with ---)
echo ""
echo "--- Command frontmatter ---"
for cmd in "$PLUGIN_DIR"/commands/*.md; do
  basename=$(basename "$cmd")
  if head -1 "$cmd" | grep -q "^---$"; then
    log_pass "frontmatter in commands/$basename"
  else
    log_fail "no frontmatter in commands/$basename" "missing ---"
  fi
done

# The lessons-learned command writes a raw note, so its embedded template must
# use the same frontmatter schema that lint accepts for raw/notes/*.md.
LL_COMMAND="$PLUGIN_DIR/commands/ll.md"
if grep -q '^type: notes$' "$LL_COMMAND" \
  && grep -q '^ingested: YYYY-MM-DD$' "$LL_COMMAND" \
  && grep -q '^lesson_kind: lessons-learned$' "$LL_COMMAND" \
  && ! grep -q '^type: lessons-learned$' "$LL_COMMAND" \
  && ! grep -q '^date: YYYY-MM-DD$' "$LL_COMMAND"; then
  log_pass "commands/ll.md raw-note template matches lint schema"
else
  log_fail "commands/ll.md raw-note template schema drift" "expected type: notes, ingested, and lesson_kind"
fi

# SKILL.md exists
echo ""
echo "--- Skill files ---"
if [ -f "$PLUGIN_DIR/skills/wiki-manager/SKILL.md" ]; then
  log_pass "SKILL.md exists"
  if head -1 "$PLUGIN_DIR/skills/wiki-manager/SKILL.md" | grep -q "^---$"; then
    log_pass "SKILL.md has frontmatter"
  else
    log_fail "SKILL.md has no frontmatter" "missing ---"
  fi
else
  log_fail "SKILL.md not found" "missing file"
fi

# Reference files exist
echo ""
echo "--- Reference files ---"
for ref in $REFERENCE_NAMES; do
  reffile="$PLUGIN_DIR/skills/wiki-manager/references/${ref}.md"
  if [ -f "$reffile" ]; then
    log_pass "references/$ref.md exists"
  else
    log_fail "references/$ref.md missing" "missing file"
  fi
done

# AGENTS.md exists at project root
echo ""
echo "--- Project files ---"
if [ -f "$PROJECT_ROOT/AGENTS.md" ]; then
  log_pass "AGENTS.md exists"
else
  log_fail "AGENTS.md missing" "missing file"
fi

# Codex mirror validation — the artifacts that Codex installs from this repo.
# Drift between Claude source and this mirror is covered by test-codex-sync.sh;
# what's checked here is whether the mirror itself is well-formed.
echo ""
echo "=== Codex Mirror Validation ==="
CODEX_PLUGIN="$PROJECT_ROOT/plugins/llm-wiki"
CODEX_SKILL="$CODEX_PLUGIN/skills/wiki"
CODEX_QUERY_SKILL="$CODEX_PLUGIN/skills/wiki-query"

# Codex copies references into the generated tree because the marketplace cache
# needs real files, not a symlink back into the repo checkout.
echo ""
echo "--- Codex references copy ---"
REFS_DIR="$CODEX_SKILL/references"
if [ -d "$REFS_DIR" ] && [ ! -L "$REFS_DIR" ]; then
  log_pass "Codex references directory exists"
  for ref in $REFERENCE_NAMES; do
    if [ -f "$REFS_DIR/${ref}.md" ]; then
      log_pass "Codex references/$ref.md exists"
    else
      log_fail "Codex references/$ref.md missing" "missing copied reference file"
    fi
  done
else
  log_fail "Codex references directory invalid" "expected copied files under plugins/llm-wiki/skills/wiki/references"
fi

# Codex plugin manifest
echo ""
echo "--- Codex plugin manifest ---"
CODEX_MANIFEST="$CODEX_PLUGIN/.codex-plugin/plugin.json"
if [ -f "$CODEX_MANIFEST" ]; then
  log_pass ".codex-plugin/plugin.json exists"
  if python3 -c "import json; m=json.load(open('$CODEX_MANIFEST')); assert m.get('name') and m.get('version'), 'missing name or version'" 2>/dev/null; then
    log_pass ".codex-plugin/plugin.json parses with name + version"
  else
    log_fail ".codex-plugin/plugin.json invalid" "parse error or missing required field"
  fi
else
  log_fail ".codex-plugin/plugin.json not found" "missing file"
fi


# Codex bundled hooks for opt-in automated session capture.
echo ""
echo "--- Codex bundled hooks ---"
CODEX_HOOKS="$CODEX_PLUGIN/hooks/hooks.json"
CODEX_SESSION_HELPER="$CODEX_PLUGIN/hooks/llm_wiki_session.py"
if [ -f "$CODEX_HOOKS" ]; then
  log_pass "Codex hooks/hooks.json exists"
  if python3 -c "import json; json.load(open('$CODEX_HOOKS'))" 2>/dev/null; then
    log_pass "Codex hooks/hooks.json is valid JSON"
  else
    log_fail "Codex hooks/hooks.json invalid" "parse error"
  fi
else
  log_fail "Codex hooks/hooks.json missing" "missing file"
fi
if [ -x "$CODEX_SESSION_HELPER" ]; then
  log_pass "Codex session hook helper exists and is executable"
else
  log_fail "Codex session hook helper missing" "expected executable hooks/llm_wiki_session.py"
fi

# Codex marketplace entry
MARKETPLACE="$PROJECT_ROOT/.agents/plugins/marketplace.json"
if [ -f "$MARKETPLACE" ]; then
  log_pass ".agents/plugins/marketplace.json exists"
  if python3 -c "import json; json.load(open('$MARKETPLACE'))" 2>/dev/null; then
    log_pass ".agents/plugins/marketplace.json is valid JSON"
  else
    log_fail ".agents/plugins/marketplace.json invalid JSON" "parse error"
  fi
else
  log_fail ".agents/plugins/marketplace.json not found" "missing file"
fi

# Codex SKILL.md
echo ""
echo "--- Codex skill files ---"
if [ -f "$CODEX_SKILL/SKILL.md" ]; then
  log_pass "Codex SKILL.md exists"
  if head -1 "$CODEX_SKILL/SKILL.md" | grep -q "^---$"; then
    log_pass "Codex SKILL.md has frontmatter"
  else
    log_fail "Codex SKILL.md has no frontmatter" "missing ---"
  fi
  if grep -q "^name: wiki$" "$CODEX_SKILL/SKILL.md"; then
    log_pass "Codex SKILL.md uses the wiki skill name"
  else
    log_fail "Codex SKILL.md uses the wrong skill name" "expected 'name: wiki'"
  fi
else
  log_fail "Codex SKILL.md not found" "missing file"
fi

# Codex agents/openai.yaml — minimal grep check (no PyYAML dep) for the two
# top-level keys the sync script writes.
OPENAI_YAML="$CODEX_SKILL/agents/openai.yaml"
if [ -f "$OPENAI_YAML" ]; then
  log_pass "agents/openai.yaml exists"
  if grep -q "^interface:" "$OPENAI_YAML" && grep -q "^policy:" "$OPENAI_YAML"; then
    log_pass "agents/openai.yaml has interface + policy keys"
  else
    log_fail "agents/openai.yaml missing required keys" "expected interface: and policy:"
  fi
else
  log_fail "agents/openai.yaml not found" "missing file"
fi

# The explicit query preset is deliberately separate from the full implicit
# skill so users can opt into a much smaller, read-only context surface.
if [ -f "$CODEX_QUERY_SKILL/SKILL.md" ]; then
  log_pass "Codex wiki-query/SKILL.md exists"
  if head -1 "$CODEX_QUERY_SKILL/SKILL.md" | grep -q "^---$" \
    && grep -q "^name: wiki-query$" "$CODEX_QUERY_SKILL/SKILL.md"; then
    log_pass "Codex wiki-query/SKILL.md has valid frontmatter"
  else
    log_fail "Codex wiki-query/SKILL.md frontmatter invalid" "expected name: wiki-query"
  fi
else
  log_fail "Codex wiki-query/SKILL.md not found" "missing query preset"
fi

CODEX_QUERY_YAML="$CODEX_QUERY_SKILL/agents/openai.yaml"
if [ -f "$CODEX_QUERY_YAML" ] \
  && grep -q "^interface:" "$CODEX_QUERY_YAML" \
  && grep -q "^policy:" "$CODEX_QUERY_YAML" \
  && grep -q "allow_implicit_invocation: false" "$CODEX_QUERY_YAML"; then
  log_pass "Codex wiki-query metadata is explicit-only"
else
  log_fail "Codex wiki-query metadata invalid" "expected interface and explicit-only policy"
fi

# OpenCode mirror validation — the artifacts that OpenCode loads via the
# "instructions" key in opencode.json. Drift between Claude source and this
# mirror is covered by test-opencode-sync.sh; what's checked here is whether
# the mirror itself is well-formed.
echo ""
echo "=== OpenCode Mirror Validation ==="
OPENCODE_PLUGIN="$PROJECT_ROOT/plugins/llm-wiki-opencode"
OPENCODE_SKILL="$OPENCODE_PLUGIN/skills/wiki-manager"
OPENCODE_QUERY_SKILL="$OPENCODE_PLUGIN/skills/wiki-query"

# References symlink
echo ""
echo "--- OpenCode references symlink ---"
OC_REFS_LINK="$OPENCODE_SKILL/references"
if [ -L "$OC_REFS_LINK" ]; then
  log_pass "OpenCode references is a symlink"
  if [ -e "$OC_REFS_LINK" ]; then
    log_pass "OpenCode references symlink resolves"
    for ref in $REFERENCE_NAMES; do
      if [ -f "$OC_REFS_LINK/${ref}.md" ]; then
        log_pass "OpenCode references/$ref.md reachable via symlink"
      else
        log_fail "OpenCode references/$ref.md not reachable via symlink" "broken target"
      fi
    done
  else
    log_fail "OpenCode references symlink target does not exist" "$(readlink "$OC_REFS_LINK")"
  fi
else
  log_fail "OpenCode references is not a symlink" "expected symlink to claude-plugin source"
fi

# OpenCode SKILL.md
echo ""
echo "--- OpenCode skill files ---"
if [ -f "$OPENCODE_SKILL/SKILL.md" ]; then
  log_pass "OpenCode SKILL.md exists"
  if head -1 "$OPENCODE_SKILL/SKILL.md" | grep -q "^---$"; then
    log_pass "OpenCode SKILL.md has frontmatter"
  else
    log_fail "OpenCode SKILL.md has no frontmatter" "missing ---"
  fi
  # Verify no Claude Code references leaked through
  if ! grep -q "Claude Code" "$OPENCODE_SKILL/SKILL.md"; then
    log_pass "OpenCode SKILL.md has no 'Claude Code' references"
  else
    log_fail "OpenCode SKILL.md contains 'Claude Code'" "sync script missed a replacement"
  fi
else
  log_fail "OpenCode SKILL.md not found" "missing file"
fi

if [ -f "$OPENCODE_QUERY_SKILL/SKILL.md" ]; then
  log_pass "OpenCode wiki-query/SKILL.md exists"
  if head -1 "$OPENCODE_QUERY_SKILL/SKILL.md" | grep -q "^---$" \
    && grep -q "^name: wiki-query$" "$OPENCODE_QUERY_SKILL/SKILL.md"; then
    log_pass "OpenCode wiki-query/SKILL.md has valid frontmatter"
  else
    log_fail "OpenCode wiki-query/SKILL.md frontmatter invalid" "expected name: wiki-query"
  fi
else
  log_fail "OpenCode wiki-query/SKILL.md not found" "missing best-effort query preset"
fi

# OpenCode README
if [ -f "$OPENCODE_PLUGIN/README.md" ]; then
  log_pass "OpenCode README.md exists"
else
  log_fail "OpenCode README.md not found" "missing file"
fi

# GitHub Copilot plugin validation. This is a generated, self-contained Agent
# Plugin package because Copilot installs it into a cache outside the checkout.
echo ""
echo "=== GitHub Copilot Plugin Validation ==="
COPILOT_PLUGIN="$PROJECT_ROOT/plugins/llm-wiki-copilot"
COPILOT_MANIFEST="$COPILOT_PLUGIN/plugin.json"
COPILOT_SKILL="$COPILOT_PLUGIN/skills/wiki-manager/SKILL.md"
COPILOT_HOOKS="$COPILOT_PLUGIN/hooks/hooks.json"
COPILOT_MARKETPLACE="$PROJECT_ROOT/.github/plugin/marketplace.json"

if [ -f "$COPILOT_MANIFEST" ] \
  && python3 -c "import json; manifest=json.load(open('$COPILOT_MANIFEST')); assert manifest['name'] == 'wiki'; assert manifest['commands'] == ['./commands']; assert manifest['skills'] == ['./skills']; assert manifest['hooks'] == './hooks/hooks.json'" 2>/dev/null; then
  log_pass "Copilot plugin manifest declares commands, skills, and hooks"
else
  log_fail "Copilot plugin manifest invalid" "missing or malformed plugin.json"
fi

if [ -f "$COPILOT_MARKETPLACE" ] \
  && python3 -c "import json; marketplace=json.load(open('$COPILOT_MARKETPLACE')); plugins=marketplace['plugins']; assert len(plugins) == 1 and plugins[0]['name'] == 'wiki' and plugins[0]['source'] == './plugins/llm-wiki-copilot'" 2>/dev/null; then
  log_pass "Copilot marketplace points at generated plugin"
else
  log_fail "Copilot marketplace invalid" "expected wiki plugin source"
fi

if [ -f "$COPILOT_SKILL" ] \
  && head -1 "$COPILOT_SKILL" | grep -q '^---$' \
  && grep -q '^name: wiki-manager$' "$COPILOT_SKILL" \
  && grep -q '^user-invocable: false$' "$COPILOT_SKILL" \
  && ! grep -q 'Claude Code' "$COPILOT_SKILL"; then
  log_pass "Copilot ambient skill has compatible frontmatter and branding"
else
  log_fail "Copilot ambient skill invalid" "expected Copilot frontmatter without Claude Code branding"
fi

if [ -d "$COPILOT_PLUGIN/skills/wiki-manager/references" ] \
  && [ ! -L "$COPILOT_PLUGIN/skills/wiki-manager/references" ]; then
  log_pass "Copilot references are copied into generated package"
else
  log_fail "Copilot references invalid" "expected copied references directory"
fi

canonical_commands="$(find "$PLUGIN_DIR/commands" -maxdepth 1 -name '*.md' -printf '%f\n' | sort)"
copilot_commands="$(find "$COPILOT_PLUGIN/commands" -maxdepth 1 -name '*.md' -printf '%f\n' | sort 2>/dev/null || true)"
if [ "$canonical_commands" = "$copilot_commands" ]; then
  log_pass "Copilot commands match canonical command set"
else
  log_fail "Copilot command parity failed" "generated command names differ"
fi

if [ -f "$COPILOT_HOOKS" ] \
  && python3 -c "import json; hooks=json.load(open('$COPILOT_HOOKS')); required={'SessionStart','UserPromptSubmit','PostToolUse','PreCompact','Stop','SessionEnd'}; assert hooks.get('version') == 1; assert required <= set(hooks['hooks']); assert all('powershellCommand' in entries[0] for entries in hooks['hooks'].values())" 2>/dev/null; then
  log_pass "Copilot hooks include cross-platform lifecycle mapping"
else
  log_fail "Copilot hooks invalid" "missing required events or PowerShell commands"
fi

if [ -x "$COPILOT_PLUGIN/hooks/llm_wiki_session.py" ]; then
  log_pass "Copilot session helper is executable"
else
  log_fail "Copilot session helper missing" "expected executable bundled helper"
fi

echo ""
echo "==========================================="
printf "Results: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m, %d total\n" "$PASS" "$FAIL" "$TOTAL"
echo "==========================================="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
