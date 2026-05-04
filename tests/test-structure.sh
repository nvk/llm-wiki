#!/bin/bash
# Layer 1: Structural validation — runs without LLM, asserts on file system
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURES="$SCRIPT_DIR/fixtures"
GOLDEN="$FIXTURES/golden-wiki"
DEFECTS="$FIXTURES/defects"
PASS=0
FAIL=0
TOTAL=0

log_pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[32mPASS\033[0m: %s\n" "$1"; }
log_fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[31mFAIL\033[0m: %s — %s\n" "$1" "$2"; }

echo "=== Layer 1: Structural Validation ==="

# ─── Golden wiki positive tests ───────────────────────────────────

echo ""
echo "--- C1: Structure (every directory has _index.md) ---"

for dirname in raw raw/articles raw/papers raw/repos raw/notes raw/data \
               wiki wiki/concepts wiki/topics wiki/references wiki/theses output; do
  if [ -f "$GOLDEN/$dirname/_index.md" ]; then
    log_pass "_index.md exists in $dirname"
  else
    log_fail "_index.md missing in $dirname" "C1 violation"
  fi
done

if [ -f "$GOLDEN/_index.md" ]; then log_pass "master _index.md exists"; else log_fail "master _index.md missing" "C1"; fi
if [ -f "$GOLDEN/config.md" ]; then log_pass "config.md exists"; else log_fail "config.md missing" "C1"; fi

echo ""
echo "--- C2: Frontmatter (required fields) ---"

# Raw sources: title, source, type, ingested, tags, summary
while IFS= read -r -d '' file; do
  bn=$(basename "$file")
  for field in title source type ingested tags summary; do
    if grep -q "^${field}:" "$file"; then
      log_pass "$field present in $bn"
    else
      log_fail "$field missing in $bn" "C2 violation"
    fi
  done
done < <(find "$GOLDEN/raw" -name "*.md" -not -name "_index.md" -print0)

# Wiki articles: title, category, sources, created, updated, tags, confidence, summary
while IFS= read -r -d '' file; do
  bn=$(basename "$file")
  for field in title category sources created updated tags confidence summary; do
    if grep -q "^${field}:" "$file"; then
      log_pass "$field present in $bn"
    else
      log_fail "$field missing in $bn" "C2 violation"
    fi
  done
done < <(find "$GOLDEN/wiki" -name "*.md" -not -name "_index.md" -print0)

echo ""
echo "--- C2: Enum validation ---"

# type enum for raw sources
while IFS= read -r -d '' file; do
  bn=$(basename "$file")
  type_val=$(grep "^type:" "$file" | head -1 | sed 's/type: *//')
  case "$type_val" in
    articles|papers|repos|notes|data) log_pass "valid type '$type_val' in $bn" ;;
    *) log_fail "invalid type '$type_val' in $bn" "C2 violation" ;;
  esac
done < <(find "$GOLDEN/raw" -name "*.md" -not -name "_index.md" -print0)

# category enum for wiki articles
while IFS= read -r -d '' file; do
  bn=$(basename "$file")
  cat_val=$(grep "^category:" "$file" | head -1 | sed 's/category: *//')
  case "$cat_val" in
    concept|topic|reference) log_pass "valid category '$cat_val' in $bn" ;;
    *) log_fail "invalid category '$cat_val' in $bn" "C2 violation" ;;
  esac
done < <(find "$GOLDEN/wiki" -name "*.md" -not -name "_index.md" -print0)

# confidence enum
while IFS= read -r -d '' file; do
  bn=$(basename "$file")
  conf_val=$(grep "^confidence:" "$file" | head -1 | sed 's/confidence: *//')
  case "$conf_val" in
    high|medium|low) log_pass "valid confidence '$conf_val' in $bn" ;;
    *) log_fail "invalid confidence '$conf_val' in $bn" "C2 violation" ;;
  esac
done < <(find "$GOLDEN/wiki" -name "*.md" -not -name "_index.md" -print0)

# volatility enum
while IFS= read -r -d '' file; do
  bn=$(basename "$file")
  # Check volatility field (new schema)
  vol=$(grep "^volatility:" "$file" | head -1 | sed 's/volatility: *//')
  if [ -n "$vol" ]; then
    case "$vol" in
      hot|warm|cold) log_pass "valid volatility '$vol' in $bn" ;;
      *) log_fail "invalid volatility '$vol' in $bn" "expected hot|warm|cold" ;;
    esac
  fi
done < <(find "$GOLDEN/wiki" -name "*.md" -not -name "_index.md" -print0)

echo ""
echo "--- C3: Index consistency ---"

for subdir in articles papers repos notes data; do
  dir="$GOLDEN/raw/$subdir"
  index="$dir/_index.md"
  [ -f "$index" ] || continue
  while IFS= read -r -d '' file; do
    bn=$(basename "$file")
    if grep -q "$bn" "$index"; then
      log_pass "$bn listed in raw/$subdir/_index.md"
    else
      log_fail "$bn NOT listed in raw/$subdir/_index.md" "C3 violation"
    fi
  done < <(find "$dir" -maxdepth 1 -name "*.md" -not -name "_index.md" -print0)
done

for subdir in concepts topics references theses; do
  dir="$GOLDEN/wiki/$subdir"
  index="$dir/_index.md"
  [ -f "$index" ] || continue
  while IFS= read -r -d '' file; do
    bn=$(basename "$file")
    if grep -q "$bn" "$index"; then
      log_pass "$bn listed in wiki/$subdir/_index.md"
    else
      log_fail "$bn NOT listed in wiki/$subdir/_index.md" "C3 violation"
    fi
  done < <(find "$dir" -maxdepth 1 -name "*.md" -not -name "_index.md" -print0)
done

echo ""
echo "--- C4b: Source provenance ---"

while IFS= read -r -d '' file; do
  bn=$(basename "$file")
  in_sources=false
  while IFS= read -r line; do
    if echo "$line" | grep -q "^sources:"; then
      in_sources=true; continue
    fi
    if $in_sources; then
      if echo "$line" | grep -q "^  - "; then
        ref=$(echo "$line" | sed 's/^  - //' | sed 's/^"//;s/"$//;s/^'\''//;s/'\''$//')
        if [ -f "$GOLDEN/$ref" ]; then
          log_pass "source ref exists: $ref (in $bn)"
        else
          log_fail "dangling source ref: $ref (in $bn)" "C4b violation"
        fi
      else
        in_sources=false
      fi
    fi
  done < "$file"
done < <(find "$GOLDEN/wiki" -name "*.md" -not -name "_index.md" -print0)

if grep -rl "RETRACTED-SOURCE" "$GOLDEN" >/dev/null 2>&1; then
  log_fail "retracted-source marker found" "C4b violation"
else
  log_pass "no retracted-source markers"
fi

echo ""
echo "--- C4: Link integrity (all body links) ---"

# Extract ALL relative .md links from wiki articles and check they resolve.
# This covers See Also, Sources, and inline body prose links.
while IFS= read -r -d '' file; do
  bn=$(basename "$file")
  filedir=$(dirname "$file")
  # Match ](path.md) and ](<path with spaces.md>) anywhere in the file.
  while IFS= read -r link; do
    target=$(python3 -c "import os,sys; print(os.path.normpath(sys.argv[1]))" "$filedir/$link")
    if [ -f "$target" ]; then
      log_pass "link resolves: $link (in $bn)"
    else
      log_fail "broken link: $link (in $bn)" "C4 violation"
    fi
  done < <(python3 - "$file" <<'PY'
import re
import sys

text = open(sys.argv[1], encoding="utf-8").read()
for match in re.finditer(r"\]\((<([^>\n]+\.md)>|([^)\n]+\.md))\)", text):
    link = match.group(2) or match.group(3)
    if "://" not in link:
        print(link)
PY
)
done < <(find "$GOLDEN/wiki" -name "*.md" -not -name "_index.md" -print0)

echo ""
echo "--- C11: File placement ---"

while IFS= read -r -d '' file; do
  bn=$(basename "$file")
  type_val=$(grep "^type:" "$file" | head -1 | sed 's/type: *//')
  parent_dir=$(basename "$(dirname "$file")")
  if [ "$type_val" = "$parent_dir" ]; then
    log_pass "placement correct: $bn (type=$type_val)"
  else
    log_fail "misplaced: $bn (type=$type_val but in $parent_dir/)" "C11 violation"
  fi
done < <(find "$GOLDEN/raw" -name "*.md" -not -name "_index.md" -print0)

while IFS= read -r -d '' file; do
  bn=$(basename "$file")
  cat_val=$(grep "^category:" "$file" | head -1 | sed 's/category: *//')
  parent_dir=$(basename "$(dirname "$file")")
  expected="${cat_val}s"
  if [ "$expected" = "$parent_dir" ]; then
    log_pass "placement correct: $bn (category=$cat_val)"
  else
    log_fail "misplaced: $bn (category=$cat_val but in $parent_dir/)" "C11 violation"
  fi
done < <(find "$GOLDEN/wiki" -name "*.md" -not -name "_index.md" -print0)

echo ""
echo "--- Log format ---"

if [ -f "$GOLDEN/log.md" ] && grep -q '^## \[' "$GOLDEN/log.md"; then
  log_pass "log.md has valid entries"
else
  log_fail "log.md missing or no valid entries" "format violation"
fi

# ─── Defect fixture negative tests ────────────────────────────────

if [ -d "$DEFECTS" ]; then
  echo ""
  echo "--- Defect fixtures (negative tests) ---"

  [ -d "$DEFECTS/missing-index" ] && {
    [ ! -f "$DEFECTS/missing-index/raw/articles/_index.md" ] \
      && log_pass "missing-index: C1 defect present" \
      || log_fail "missing-index: _index.md still exists" "fixture broken"
  }

  [ -d "$DEFECTS/bad-frontmatter" ] && {
    grep -q "^type: invalid" "$DEFECTS/bad-frontmatter/raw/articles/2026-01-01-sample-article.md" 2>/dev/null \
      && log_pass "bad-frontmatter: C2 defect present" \
      || log_fail "bad-frontmatter: type still valid" "fixture broken"
  }

  [ -d "$DEFECTS/stale-index" ] && {
    [ -f "$DEFECTS/stale-index/raw/articles/2026-01-03-unlisted.md" ] \
      && ! grep -q "unlisted" "$DEFECTS/stale-index/raw/articles/_index.md" 2>/dev/null \
      && log_pass "stale-index: C3 defect present" \
      || log_fail "stale-index: defect not correct" "fixture broken"
  }

  [ -d "$DEFECTS/dead-index-entry" ] && {
    grep -q "nonexistent.md" "$DEFECTS/dead-index-entry/raw/articles/_index.md" 2>/dev/null \
      && [ ! -f "$DEFECTS/dead-index-entry/raw/articles/nonexistent.md" ] \
      && log_pass "dead-index-entry: C3 defect present" \
      || log_fail "dead-index-entry: defect not correct" "fixture broken"
  }

  [ -d "$DEFECTS/broken-link" ] && {
    grep -q "nonexistent.md" "$DEFECTS/broken-link/wiki/concepts/sample-concept.md" 2>/dev/null \
      && log_pass "broken-link: C4 defect present" \
      || log_fail "broken-link: no broken link" "fixture broken"
  }

  [ -d "$DEFECTS/broken-inline-body-link" ] && {
    grep -q "nonexistent-inline.md" "$DEFECTS/broken-inline-body-link/wiki/concepts/sample-concept.md" 2>/dev/null \
      && log_pass "broken-inline-body-link: C4 defect present" \
      || log_fail "broken-inline-body-link: no broken inline link" "fixture broken"
  }

  [ -d "$DEFECTS/dangling-source-ref" ] && {
    grep -q "2026-01-03-deleted.md" "$DEFECTS/dangling-source-ref/wiki/concepts/sample-concept.md" 2>/dev/null \
      && log_pass "dangling-source-ref: C4b defect present" \
      || log_fail "dangling-source-ref: no dangling ref" "fixture broken"
  }

  [ -d "$DEFECTS/retracted-marker" ] && {
    grep -q "RETRACTED-SOURCE" "$DEFECTS/retracted-marker/wiki/concepts/sample-concept.md" 2>/dev/null \
      && log_pass "retracted-marker: C4b defect present" \
      || log_fail "retracted-marker: no marker" "fixture broken"
  }

  [ -d "$DEFECTS/duplicate-tags" ] && {
    grep -q "tags: \[ml, patterns\]" "$DEFECTS/duplicate-tags/raw/articles/2026-01-01-sample-article.md" 2>/dev/null \
      && grep -q "tags: \[machine-learning, patterns, evals\]" "$DEFECTS/duplicate-tags/wiki/concepts/sample-concept.md" 2>/dev/null \
      && log_pass "duplicate-tags: C5 defect present" \
      || log_fail "duplicate-tags: defect not correct" "fixture broken"
  }

  [ -d "$DEFECTS/orphan-source" ] && {
    [ -f "$DEFECTS/orphan-source/raw/articles/2026-01-03-orphan.md" ] \
      && log_pass "orphan-source: C6 defect present" \
      || log_fail "orphan-source: no orphan file" "fixture broken"
  }

  [ -d "$DEFECTS/misplaced-file" ] && {
    [ -f "$DEFECTS/misplaced-file/wiki/references/sample-concept.md" ] \
      && grep -q "^category: concept" "$DEFECTS/misplaced-file/wiki/references/sample-concept.md" 2>/dev/null \
      && log_pass "misplaced-file: C11 defect present" \
      || log_fail "misplaced-file: defect not correct" "fixture broken"
  }

  [ -d "$DEFECTS/unknown-file" ] && {
    [ -f "$DEFECTS/unknown-file/raw/stray.txt" ] \
      && log_pass "unknown-file: C12 defect present" \
      || log_fail "unknown-file: no stray file" "fixture broken"
  }

  [ -d "$DEFECTS/stale-article" ] && {
    grep -q "volatility: hot" "$DEFECTS/stale-article/wiki/concepts/sample-concept.md" 2>/dev/null \
      && grep -q "verified: 2025-01-01" "$DEFECTS/stale-article/wiki/concepts/sample-concept.md" 2>/dev/null \
      && log_pass "stale-article: C14 defect present" \
      || log_fail "stale-article: no stale volatility/verified" "fixture broken"
  }

  [ -d "$DEFECTS/missing-volatility" ] && {
    ! grep -q "^volatility:" "$DEFECTS/missing-volatility/wiki/concepts/sample-concept.md" 2>/dev/null \
      && log_pass "missing-volatility: C15 defect present" \
      || log_fail "missing-volatility: volatility field still present" "fixture broken"
  }
else
  echo ""
  echo "--- No defect fixtures (run generate-defect-fixtures.sh first) ---"
fi

# ─── Summary ──────────────────────────────────────────────────────

echo ""
echo "==========================================="
printf "Results: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m, %d total\n" "$PASS" "$FAIL" "$TOTAL"
echo "==========================================="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
