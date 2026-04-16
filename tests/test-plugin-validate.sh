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

log_pass() { ((PASS++)); ((TOTAL++)); printf "  \033[32mPASS\033[0m: %s\n" "$1"; }
log_fail() { ((FAIL++)); ((TOTAL++)); printf "  \033[31mFAIL\033[0m: %s — %s\n" "$1" "$2"; }

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
for ref in command-prelude compilation hub-resolution indexing ingestion linting projects research-infrastructure wiki-structure; do
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
CODEX_SKILL="$CODEX_PLUGIN/skills/wiki-manager"

# References symlink: must be a symlink AND must resolve AND each of the 9
# expected reference files must be reachable through it. This is the only
# Codex-side failure mode test-codex-sync.sh cannot detect — git diff doesn't
# traverse symlinks and the sync script doesn't read through this one either.
echo ""
echo "--- References symlink ---"
REFS_LINK="$CODEX_SKILL/references"
if [ -L "$REFS_LINK" ]; then
  log_pass "references is a symlink"
  if [ -e "$REFS_LINK" ]; then
    log_pass "references symlink resolves"
    for ref in command-prelude compilation hub-resolution indexing ingestion linting projects research-infrastructure wiki-structure; do
      if [ -f "$REFS_LINK/${ref}.md" ]; then
        log_pass "references/$ref.md reachable via symlink"
      else
        log_fail "references/$ref.md not reachable via symlink" "broken target"
      fi
    done
  else
    log_fail "references symlink target does not exist" "$(readlink "$REFS_LINK")"
  fi
else
  log_fail "references is not a symlink" "expected symlink to claude-plugin source"
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

echo ""
echo "==========================================="
printf "Results: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m, %d total\n" "$PASS" "$FAIL" "$TOTAL"
echo "==========================================="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
