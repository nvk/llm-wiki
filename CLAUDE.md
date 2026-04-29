# llm-wiki Development Guide

## Testing

Run tests before declaring any change to plugin code done.

### Structural tests (always run — no LLM, instant)

```bash
./tests/test-plugin-validate.sh   # plugin manifest + command frontmatter
./tests/test-structure.sh          # wiki fixture validation (84 assertions)
./tests/test-codex-sync.sh         # Codex plugin mirror matches Claude source
./tests/test-opencode-sync.sh     # OpenCode plugin mirror matches Claude source
```

### Codex runtime smoke test (run when touching Codex packaging/docs)

```bash
./tests/test-codex-runtime.sh      # bootstrap + headless prompt-input check for @wiki
```

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
- **Changed the fuzzy router**: add or update test cases in `promptfooconfig.yaml` covering the new routing behavior plus negative controls.
- **Added a new reference file**: `test-plugin-validate.sh` has three `for ref in ...` loops (Claude-side existence, Codex-side copied-reference validation, OpenCode-side symlink reachability) — add the new filename to all three.
- **Changed directory structure** (new `raw/` or `wiki/` subdirectory): update `test-structure.sh` C1 directory list and C11 placement checks. Update the golden wiki fixture if needed.
- **Edited `claude-plugin/skills/wiki-manager/`**: both `test-codex-sync.sh` and `test-opencode-sync.sh` will fail until you re-run both sync scripts and commit `plugins/`. Never edit `plugins/llm-wiki/` or `plugins/llm-wiki-opencode/` by hand — they are generated. Codex gets copied references for marketplace caching; OpenCode keeps a symlink into the Claude source.
- **Added a runtime-specific text rewrite to a sync script**: update the corresponding sync script's SKILL.md replacement list. References are runtime-neutral and shared verbatim — do not add per-file replacements there.
- **Changed Codex install docs or bootstrap flow**: run `./tests/test-codex-runtime.sh` to verify the bootstrap flow either resolves `@wiki` from a clean scratch Codex home or cleanly reports that `/plugins` still needs to be opened once for first-time materialization.

### Test file locations

- `tests/fixtures/golden-wiki/` — known-correct wiki (3 sources, 2 articles, all indexes)
- `tests/fixtures/defects/` — generated broken wikis (one per lint rule)
- `tests/promptfooconfig.yaml` — Promptfoo behavioral eval config
- `tests/evals/assertions/*.js` — custom JS assertions for file-system checks
- `tests/ci/plugin-tests.yml` — GitHub Actions workflow (copy to `.github/workflows/` to activate)

## Project Structure

```
claude-plugin/                  — source of truth, primary distribution target
  commands/*.md                 — 16 command files (15 user commands + wiki router)
  skills/wiki-manager/
    SKILL.md                    — skill manifest + fuzzy router
    references/*.md             — 10 reference docs (hub-resolution, linting, audit, etc.)
  .claude-plugin/
    plugin.json                 — plugin manifest
plugins/llm-wiki/               — generated Codex packaging mirror (do NOT hand-edit)
  skills/wiki/
    SKILL.md                    — patched copy of claude-plugin SKILL.md
    references/*.md             — copied from claude-plugin/skills/wiki-manager/references
    agents/openai.yaml          — Codex UI metadata (generated)
  .codex-plugin/plugin.json     — Codex manifest (version synced from Claude)
plugins/llm-wiki-opencode/      — generated OpenCode packaging mirror (do NOT hand-edit)
  skills/wiki-manager/
    SKILL.md                    — patched copy of claude-plugin SKILL.md
    references → ../../../../claude-plugin/skills/wiki-manager/references  (symlink)
  README.md                     — OpenCode install instructions
.agents/plugins/marketplace.json — repo-local Codex marketplace entry
scripts/sync-codex-plugin.sh    — regenerates plugins/llm-wiki/ from claude-plugin/
scripts/sync-opencode-plugin.sh — regenerates plugins/llm-wiki-opencode/ from claude-plugin/
AGENTS.md                       — portable single-file protocol for non-Claude agents
tests/                          — test suite (see above)
```

## Release Process

See `.claude/release-checklist.md` for the full ship process. Run all structural tests before bumping version.
