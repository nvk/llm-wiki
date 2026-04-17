#!/bin/bash
# Generate defect fixtures from the golden wiki — one defect per lint rule
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GOLDEN="$SCRIPT_DIR/fixtures/golden-wiki"
DEFECTS="$SCRIPT_DIR/fixtures/defects"

if [ ! -d "$GOLDEN" ]; then
  echo "ERROR: Golden wiki not found at $GOLDEN"
  exit 1
fi

rm -rf "$DEFECTS"
mkdir -p "$DEFECTS"

echo "Generating defect fixtures from golden wiki..."

# C1: missing-index — delete raw/articles/_index.md
cp -r "$GOLDEN" "$DEFECTS/missing-index"
rm "$DEFECTS/missing-index/raw/articles/_index.md"
echo "  Created: missing-index (C1)"

# C2: bad-frontmatter — invalid type enum
cp -r "$GOLDEN" "$DEFECTS/bad-frontmatter"
sed -i.bak 's/^type: articles$/type: invalid/' \
  "$DEFECTS/bad-frontmatter/raw/articles/2026-01-01-sample-article.md"
rm -f "$DEFECTS/bad-frontmatter/raw/articles/2026-01-01-sample-article.md.bak"
echo "  Created: bad-frontmatter (C2)"

# C3: stale-index — file exists but not in index
cp -r "$GOLDEN" "$DEFECTS/stale-index"
cp "$DEFECTS/stale-index/raw/articles/2026-01-01-sample-article.md" \
   "$DEFECTS/stale-index/raw/articles/2026-01-03-unlisted.md"
echo "  Created: stale-index (C3)"

# C3: dead-index-entry — index row points to nonexistent file
cp -r "$GOLDEN" "$DEFECTS/dead-index-entry"
echo '| 2026-01-05 | [Ghost Article](nonexistent.md) | 3/5 | ghost |' \
  >> "$DEFECTS/dead-index-entry/raw/articles/_index.md"
echo "  Created: dead-index-entry (C3)"

# C4: broken-link — See Also points to nonexistent article
cp -r "$GOLDEN" "$DEFECTS/broken-link"
sed -i.bak 's|sample-reference.md|nonexistent.md|g' \
  "$DEFECTS/broken-link/wiki/concepts/sample-concept.md"
rm -f "$DEFECTS/broken-link/wiki/concepts/sample-concept.md.bak"
echo "  Created: broken-link (C4)"

# C4: broken-inline-body-link — inline body prose link points to nonexistent article
cp -r "$GOLDEN" "$DEFECTS/broken-inline-body-link"
sed -i.bak 's|(../references/sample-reference.md)|(../references/nonexistent-inline.md)|' \
  "$DEFECTS/broken-inline-body-link/wiki/concepts/sample-concept.md"
rm -f "$DEFECTS/broken-inline-body-link/wiki/concepts/sample-concept.md.bak"
echo "  Created: broken-inline-body-link (C4)"

# C4b: dangling-source-ref — sources: entry points to deleted file
cp -r "$GOLDEN" "$DEFECTS/dangling-source-ref"
sed -i.bak '/^  - raw\/papers/a\
  - raw/articles/2026-01-03-deleted.md' \
  "$DEFECTS/dangling-source-ref/wiki/concepts/sample-concept.md"
rm -f "$DEFECTS/dangling-source-ref/wiki/concepts/sample-concept.md.bak"
echo "  Created: dangling-source-ref (C4b)"

# C4b: retracted-marker — <!--RETRACTED-SOURCE--> left in body
cp -r "$GOLDEN" "$DEFECTS/retracted-marker"
echo '<!--RETRACTED-SOURCE: previously cited claim from deleted source-->' \
  >> "$DEFECTS/retracted-marker/wiki/concepts/sample-concept.md"
echo "  Created: retracted-marker (C4b)"

# C5: duplicate-tags — ml and machine-learning
cp -r "$GOLDEN" "$DEFECTS/duplicate-tags"
sed -i.bak 's/tags: \[testing, patterns\]/tags: [ml, patterns]/' \
  "$DEFECTS/duplicate-tags/raw/articles/2026-01-01-sample-article.md"
sed -i.bak 's/tags: \[testing, patterns, evals\]/tags: [machine-learning, patterns, evals]/' \
  "$DEFECTS/duplicate-tags/wiki/concepts/sample-concept.md"
rm -f "$DEFECTS"/duplicate-tags/raw/articles/*.bak "$DEFECTS"/duplicate-tags/wiki/concepts/*.bak
echo "  Created: duplicate-tags (C5)"

# C6: orphan-source — raw source referenced by zero articles
cp -r "$GOLDEN" "$DEFECTS/orphan-source"
cat > "$DEFECTS/orphan-source/raw/articles/2026-01-03-orphan.md" << 'ENDOFFILE'
---
title: "Orphan Source"
source: https://example.com/orphan
type: articles
ingested: 2026-01-03
tags: [orphan]
summary: "A source no article references."
---

# Orphan Source

This source is not referenced by any wiki article.
ENDOFFILE
echo "  Created: orphan-source (C6)"

# C11: misplaced-file — concept article in references/ directory
cp -r "$GOLDEN" "$DEFECTS/misplaced-file"
mv "$DEFECTS/misplaced-file/wiki/concepts/sample-concept.md" \
   "$DEFECTS/misplaced-file/wiki/references/sample-concept.md"
echo "  Created: misplaced-file (C11)"

# C12: unknown-file — .txt file in raw/
cp -r "$GOLDEN" "$DEFECTS/unknown-file"
echo "this is not a markdown file" > "$DEFECTS/unknown-file/raw/stray.txt"
echo "  Created: unknown-file (C12)"

COUNT=$(ls -d "$DEFECTS"/*/ 2>/dev/null | wc -l | tr -d ' ')
echo ""
echo "Generated $COUNT defect fixtures"
