# llm-wiki Development Guide

## Testing

Run tests before declaring any change to plugin code done.

### Structural tests (always run — no LLM, instant)

```bash
./tests/test-plugin-validate.sh   # plugin manifest + command frontmatter
./tests/test-structure.sh          # wiki fixture validation (84 assertions)
./tests/test-codex-sync.sh         # Codex plugin mirror matches Claude source
```

`test-codex-sync.sh` is self-healing: if it fails, the sync script has already
regenerated `plugins/llm-wiki/` — stage and commit the result, then re-run.
Read its FAIL message; it tells you exactly what to do.

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
- **Changed the fuzzy router**: add or update test cases in `promptfooconfig.yaml` covering the new routing behavior plus negative controls.
- **Added a new reference file**: `test-plugin-validate.sh` has two `for ref in ...` loops (one Claude-side existence, one Codex-side symlink reachability) — add the new filename to both.
- **Changed directory structure** (new `raw/` or `wiki/` subdirectory): update `test-structure.sh` C1 directory list and C11 placement checks. Update the golden wiki fixture if needed.
- **Edited `claude-plugin/skills/wiki-manager/`**: `test-codex-sync.sh` will fail until you re-run `./scripts/sync-codex-plugin.sh` and commit `plugins/llm-wiki/`. Never edit `plugins/llm-wiki/skills/wiki-manager/` by hand — it is generated, and `references/` is a symlink into the Claude source.
- **Added a Codex-specific text rewrite to the sync script**: also update `scripts/sync-codex-plugin.sh`'s SKILL.md replacement list. References are runtime-neutral and shared verbatim — do not add per-file replacements there.

### Test file locations

- `tests/fixtures/golden-wiki/` — known-correct wiki (3 sources, 2 articles, all indexes)
- `tests/fixtures/defects/` — generated broken wikis (one per lint rule)
- `tests/promptfooconfig.yaml` — Promptfoo behavioral eval config
- `tests/evals/assertions/*.js` — custom JS assertions for file-system checks
- `tests/ci/plugin-tests.yml` — GitHub Actions workflow (copy to `.github/workflows/` to activate)

## Project Structure

```
claude-plugin/                  — source of truth, primary distribution target
  commands/*.md                 — 12 subcommand definitions
  skills/wiki-manager/
    SKILL.md                    — skill manifest + fuzzy router
    references/*.md             — 9 reference docs (hub-resolution, linting, etc.)
  .claude-plugin/
    plugin.json                 — plugin manifest
plugins/llm-wiki/               — generated Codex packaging mirror (do NOT hand-edit)
  skills/wiki-manager/
    SKILL.md                    — patched copy of claude-plugin SKILL.md
    references → ../../../../claude-plugin/skills/wiki-manager/references  (symlink)
    agents/openai.yaml          — Codex UI metadata (generated)
  .codex-plugin/plugin.json     — Codex manifest (version synced from Claude)
.agents/plugins/marketplace.json — repo-local Codex marketplace entry
scripts/sync-codex-plugin.sh    — regenerates plugins/llm-wiki/ from claude-plugin/
AGENTS.md                       — portable single-file protocol for non-Claude agents
tests/                          — test suite (see above)
```

## Release Process

See `.claude/release-checklist.md` for the full ship process. Run all three structural tests before bumping version.
