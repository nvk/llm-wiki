#!/bin/bash
# Validate the local deterministic llm-wiki lint helper.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLI="$PROJECT_ROOT/scripts/llm-wiki"
GOLDEN="$SCRIPT_DIR/fixtures/golden-wiki"
PASS=0
FAIL=0
TOTAL=0

log_pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[32mPASS\033[0m: %s\n" "$1"; }
log_fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[31mFAIL\033[0m: %s - %s\n" "$1" "$2"; }

expect_success() {
  local name="$1"
  shift
  local output
  if output="$("$@" 2>&1)" && grep -q "Result: PASS" <<<"$output"; then
    log_pass "$name"
  else
    log_fail "$name" "$output"
  fi
}

expect_failure_contains() {
  local name="$1"
  local expected="$2"
  shift 2
  local output
  set +e
  output="$("$@" 2>&1)"
  local rc=$?
  set -e
  if [ "$rc" -ne 0 ] && grep -q "$expected" <<<"$output"; then
    log_pass "$name"
  else
    log_fail "$name" "$output"
  fi
}

echo "=== Local llm-wiki CLI Lint ==="

if [ -x "$CLI" ]; then
  log_pass "scripts/llm-wiki is executable"
else
  log_fail "scripts/llm-wiki is executable" "missing executable bit"
fi

expect_success "golden wiki passes local lint" "$CLI" lint "$GOLDEN"

expect_failure_contains \
  "missing-index fixture fails local lint" \
  "Required _index.md is missing" \
  "$CLI" lint "$SCRIPT_DIR/fixtures/defects/missing-index"

expect_failure_contains \
  "bad-frontmatter fixture fails local lint" \
  "Invalid type" \
  "$CLI" lint "$SCRIPT_DIR/fixtures/defects/bad-frontmatter"

expect_failure_contains \
  "raw-source-unresolved fixture fails local lint" \
  "Raw source reference does not resolve" \
  "$CLI" lint "$SCRIPT_DIR/fixtures/defects/raw-source-unresolved"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir "$tmpdir/wiki"
cp -R "$GOLDEN/." "$tmpdir/wiki/"
mv "$tmpdir/wiki/wiki/concepts/sample-concept.md" \
  "$tmpdir/wiki/wiki/references/sample-concept.md"

expect_failure_contains \
  "misplaced file is reported" \
  "File is in the wrong directory" \
  "$CLI" lint "$tmpdir/wiki"

set +e
fix_output="$("$CLI" lint --fix "$tmpdir/wiki" 2>&1)"
fix_rc=$?
set -e
if [ "$fix_rc" -eq 0 ] \
  && grep -q "Moved wiki/references/sample-concept.md to wiki/concepts/sample-concept.md" <<<"$fix_output" \
  && [ -f "$tmpdir/wiki/wiki/concepts/sample-concept.md" ]; then
  log_pass "--fix moves misplaced wiki files"
else
  log_fail "--fix moves misplaced wiki files" "$fix_output"
fi

mkdir "$tmpdir/no-optional"
cp -R "$GOLDEN/." "$tmpdir/no-optional/"
rm -rf "$tmpdir/no-optional/inventory" "$tmpdir/no-optional/datasets"
set +e
optional_output="$("$CLI" lint --fix "$tmpdir/no-optional" 2>&1)"
optional_rc=$?
set -e
if [ "$optional_rc" -eq 0 ] \
  && grep -q "Result: PASS" <<<"$optional_output" \
  && [ ! -e "$tmpdir/no-optional/inventory" ] \
  && [ ! -e "$tmpdir/no-optional/datasets" ]; then
  log_pass "--fix preserves absent optional inventory and dataset layers"
else
  log_fail "--fix preserves absent optional inventory and dataset layers" "$optional_output"
fi

mkdir "$tmpdir/sparse-optional"
cp -R "$GOLDEN/." "$tmpdir/sparse-optional/"
rm -rf "$tmpdir/sparse-optional/inventory" "$tmpdir/sparse-optional/datasets"
mkdir -p "$tmpdir/sparse-optional/inventory" "$tmpdir/sparse-optional/datasets/sparse-dataset"
cat > "$tmpdir/sparse-optional/inventory/_index.md" <<'EOF'
# Inventory Index

## Contents
EOF
cat > "$tmpdir/sparse-optional/datasets/_index.md" <<'EOF'
# Dataset Registry Index

## Contents

| Dataset | Status | Storage | Formats | Size | Records | Updated |
|---------|--------|---------|---------|------|---------|---------|
| [Sparse Dataset](sparse-dataset/MANIFEST.md) | external | external | csv | unknown | unknown | 2026-01-03 |
EOF
cat > "$tmpdir/sparse-optional/datasets/sparse-dataset/_index.md" <<'EOF'
# Sparse Dataset Index

## Contents

| File | Summary | Tags | Updated |
|------|---------|------|---------|
| [MANIFEST.md](MANIFEST.md) | Sparse optional-layer fixture. | sparse | 2026-01-03 |
EOF
cat > "$tmpdir/sparse-optional/datasets/sparse-dataset/MANIFEST.md" <<'EOF'
---
title: "Sparse Dataset"
dataset_id: sparse-dataset
status: external
storage: external
locations:
  - https://example.com/sparse.csv
formats: [csv]
schema_status: unknown
created: 2026-01-03
updated: 2026-01-03
tags: [sparse]
summary: "Sparse optional-layer fixture."
---

# Sparse Dataset
EOF
set +e
sparse_output="$("$CLI" lint --fix "$tmpdir/sparse-optional" 2>&1)"
sparse_rc=$?
set -e
if [ "$sparse_rc" -eq 0 ] \
  && grep -q "Result: PASS" <<<"$sparse_output" \
  && [ ! -e "$tmpdir/sparse-optional/inventory/items" ] \
  && [ ! -e "$tmpdir/sparse-optional/datasets/sparse-dataset/samples" ] \
  && [ ! -e "$tmpdir/sparse-optional/datasets/sparse-dataset/profiles" ] \
  && [ ! -e "$tmpdir/sparse-optional/datasets/sparse-dataset/queries" ]; then
  log_pass "--fix preserves sparse optional layer subdirectories"
else
  log_fail "--fix preserves sparse optional layer subdirectories" "$sparse_output"
fi

librarian_noise="$tmpdir/librarian-noise"
mkdir "$librarian_noise"
cp -R "$GOLDEN/." "$librarian_noise/"
mkdir -p "$librarian_noise/.librarian/backup/raw/articles"
cat > "$librarian_noise/.librarian/backup/raw/articles/_index.md" <<'EOF'
# Backup Articles

[dead.md](dead.md)
EOF

expect_success \
  "lint ignores maintenance backup indexes under .librarian" \
  "$CLI" lint "$librarian_noise"

legacy_repair="$tmpdir/legacy-repair"
mkdir "$legacy_repair"
cp -R "$GOLDEN/." "$legacy_repair/"
cat > "$legacy_repair/raw/articles/2026-01-04-quantum-canary-satoshi-coins.md" <<'EOF'
---
title: "Quantum Canary Satoshi Coins"
source: https://example.com/quantum-canary
type: articles
ingested: 2026-01-04
tags: [quantum, bitcoin]
summary: "Quantum Canary source fixture for fuzzy source repair."
---

# Quantum Canary Satoshi Coins
EOF
cat > "$legacy_repair/wiki/topics/legacy-topic.md" <<'EOF'
---
title: "Legacy Topic"
tags: [legacy, quantum]
confidence: high
sources: [quantum-canary]
created: 2026-01-04
updated: 2026-01-04
---

# Legacy Topic

This older compiled article has useful prose but lacks newer schema fields that lint can safely infer from its directory and first paragraph.
EOF
cat >> "$legacy_repair/wiki/topics/_index.md" <<'EOF'
| [Dead Topic](dead-topic.md) | no longer present | low | 2025-01-01 |
EOF
set +e
legacy_output="$("$CLI" lint --fix "$legacy_repair" 2>&1)"
legacy_rc=$?
set -e
if [ "$legacy_rc" -eq 0 ] \
  && grep -q "Result: PASS" <<<"$legacy_output" \
  && grep -q "category: topic" "$legacy_repair/wiki/topics/legacy-topic.md" \
  && grep -q "summary:" "$legacy_repair/wiki/topics/legacy-topic.md" \
  && grep -q "volatility: warm" "$legacy_repair/wiki/topics/legacy-topic.md" \
  && grep -q "raw/articles/2026-01-04-quantum-canary-satoshi-coins.md" "$legacy_repair/wiki/topics/legacy-topic.md" \
  && grep -q "Legacy Topic" "$legacy_repair/wiki/topics/_index.md" \
  && ! grep -q "dead-topic.md" "$legacy_repair/wiki/topics/_index.md"; then
  log_pass "--fix repairs legacy frontmatter, source refs, and indexes"
else
  log_fail "--fix repairs legacy frontmatter, source refs, and indexes" "$legacy_output"
fi

coverage_repair="$tmpdir/coverage-repair"
mkdir "$coverage_repair"
cp -R "$GOLDEN/." "$coverage_repair/"
cat > "$coverage_repair/raw/articles/2026-01-05-uncompiled-source.md" <<'EOF'
---
title: "Uncompiled Source"
source: https://example.com/uncompiled
type: articles
ingested: 2026-01-05
tags: [coverage]
summary: "Uncompiled raw source fixture for coverage repair."
---

# Uncompiled Source
EOF
set +e
coverage_output="$("$CLI" lint --fix "$coverage_repair" 2>&1)"
coverage_rc=$?
set -e
if [ "$coverage_rc" -eq 0 ] \
  && grep -q "Result: PASS" <<<"$coverage_output" \
  && [ -f "$coverage_repair/wiki/references/uncompiled-source-coverage.md" ] \
  && grep -q "raw/articles/2026-01-05-uncompiled-source.md" "$coverage_repair/wiki/references/uncompiled-source-coverage.md" \
  && grep -q "Uncompiled Source Coverage" "$coverage_repair/wiki/references/_index.md"; then
  log_pass "--fix creates explicit coverage reference for uncompiled raw sources"
else
  log_fail "--fix creates explicit coverage reference for uncompiled raw sources" "$coverage_output"
fi

hub_scope="$tmpdir/hub-scope"
mkdir -p "$hub_scope/topics/noisy-topic"
cp -R "$SCRIPT_DIR/fixtures/defects/missing-index/." "$hub_scope/topics/noisy-topic/"
cat > "$hub_scope/_index.md" <<'EOF'
# Hub Index
EOF
cat > "$hub_scope/log.md" <<'EOF'
# Hub Log
EOF
cat > "$hub_scope/wikis.json" <<'JSON'
{
  "default": "<HUB>",
  "wikis": {
    "hub": { "path": "<HUB>", "description": "Hub" },
    "noisy-topic": { "path": "topics/noisy-topic", "description": "Noisy topic" }
  },
  "local_wikis": []
}
JSON

expect_success \
  "hub lint stays scoped to hub registry" \
  "$CLI" lint "$hub_scope"

portable_home="$tmpdir/portable-home"
portable_hub="$portable_home/Library/Mobile Documents/com~apple~CloudDocs/wiki"
mkdir -p "$portable_home/.config/llm-wiki" "$portable_hub/topics/portable-topic"
cp -R "$GOLDEN/." "$portable_hub/topics/portable-topic/"
cat > "$portable_home/.config/llm-wiki/config.json" <<'JSON'
{
  "hub_path": "~/Library/Mobile Documents/com~apple~CloudDocs/wiki",
  "resolved_path": "/Users/olduser/Library/Mobile Documents/com~apple~CloudDocs/wiki"
}
JSON
cat > "$portable_hub/_index.md" <<'EOF'
# Hub Index
EOF
cat > "$portable_hub/wikis.json" <<'JSON'
{
  "default": "<HUB>",
  "wikis": {
    "hub": { "path": "<HUB>", "description": "Hub" },
    "portable-topic": {
      "path": "/Users/olduser/Library/Mobile Documents/com~apple~CloudDocs/wiki/topics/portable-topic",
      "description": "Portable topic"
    }
  },
  "local_wikis": []
}
JSON

expect_success \
  "portable hub_path beats stale resolved_path and registry path" \
  env HOME="$portable_home" "$CLI" lint --wiki portable-topic

lag_home="$tmpdir/lag-home"
lag_hub="$lag_home/Library/Mobile Documents/com~apple~CloudDocs/wiki"
stale_resolved_hub="$tmpdir/stale-resolved-hub"
mkdir -p "$lag_home/.config/llm-wiki" "$lag_hub/topics/lag-topic" "$stale_resolved_hub"
cp -R "$GOLDEN/." "$lag_hub/topics/lag-topic/"
cat > "$lag_home/.config/llm-wiki/config.json" <<JSON
{
  "hub_path": "~/Library/Mobile Documents/com~apple~CloudDocs/wiki",
  "resolved_path": "$stale_resolved_hub"
}
JSON
cat > "$lag_hub/wikis.json" <<'JSON'
{
  "default": "<HUB>",
  "wikis": {
    "hub": { "path": "<HUB>", "description": "Hub" },
    "lag-topic": { "path": "topics/lag-topic", "description": "Lag topic" }
  },
  "local_wikis": []
}
JSON
cat > "$stale_resolved_hub/_index.md" <<'EOF'
# Stale Hub Index
EOF

expect_success \
  "existing hub_path wins even when hub _index is not present yet" \
  env HOME="$lag_home" "$CLI" lint --wiki lag-topic

relative_hub="$tmpdir/relative-hub"
mkdir -p "$relative_hub/topics/relative-topic"
cp -R "$GOLDEN/." "$relative_hub/topics/relative-topic/"
cat > "$relative_hub/wikis.json" <<'JSON'
{
  "default": "<HUB>",
  "wikis": {
    "hub": { "path": "<HUB>", "description": "Hub" },
    "relative-topic": { "path": "topics/relative-topic", "description": "Relative topic" }
  },
  "local_wikis": []
}
JSON

expect_success \
  "relative wikis.json paths resolve from hub" \
  "$CLI" lint --hub "$relative_hub" --wiki relative-topic

archive_hub="$tmpdir/archive-hub"
mkdir -p "$archive_hub/topics/archive-topic"
cp -R "$GOLDEN/." "$archive_hub/topics/archive-topic/"
cat > "$archive_hub/_index.md" <<'EOF'
# Hub Index
EOF
cat > "$archive_hub/log.md" <<'EOF'
# Hub Log
EOF
cat > "$archive_hub/wikis.json" <<'JSON'
{
  "default": "<HUB>",
  "wikis": {
    "hub": { "path": "<HUB>", "description": "Hub" },
    "archive-topic": { "path": "topics/archive-topic", "description": "Archive topic" }
  },
  "local_wikis": []
}
JSON

set +e
archive_output="$("$CLI" archive --hub "$archive_hub" topic archive-topic --reason "No longer active" 2>&1)"
archive_rc=$?
set -e
if [ "$archive_rc" -eq 0 ] \
  && [ -d "$archive_hub/topics/.archive/archive-topic" ] \
  && [ ! -e "$archive_hub/topics/archive-topic" ] \
  && grep -q '"status": "archived"' "$archive_hub/wikis.json" \
  && grep -q 'topics/.archive/archive-topic' "$archive_hub/wikis.json"; then
  log_pass "archive command moves topic and marks registry archived"
else
  log_fail "archive command moves topic and marks registry archived" "$archive_output"
fi

expect_failure_contains \
  "archived wiki is rejected by default resolution" \
  "wiki is archived" \
  "$CLI" lint --hub "$archive_hub" --wiki archive-topic

expect_success \
  "archived wiki can be linted explicitly" \
  "$CLI" lint --hub "$archive_hub" --wiki archive-topic --include-archived

set +e
restore_output="$("$CLI" archive --hub "$archive_hub" restore archive-topic 2>&1)"
restore_rc=$?
set -e
if [ "$restore_rc" -eq 0 ] \
  && [ -d "$archive_hub/topics/archive-topic" ] \
  && [ ! -e "$archive_hub/topics/.archive/archive-topic" ] \
  && grep -q '"status": "active"' "$archive_hub/wikis.json" \
  && grep -q 'topics/archive-topic' "$archive_hub/wikis.json"; then
  log_pass "archive restore moves topic back and marks registry active"
else
  log_fail "archive restore moves topic back and marks registry active" "$restore_output"
fi

bad_registry_hub="$tmpdir/bad-registry-hub"
mkdir -p "$bad_registry_hub/topics/bad-registry-topic"
cp -R "$GOLDEN/." "$bad_registry_hub/topics/bad-registry-topic/"
printf '' > "$bad_registry_hub/wikis.json"

expect_success \
  "topic directory fallback works when wikis.json is unreadable" \
  "$CLI" lint --hub "$bad_registry_hub" --wiki bad-registry-topic

permission_hub="$tmpdir/permission-hub"
mkdir -p "$permission_hub/topics/denied-topic"
cp -R "$GOLDEN/." "$permission_hub/topics/denied-topic/"
cat > "$permission_hub/wikis.json" <<'JSON'
{
  "default": "<HUB>",
  "wikis": {
    "hub": { "path": "<HUB>", "description": "Hub" },
    "denied-topic": { "path": "topics/denied-topic", "description": "Denied topic" }
  },
  "local_wikis": []
}
JSON
chmod 000 "$permission_hub/wikis.json"
expect_failure_contains \
  "permission-denied registry read gives actionable diagnostic" \
  "Full Disk Access" \
  "$CLI" lint --hub "$permission_hub" --wiki denied-topic
chmod 644 "$permission_hub/wikis.json"

echo ""
echo "==========================================="
printf "Results: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m, %d total\n" "$PASS" "$FAIL" "$TOTAL"

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
