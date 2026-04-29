# llm-wiki Tests

Three-layer test suite for the llm-wiki Claude Code plugin.

## Layer 1: Structural Validation ($0, every push)

No LLM calls. Validates wiki file structure, frontmatter schema, index integrity, cross-references, and file placement against a golden wiki fixture.

```bash
# Generate defect fixtures (run once, or after changing golden-wiki)
./tests/generate-defect-fixtures.sh

# Run structural tests
./tests/test-structure.sh

# Validate plugin manifest
./tests/test-plugin-validate.sh
```

### What it checks

- C1: Every directory has `_index.md`
- C2: Required frontmatter fields present, enum values valid
- C3: Index entries match actual files (no stale entries, no unlisted files)
- C4: See Also links resolve to existing articles
- C4b: Source references point to existing raw files, no retracted markers
- C5: No near-duplicate tags (via defect fixture)
- C6: No orphan sources (via defect fixture)
- C11: File placement matches frontmatter type/category
- C12: No unknown file types in raw/wiki directories

### Defect fixtures

`generate-defect-fixtures.sh` creates 11 broken wikis from the golden fixture, one per lint rule. Each has exactly one defect. The structural test verifies each defect is correctly present (negative testing).

## Layer 2: Behavioral Evals (~$2-5/run, on PR merge)

Uses Promptfoo with the Claude Agent SDK to test plugin behavior.

```bash
# Install promptfoo
npm install -g promptfoo

# Run evals
promptfoo eval -c tests/promptfooconfig.yaml

# Run with variance measurement
promptfoo eval -c tests/promptfooconfig.yaml --repeat 3
```

### What it tests

- Fuzzy router dispatches research/URL/question intents correctly
- Audit/trust prompts dispatch to the audit workflow
- Negative control: ambiguous input triggers clarification
- Plugin loads without errors

### Custom assertions

- `evals/assertions/check-raw-source.js` — verifies raw source files have correct frontmatter
- `evals/assertions/check-index-integrity.js` — verifies all directories have `_index.md`
- `evals/assertions/check-frontmatter.js` — validates frontmatter schema with enum checks

## CI

Copy `tests/ci/plugin-tests.yml` to `.github/workflows/` to enable:

- Structural tests run on every push to `claude-plugin/**` or `tests/**`
- Behavioral evals run on PRs only (requires `ANTHROPIC_API_KEY` secret)

## Fixtures

- `fixtures/golden-wiki/` — minimal but complete wiki with 3 sources, 2 articles, correct indexes and cross-references
- `fixtures/defects/` — generated broken wikis (one per lint rule)
- `fixtures/expected-violations/` — expected lint output per defect (placeholder for future use)
