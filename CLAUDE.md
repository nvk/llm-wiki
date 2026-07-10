# llm-wiki Development Guide

## Testing

Run tests before declaring any change to plugin code done.

## GitHub Auth And Transport

Agents should use GitHub CLI web login and HTTPS git transport, not SSH. SSH
host-key prompts and `known_hosts` writes are fragile inside nono profiles, and
public plugin updates do not need SSH.

Expected setup:

```bash
gh auth login --web --git-protocol https
gh auth setup-git
```

When pushing from an agent session, prefer an explicit HTTPS URL with gh's git
credential helper so the command does not depend on the checkout's `origin`
remote using SSH:

```bash
git -c credential.helper='!gh auth git-credential' push https://github.com/nvk/llm-wiki.git <branch>:master
```

If a marketplace checkout has an SSH remote, switch it to HTTPS before updating:

```bash
git -C ~/.claude/plugins/marketplaces/llm-wiki remote set-url origin https://github.com/nvk/llm-wiki.git
```

### Structural tests (always run — no LLM, instant)

```bash
./tests/test-plugin-validate.sh   # plugin manifest + command frontmatter
./tests/test-docs-consistency.sh   # README command table + manifest/version drift
./tests/test-structure.sh          # wiki fixture validation (84 assertions)
./tests/test-local-cli-lint.sh     # local scripts/llm-wiki lint helper
./tests/test-session-capture.sh    # deterministic session capture helper
./tests/test-session-concurrency.sh # concurrent session-state regression
./tests/test-hermes-runtime.sh     # optional Hermes session adapter
./tests/test-codex-sync.sh         # Codex plugin mirror matches Claude source
./tests/test-opencode-sync.sh     # OpenCode plugin mirror matches Claude source
./tests/test-token-benchmarks.sh  # budgets + fake Codex/Claude protocol fixtures
./tests/test-query-lite-sync.sh   # shared query profile + read-only DS4 launcher
```

### Codex runtime smoke test (run when touching Codex packaging/docs)

```bash
./tests/test-codex-runtime.sh      # @wiki resolution + explicit-only $wiki-query install
```

### Token-efficiency benchmark (run when changing routing or context loading)

```bash
./scripts/benchmark-token-efficiency static --check
```

The static gate is free and deterministic. Real Codex, Claude, and AB/BA
commands consume account quota; see `benchmarks/README.md` before running them.

`test-codex-sync.sh` and `test-opencode-sync.sh` are self-healing: if they fail,
the sync script has already regenerated the target directory — stage and commit
the result, then re-run. Read the FAIL message; it tells you exactly what to do.

If you changed the golden wiki fixture, regenerate defect fixtures first:

```bash
./tests/generate-defect-fixtures.sh
```

### Behavioral evals (run when changing command logic)

```bash
npx promptfoo@latest eval -c tests/promptfooconfig.yaml
```

Requires `ANTHROPIC_API_KEY`. Costs ~$2-5 per run.

### When to update tests

- **Added a new lint rule**: add a defect fixture in `generate-defect-fixtures.sh` and a negative test case in `test-structure.sh`.
- **Changed frontmatter schema** (new required field, renamed enum): update the golden wiki fixture files to match, update `test-structure.sh` field/enum lists, regenerate defect fixtures.
- **Added a new command**: add a frontmatter check to `test-plugin-validate.sh` if it's not picked up by the wildcard. Add a behavioral eval in `promptfooconfig.yaml` for routing.
- **Changed user-facing command docs or versions**: update README command rows and all plugin/marketplace manifest versions together, then run `test-docs-consistency.sh`.
- **Changed the fuzzy router**: add or update test cases in `promptfooconfig.yaml` covering the new routing behavior plus negative controls.
- **Added a new reference file**: `test-plugin-validate.sh` has three `for ref in ...` loops (Claude-side existence, Codex-side copied-reference validation, OpenCode-side symlink reachability) — add the new filename to all three.
- **Changed `references/query-lite.md`**: run `scripts/sync-query-lite-profile.sh`, `scripts/sync-codex-plugin.sh`, and `scripts/sync-opencode-plugin.sh`, then run `tests/test-query-lite-sync.sh` and the two mirror sync tests.
- **Changed directory structure** (new `raw/` or `wiki/` subdirectory): update `test-structure.sh` C1 directory list and C11 placement checks. Update the golden wiki fixture if needed.
- **Edited `claude-plugin/skills/wiki-manager/`**: both `test-codex-sync.sh` and `test-opencode-sync.sh` will fail until you re-run both sync scripts and commit `plugins/`. Never edit `plugins/llm-wiki/` or `plugins/llm-wiki-opencode/` by hand — they are generated. Codex gets copied references for marketplace caching; OpenCode keeps a symlink into the Claude source.
- **Added a runtime-specific text rewrite to a sync script**: update the corresponding sync script's SKILL.md replacement list. References are runtime-neutral and shared verbatim — do not add per-file replacements there.
- **Changed Codex install docs or bootstrap flow**: run `./tests/test-codex-runtime.sh` to verify a user-scoped install materializes the plugin cache, resolves `@wiki`, and installs `$wiki-query` as explicit-only from a clean scratch Codex home without an interactive `/plugins` step. Codex 0.144 reads plugin enablement from user config, not project config; the test also guards the unsupported project-scope path.
- **Changed the Hermes adapter or session engine API**: run `./tests/test-hermes-runtime.sh`. Keep Hermes support session-only: do not bundle another skill copy, register tools, inject ambient wiki memory, or mutate Hermes skill/config state.

### Test file locations

- `tests/fixtures/golden-wiki/` — known-correct wiki (3 sources, 2 articles, all indexes)
- `tests/fixtures/defects/` — generated broken wikis (one per lint rule)
- `tests/promptfooconfig.yaml` — Promptfoo behavioral eval config
- `tests/evals/assertions/*.js` — custom JS assertions for file-system checks
- `tests/ci/plugin-tests.yml` — GitHub Actions workflow (copy to `.github/workflows/` to activate)

## Project Structure

```
claude-plugin/                  — source of truth, primary distribution target
  commands/*.md                 — command specs, including user commands, wiki router, and the deprecated thesis shim
  skills/wiki-manager/
    SKILL.md                    — skill manifest + fuzzy router
    references/*.md             — reference docs (hub-resolution, archive, linting, audit, etc.)
  .claude-plugin/
    plugin.json                 — plugin manifest
plugins/llm-wiki/               — generated Codex packaging mirror (do NOT hand-edit)
  skills/wiki/
    SKILL.md                    — patched copy of claude-plugin SKILL.md
    references/*.md             — copied from claude-plugin/skills/wiki-manager/references
    agents/openai.yaml          — Codex UI metadata (generated)
  skills/wiki-query/
    SKILL.md                    — compact explicit-only read-only query preset
    agents/openai.yaml          — explicit-only Codex UI policy (generated)
  .codex-plugin/plugin.json     — Codex manifest (version synced from Claude)
plugins/llm-wiki-opencode/      — generated OpenCode packaging mirror (do NOT hand-edit)
  skills/wiki-manager/
    SKILL.md                    — patched copy of claude-plugin SKILL.md
    references → ../../../../claude-plugin/skills/wiki-manager/references  (symlink)
  README.md                     — OpenCode install instructions
  skills/wiki-query/SKILL.md    — best-effort compact read-only preset
plugins/llm-wiki-hermes/        — thin optional Hermes session hooks; no skills/tools/config mutation
profiles/query-lite/SKILL.md    — portable generated read-only query profile
.agents/plugins/marketplace.json — repo-local Codex marketplace entry
scripts/sync-codex-plugin.sh    — regenerates plugins/llm-wiki/ from claude-plugin/
scripts/sync-opencode-plugin.sh — regenerates plugins/llm-wiki-opencode/ from claude-plugin/
scripts/sync-query-lite-profile.sh — regenerates profiles/query-lite/ from the canonical reference
scripts/pi-wiki-query           — generic read-only Pi launcher
scripts/pi-ds4-wiki-query       — isolated read-only Pi/DS4 launcher
AGENTS.md                       — portable single-file protocol for non-Claude agents
tests/                          — test suite (see above)
```

## Release Process

See `.claude/release-checklist.md` for the full ship process. Run all structural tests before bumping version.
