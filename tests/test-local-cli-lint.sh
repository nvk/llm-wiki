#!/bin/bash
# Validate the local deterministic llm-wiki lint helper.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLI="$PROJECT_ROOT/scripts/llm-wiki"
GOLDEN="$SCRIPT_DIR/fixtures/golden-wiki"
export LLM_WIKI_TODAY="${LLM_WIKI_TODAY:-2026-01-10}"
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

set +e
portable_path_output="$(python3 - "$CLI" <<'PY' 2>&1
import runpy
import sys
from pathlib import PureWindowsPath

namespace = runpy.run_path(sys.argv[1])

normalize_windows = namespace["normalize_windows_absolute_path"]
assert normalize_windows(r"C:\Users\person\wiki", platform="nt") == (
    "C:/Users/person/wiki"
)
assert normalize_windows("C:/Users/person/wiki", platform="nt") == (
    "C:/Users/person/wiki"
)
assert normalize_windows("/C:/Users/person/wiki", platform="nt") == (
    "C:/Users/person/wiki"
)
assert normalize_windows("topics/example", platform="nt") is None
assert normalize_windows(r"C:\Users\person\wiki", platform="posix") is None

# Exercise the link helper with Windows-native relpath output even when this
# test suite runs on POSIX. PureWindowsPath makes as_posix() behavior
# deterministic without requiring a Windows runner.
link_helper = namespace["markdown_relative_link"]
original_path = link_helper.__globals__["Path"]
original_relpath = link_helper.__globals__["os"].path.relpath
try:
    link_helper.__globals__["Path"] = PureWindowsPath
    link_helper.__globals__["os"].path.relpath = (
        lambda _target, _base: r"..\..\raw\articles\source.md"
    )
    assert link_helper(PureWindowsPath("base"), PureWindowsPath("target")) == (
        "../../raw/articles/source.md"
    )
finally:
    link_helper.__globals__["Path"] = original_path
    link_helper.__globals__["os"].path.relpath = original_relpath


class FakeResolvedPath:
    def __init__(self, relative: str) -> None:
        self.relative = relative

    def resolve(self):
        return self

    def relative_to(self, _root):
        return PureWindowsPath(self.relative)


ctx = object.__new__(namespace["LintContext"])
ctx.root = FakeResolvedPath("")
assert ctx.rel(FakeResolvedPath(r"raw\articles\source.md")) == (
    "raw/articles/source.md"
)
PY
)"
portable_path_rc=$?
set -e
if [ "$portable_path_rc" -eq 0 ]; then
  log_pass "generated wiki paths use portable separators"
else
  log_fail "generated wiki paths use portable separators" "$portable_path_output"
fi

expect_success "golden wiki passes local lint" "$CLI" lint "$GOLDEN"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

warning_only="$tmpdir/warning-only"
mkdir "$warning_only"
cp -R "$GOLDEN/." "$warning_only/"
sed -i 's/^confidence: high$/confidence: unsupported/' \
  "$warning_only/wiki/concepts/sample-concept.md"

expect_failure_contains \
  "default lint exit still fails on a warning" \
  "Invalid confidence" \
  "$CLI" lint "$warning_only"

set +e
fail_on_output="$("$CLI" lint "$warning_only" --fail-on critical 2>&1)"
fail_on_rc=$?
set -e
if [ "$fail_on_rc" -eq 0 ] \
  && grep -q "Invalid confidence" <<<"$fail_on_output" \
  && grep -q "Result: FAIL" <<<"$fail_on_output"; then
  log_pass "--fail-on critical ignores advisory findings in exit status"
else
  log_fail "--fail-on critical ignores advisory findings in exit status" "$fail_on_output"
fi

hybrid_rollup="$tmpdir/hybrid-rollup"
mkdir "$hybrid_rollup"
cp -R "$SCRIPT_DIR/fixtures/defects/stale-inventory-rollup/." "$hybrid_rollup/"
expect_failure_contains \
  "hybrid inventory root reports a missing nested record rollup" \
  "Required inventory navigation or record rollup entry is missing" \
  "$CLI" lint "$hybrid_rollup"
set +e
hybrid_fix_output="$("$CLI" lint --fix "$hybrid_rollup" 2>&1)"
hybrid_fix_rc=$?
set -e
if [ "$hybrid_fix_rc" -eq 0 ] \
  && grep -q 'items/unlisted-item.md' "$hybrid_rollup/inventory/_index.md" \
  && grep -q '\[Items\](items/_index.md)' "$hybrid_rollup/inventory/_index.md" \
  && grep -q '| File | Kind | Status | Priority | Next Action | Updated |' "$hybrid_rollup/inventory/_index.md"; then
  log_pass "--fix restores inventory hybrid navigation and nested record rollup"
else
  log_fail "--fix restores inventory hybrid navigation and nested record rollup" "$hybrid_fix_output"
fi

pointer_index="$tmpdir/pointer-index"
mkdir "$pointer_index"
cp -R "$SCRIPT_DIR/fixtures/defects/empty-wiki-pointer-index/." "$pointer_index/"
expect_failure_contains \
  "empty wiki pointer index is reported as missing category navigation" \
  "Required wiki category pointer entry is missing" \
  "$CLI" lint "$pointer_index"
set +e
pointer_fix_output="$("$CLI" lint --fix "$pointer_index" 2>&1)"
pointer_fix_rc=$?
set -e
if [ "$pointer_fix_rc" -eq 0 ] \
  && grep -q '\[concepts/_index.md\](concepts/_index.md)' "$pointer_index/wiki/_index.md" \
  && grep -q '\[theses/_index.md\](theses/_index.md)' "$pointer_index/wiki/_index.md" \
  && ! grep -q 'sample-concept.md' "$pointer_index/wiki/_index.md"; then
  log_pass "--fix restores wiki category pointers without flattening articles"
else
  log_fail "--fix restores wiki category pointers without flattening articles" "$pointer_fix_output"
fi

domain_renderers="$tmpdir/domain-renderers"
mkdir "$domain_renderers"
cp -R "$GOLDEN/." "$domain_renderers/"
mkdir -p "$domain_renderers/output/projects/example-project"
cat > "$domain_renderers/output/projects/example-project/WHY.md" <<'EOF'
# Example Project

Preserve project-aware output navigation while repairing the root index.
EOF
printf '# Dataset Registry Index\n' > "$domain_renderers/datasets/_index.md"
printf '# Output Artifacts\n' > "$domain_renderers/output/_index.md"
set +e
domain_fix_output="$("$CLI" lint --fix "$domain_renderers" 2>&1)"
domain_fix_rc=$?
set -e
if [ "$domain_fix_rc" -eq 0 ] \
  && grep -q '| Dataset | Status | Storage | Formats | Size | Records | Updated |' "$domain_renderers/datasets/_index.md" \
  && grep -q 'bitcointalk-temporal-graph/MANIFEST.md' "$domain_renderers/datasets/_index.md" \
  && grep -q '| Output | Type | Date |' "$domain_renderers/output/_index.md" \
  && grep -q 'projects/example-project/WHY.md' "$domain_renderers/output/_index.md"; then
  log_pass "--fix uses dataset and project-aware output renderers"
else
  log_fail "--fix uses dataset and project-aware output renderers" "$domain_fix_output"
fi

empty_contract_indexes="$tmpdir/empty-contract-indexes"
mkdir "$empty_contract_indexes"
cp -R "$GOLDEN/." "$empty_contract_indexes/"
rm -f "$empty_contract_indexes/output/_index.md" \
  "$empty_contract_indexes/output/sample-output.md" \
  "$empty_contract_indexes/datasets/_index.md"
rm -rf "$empty_contract_indexes/datasets/bitcointalk-temporal-graph"
sed -i.bak \
  's|  - output/sample-output.md|  - wiki/references/sample-reference.md|' \
  "$empty_contract_indexes/inventory/candidates/bitcointalk-archive.md"
sed -i.bak \
  's|\[Sample output\](../../output/sample-output.md)|[Sample reference](../../wiki/references/sample-reference.md)|' \
  "$empty_contract_indexes/inventory/candidates/bitcointalk-archive.md"
rm -f "$empty_contract_indexes/inventory/candidates/bitcointalk-archive.md.bak"
set +e
empty_contract_output="$("$CLI" lint --fix "$empty_contract_indexes" 2>&1)"
empty_contract_rc=$?
set -e
if [ "$empty_contract_rc" -eq 0 ] \
  && grep -q '^# Dataset Registry Index$' "$empty_contract_indexes/datasets/_index.md" \
  && grep -q '| Dataset | Status | Storage | Formats | Size | Records | Updated |' "$empty_contract_indexes/datasets/_index.md" \
  && grep -q '^# Output Artifacts$' "$empty_contract_indexes/output/_index.md" \
  && grep -q '| Output | Type | Date |' "$empty_contract_indexes/output/_index.md" \
  && ! grep -q 'Generated by local llm-wiki lint' "$empty_contract_indexes/datasets/_index.md" \
  && ! grep -q 'Generated by local llm-wiki lint' "$empty_contract_indexes/output/_index.md"; then
  log_pass "--fix creates empty root indexes with their declared renderers"
else
  log_fail "--fix creates empty root indexes with their declared renderers" "$empty_contract_output"
fi

readme_root="$tmpdir/readme-root"
mkdir "$readme_root"
cp -R "$GOLDEN/." "$readme_root/"
printf '# Wiki README\n' > "$readme_root/README.md"
set +e
readme_output="$("$CLI" lint --fix "$readme_root" 2>&1)"
readme_rc=$?
set -e
if [ "$readme_rc" -eq 0 ] \
  && [ -f "$readme_root/README.md" ] \
  && [ ! -e "$readme_root/inbox/.unknown/README.md" ]; then
  log_pass "--fix preserves README.md at any wiki root"
else
  log_fail "--fix preserves README.md at any wiki root" "$readme_output"
fi

git_root="$tmpdir/git-root"
mkdir "$git_root"
cp -R "$GOLDEN/." "$git_root/"
mkdir "$git_root/.git" "$git_root/.github"
for file in AGENTS.md CLAUDE.md CHANGELOG.md CODE_OF_CONDUCT.md \
  CONTRIBUTING.md SECURITY.md LICENSE LICENSE.md .gitignore .gitattributes \
  .gitmodules; do
  printf '# project metadata\n' > "$git_root/$file"
done
set +e
git_root_output="$("$CLI" lint --fix "$git_root" 2>&1)"
git_root_rc=$?
set -e
if [ "$git_root_rc" -eq 0 ] \
  && grep -q "Result: PASS" <<<"$git_root_output" \
  && [ -d "$git_root/.git" ] \
  && [ -d "$git_root/.github" ] \
  && [ -f "$git_root/AGENTS.md" ] \
  && [ -f "$git_root/.gitignore" ] \
  && [ ! -d "$git_root/inbox/.unknown" ]; then
  log_pass "--fix preserves conventional metadata at a Git-backed wiki root"
else
  log_fail "--fix preserves conventional metadata at a Git-backed wiki root" "$git_root_output"
fi

worktree_root="$tmpdir/worktree-root"
mkdir "$worktree_root"
cp -R "$GOLDEN/." "$worktree_root/"
printf 'gitdir: ../repo/.git/worktrees/wiki\n' > "$worktree_root/.git"
printf '# Agent instructions\n' > "$worktree_root/AGENTS.md"
set +e
worktree_output="$("$CLI" lint --fix "$worktree_root" 2>&1)"
worktree_rc=$?
set -e
if [ "$worktree_rc" -eq 0 ] \
  && [ -f "$worktree_root/.git" ] \
  && [ -f "$worktree_root/AGENTS.md" ] \
  && [ ! -d "$worktree_root/inbox/.unknown" ]; then
  log_pass "--fix recognizes a worktree .git file as a Git root"
else
  log_fail "--fix recognizes a worktree .git file as a Git root" "$worktree_output"
fi

expect_failure_contains \
  "missing-index fixture fails local lint" \
  "Required _index.md is missing" \
  "$CLI" lint "$SCRIPT_DIR/fixtures/defects/missing-index"

expect_failure_contains \
  "bad-frontmatter fixture fails local lint" \
  "Invalid type" \
  "$CLI" lint "$SCRIPT_DIR/fixtures/defects/bad-frontmatter"

ideas_wiki="$tmpdir/ideas-wiki"
mkdir "$ideas_wiki"
cp -R "$GOLDEN/." "$ideas_wiki/"
mkdir -p "$ideas_wiki/inventory/ideas"
cat > "$ideas_wiki/inventory/ideas/_index.md" <<'EOF'
# Ideas Index

> Cataloged proposals being researched and shaped before project commitment.

Last updated: 2026-01-03

## Contents

| File | Summary | Tags | Updated |
|------|---------|------|---------|
| [local-search.md](local-search.md) | Test the smallest useful local search product. | idea, local-first | 2026-01-03 |
EOF
cat > "$ideas_wiki/inventory/ideas/local-search.md" <<'EOF'
---
title: "Local Search"
kind: idea
status: active
priority: p1
created: 2026-01-03
updated: 2026-01-03
tags: [idea, local-first]
summary: "Test the smallest useful local search product."
next_action: "Approve or reject the shaped brief."
sources:
  - wiki/concepts/sample-concept.md
---

# Local Search

## Original Seed

Build a private local search tool.
EOF
cat >> "$ideas_wiki/inventory/_index.md" <<'EOF'

- [Ideas](ideas/_index.md)

| [local-search.md](ideas/local-search.md) | idea | active | p1 | Approve or reject the shaped brief. | 2026-01-03 |
EOF

expect_success \
  "idea records are valid in inventory/ideas" \
  "$CLI" lint "$ideas_wiki"

mv "$ideas_wiki/inventory/ideas/local-search.md" \
  "$ideas_wiki/inventory/candidates/local-search.md"
expect_failure_contains \
  "misplaced idea record is reported" \
  "File is in the wrong directory" \
  "$CLI" lint "$ideas_wiki"

set +e
idea_fix_output="$("$CLI" lint --fix "$ideas_wiki" 2>&1)"
idea_fix_rc=$?
set -e
if [ "$idea_fix_rc" -eq 0 ] \
  && grep -q "Moved inventory/candidates/local-search.md to inventory/ideas/local-search.md" <<<"$idea_fix_output" \
  && [ -f "$ideas_wiki/inventory/ideas/local-search.md" ]; then
  log_pass "--fix restores idea records to inventory/ideas"
else
  log_fail "--fix restores idea records to inventory/ideas" "$idea_fix_output"
fi

schema_migrate="$tmpdir/schema-migrate"
mkdir "$schema_migrate"
cp -R "$GOLDEN/." "$schema_migrate/"
rm -f "$schema_migrate/schema.md"

expect_success \
  "missing schema is an info-level topic-guide prompt, not a lint failure" \
  "$CLI" lint "$schema_migrate"

set +e
schema_dry_output="$("$CLI" schema migrate "$schema_migrate" 2>&1)"
schema_dry_rc=$?
set -e
if [ "$schema_dry_rc" -eq 0 ] \
  && grep -q "Would create default advisory topic guide" <<<"$schema_dry_output" \
  && [ ! -e "$schema_migrate/schema.md" ]; then
  log_pass "schema migrate dry-run does not write schema.md"
else
  log_fail "schema migrate dry-run does not write schema.md" "$schema_dry_output"
fi

set +e
schema_apply_output="$("$CLI" schema adopt "$schema_migrate" 2>&1)"
schema_apply_rc=$?
set -e
if [ "$schema_apply_rc" -eq 0 ] \
  && grep -q "Created advisory topic guide" <<<"$schema_apply_output" \
  && [ -f "$schema_migrate/schema.md" ] \
  && grep -q "schema_state: advisory" "$schema_migrate/schema.md" \
  && grep -q "^## Compile Guidance$" "$schema_migrate/schema.md" \
  && grep -q "does not exempt raw sources from C6 coverage" "$schema_migrate/schema.md" \
  && "$CLI" schema status "$schema_migrate" | grep -q "State: advisory"; then
  log_pass "schema adopt creates advisory schema.md"
else
  log_fail "schema adopt creates advisory schema.md" "$schema_apply_output"
fi

schema_migrate_compat="$tmpdir/schema-migrate-compat"
mkdir "$schema_migrate_compat"
cp -R "$GOLDEN/." "$schema_migrate_compat/"
rm -f "$schema_migrate_compat/schema.md"
set +e
schema_compat_output="$("$CLI" schema migrate --apply "$schema_migrate_compat" 2>&1)"
schema_compat_rc=$?
set -e
if [ "$schema_compat_rc" -eq 0 ] \
  && grep -q "Created advisory topic guide" <<<"$schema_compat_output" \
  && [ -f "$schema_migrate_compat/schema.md" ]; then
  log_pass "schema migrate --apply remains a compatibility alias"
else
  log_fail "schema migrate --apply remains a compatibility alias" "$schema_compat_output"
fi

set +e
schema_json_output="$("$CLI" schema status "$schema_migrate" --json 2>&1)"
schema_json_rc=$?
set -e
if [ "$schema_json_rc" -eq 0 ] \
  && python3 -c 'import json,sys; data=json.load(sys.stdin); assert data["state"] == "advisory"; assert data["schema_exists"] is True' <<<"$schema_json_output"; then
  log_pass "schema status supports --json after subcommand"
else
  log_fail "schema status supports --json after subcommand" "$schema_json_output"
fi

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

mkdir -p "$hub_scope/.sessions/state/codex"
echo '{}' > "$hub_scope/.sessions/state/codex/example.json"
expect_success \
  "hub lint allows operational .sessions layer" \
  "$CLI" lint "$hub_scope"

registry_portability="$tmpdir/registry-portability"
external_registry_wiki="$tmpdir/external-registry-wiki"
missing_registry_wiki="$tmpdir/missing-registry-wiki"
mkdir -p "$registry_portability/topics/portable-topic" "$external_registry_wiki"
cp -R "$GOLDEN/." "$registry_portability/topics/portable-topic/"
cp -R "$GOLDEN/." "$external_registry_wiki/"
cat > "$registry_portability/_index.md" <<'EOF'
# Hub Index
EOF
cat > "$registry_portability/log.md" <<'EOF'
# Hub Log
EOF
cat > "$registry_portability/wikis.json" <<JSON
{
  "default": "$registry_portability",
  "wikis": {
    "hub": { "path": "$registry_portability", "description": "Hub" },
    "portable-topic": {
      "path": "$registry_portability/topics/portable-topic",
      "description": "Portable topic"
    },
    "external-existing": {
      "path": "$external_registry_wiki",
      "description": "External existing wiki"
    },
    "external-missing": {
      "path": "$missing_registry_wiki",
      "description": "External missing wiki"
    }
  },
  "local_wikis": []
}
JSON
set +e
registry_report="$("$CLI" lint "$registry_portability" --json 2>&1)"
registry_report_rc=$?
set -e
if [ "$registry_report_rc" -ne 0 ] \
  && python3 -c '
import json, sys
report = json.load(sys.stdin)
messages = "\n".join(item["message"] for item in report["issues"])
assert report["counts"] == {"critical": 0, "info": 1, "suggestion": 3, "warning": 1}
assert "default should use the portable <HUB> token" in messages
assert "Hub registry entry should use portable path <HUB>" in messages
assert "Hub-owned wiki path should be portable: use topics/portable-topic" in messages
assert "external local absolute path that exists" in messages
assert "external local absolute path that does not exist" in messages
' <<<"$registry_report"; then
  log_pass "hub lint reports portable and external registry paths distinctly"
else
  log_fail "hub lint reports portable and external registry paths distinctly" "$registry_report"
fi

set +e
registry_fix_report="$("$CLI" lint "$registry_portability" --fix --json 2>&1)"
registry_fix_rc=$?
set -e
if [ "$registry_fix_rc" -ne 0 ] \
  && python3 - "$registry_portability/wikis.json" "$external_registry_wiki" "$missing_registry_wiki" <<'PY'
import json
import sys

registry = json.load(open(sys.argv[1], encoding="utf-8"))
assert registry["default"] == "<HUB>"
assert registry["wikis"]["hub"]["path"] == "<HUB>"
assert registry["wikis"]["portable-topic"]["path"] == "topics/portable-topic"
assert registry["wikis"]["external-existing"]["path"] == sys.argv[2]
assert registry["wikis"]["external-missing"]["path"] == sys.argv[3]
PY
then
  log_pass "--fix rewrites only hub-owned registry paths"
else
  log_fail "--fix rewrites only hub-owned registry paths" "$registry_fix_report"
fi

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
