# llm-wiki Tests

Three-layer test suite plus token-efficiency regression benchmarks for the
llm-wiki plugin.

## Layer 0: Context Budgets ($0, every push)

Deterministic byte/character ceilings catch prompt, skill, metadata, and lazy
reference growth before model calls are needed.

```bash
./tests/test-token-benchmarks.sh
./tests/test-query-lite-sync.sh
./scripts/benchmark-token-efficiency static --check
```

The test also exercises complete Codex app-server and Claude stream-json
accounting paths with fake providers. Real model runs and AB/BA comparisons are
explicit and cost-bearing; see
[`../benchmarks/README.md`](../benchmarks/README.md).

## Layer 1: Structural Validation ($0, every push)

No LLM calls. Validates wiki file structure, default `schema.md`, frontmatter schema, index integrity, cross-references, and file placement against a golden wiki fixture.

```bash
# Generate defect fixtures (run once, or after changing golden-wiki)
./tests/generate-defect-fixtures.sh

# Run structural tests
./tests/test-structure.sh
./tests/test-local-cli-lint.sh

# Validate plugin manifest and docs/version consistency
./tests/test-plugin-validate.sh
./tests/test-docs-consistency.sh
```

### What it checks

- C1: Every existing wiki-managed directory has `_index.md`
- Topic guide defaults: golden wikis include advisory `schema.md`; missing guides
  are info-level prompts and `schema adopt` writes a starter
- C2: Required frontmatter fields present, enum values valid
- C3: Index entries match actual files (no stale entries, no unlisted files)
- C4: See Also links resolve to existing articles
- C4b: Source references point to existing raw files, no retracted markers
- C5: No near-duplicate tags (via defect fixture)
- C6: No orphan sources (via defect fixture)
- C11: File placement matches frontmatter type/category
- C12: No unknown file types in raw/wiki directories
- Docs consistency: README command table, plugin/marketplace versions, and
  reference-file allowlists stay synchronized
- Token budgets: checked-in context surfaces stay below explicit ceilings
- Codex/Claude accounting: tokens, cache creation/reads, cost, latency, fixture
  reads, quality, write detection, and case/fixture corpus hashes are parsed and
  gated deterministically
- Query presets: Claude command, explicit Codex skill, portable profile, and
  Pi/DS4 launcher remain read-only and synchronized from one canonical protocol
- OpenCode: full and query packages remain generated and within static budgets;
  live provider/model behavior is best effort
- GitHub Copilot: generated Agent Plugin preserves canonical command parity,
  copied references, read-only query behavior, cross-platform hooks, and
  static package budgets; CLI install remains a Preview manual smoke

### Defect fixtures

`generate-defect-fixtures.sh` creates broken wikis from the golden fixture, one per lint rule. Each has exactly one defect. The structural test verifies each defect is correctly present (negative testing).

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

- Structural tests run when plugin, profile, benchmark, script, or docs inputs change
- Static token budgets and benchmark protocol tests run on every push
- Codex/OpenCode/Copilot mirrors and the portable query profile are regenerated and checked
- Behavioral evals run on PRs only (requires `ANTHROPIC_API_KEY` secret)

## Fixtures

- `fixtures/golden-wiki/` — minimal but complete wiki with 4 sources, 2 articles, advisory schema, correct indexes and cross-references
- `fixtures/defects/` — generated broken wikis (one per lint rule)
- `fixtures/expected-violations/` — expected lint output per defect (placeholder for future use)
