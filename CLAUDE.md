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
- **Changed user-facing command docs or versions**: update README command rows and all plugin/marketplace manifest versions together, then run `test-docs-consistency.sh`.
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

## Lessons Learned (Hermes plugin work)

Generalizable patterns from building `plugins/llm-wiki-hermes/`:

1. **Verify plugin manifests against the ACTUAL runtime parser, not the plan.**
   Hermes' `PluginManifest._parse_manifest` reads `provides_tools` / `provides_hooks`
   (and a `kind` defaulting to `standalone`). The implementation plan specified a bare
   `hooks:` key that Hermes would have ignored, silently loading the plugin with no
   hooks. When the plan and the framework source disagree, trust the framework source
   (`hermes_cli/plugins.py`) and fix the plan, not the code.

2. **Trace the real hook-contract payloads before writing adapters.** Hermes invokes
   hooks with `cb(**kwargs)`; `pre_llm_call` receives `user_message` +
   `conversation_history` (see `hermes_cli/hooks.py` test payloads), NOT `history`.
   Newer reference plugins still use `history` — that is stale; match what the
   installed Hermes actually passes.

3. **Bundled plugin skills are NOT auto-discovered.** A `skills/<name>/SKILL.md` tree
   inside a plugin is invisible to Hermes unless the plugin calls
   `ctx.register_skill("name", path)` in `register()`. The skill then resolves as
   `<plugin_name>:<name>` (opt-in load only).

4. **Enurate real CLI subcommands via `--help` before routing a tool.** The `wiki`
   tool originally routed a `"session"` subcommand that does not exist in
   `scripts/llm-wiki-session` (real set: `enable|disable|hook|capture|list|show|
   rehydrate|promote|feedback|status`; the CLI `scripts/llm-wiki` has
   `lint|archive|schema`). Phantom commands route to a real script and fail at the
   argparser. Always ground routing tables in `python3 <script> --help`.

5. **Make engine/library path resolution install-method-agnostic.** A hard-coded
   `Path(__file__).resolve().parents[2]` only resolves under the documented
   symlink-from-repo install. A copy or pip install yields `None` → every hook
   silently no-ops. Resolve via ordered candidates: env override
   (`LLM_WIKI_ENGINE`) → repo-relative → vendored → top-level import; emit a visible
   stderr WARNING on total failure rather than failing silently.

6. **`on_session_start` return values are discarded by Hermes** — only `pre_llm_call`
   returns are injected into the prompt. A `rehydrate.session_start` config flag is
   inert for Hermes; rehydration happens on the first `UserPromptSubmit` via
   `pre_llm_call`. Document this rather than surprising future readers.

7. **Empirically verify reviewer "Critical" claims before fixing.** A holistic review
   flagged a "Critical" engine-path bug; running `adapter._get_engine()` showed the
   engine loads correctly (the reviewer miscounted `parents[]`). Run the actual code
   path to confirm a reported defect before writing a fix — reviewer arithmetic and
   reasoning errors are real and waste cycles.

8. **Subagent-driven development runs ONE subagent per task.** Parallel implementer
    subagents conflict on shared files. Dispatch sequentially; review between tasks.

 9. **`_score_articles` must handle `[[Title]](path)` wikilinks, not just `[Title](path)`.**
    The original regex `r"\[([^\]]+)\]\(([^)]+)\)"` only matches single-bracket markdown
    links. Wiki `_index.md` files use Obsidian-style `[[Wikilink]](path)` format. The
    fix is `_parse_article_entry()` with regex `r"\[\[?([^\]]+)\]\]?\(([^)]+)\)"` that
    handles both. Without this, `retrieve_wiki_context` silently returns empty because
    zero articles are parsed from the index.

10. **`_score_articles` needs a topics/ directory fallback.** If the hub `_index.md`
    has no `topics/` slug references (e.g., a fresh hub or non-standard layout),
    `slugs` is empty and scoring skips all topics. Fall back to enumerating
    `hub/topics/` directory entries.

11. **Dedup logic in `_score_articles` must include unique entries, not duplicates.**
    The correct pattern is `if rel not in seen: add; append`. An inverted condition
    (`if rel in seen: append`) silently produces empty output because every first
    encounter of a unique path is skipped.

12. **Verify hook evidence through three channels, not one.** A single signal (e.g.,
    "plugin is enabled") is insufficient. Check: (a) `journalctl` for registration
    logs, (b) `~/.wiki/.sessions/queue/*.jsonl` for captured events, (c) Hermes
    agent logs for injected context blocks. All three must confirm the hook fires
    and produces output.

13. **`on_session_finalize` only fires on session teardown.** The `PreCompact` event
    appears in the session queue only after `/new`, GC eviction, or CLI quit — never
    during an active conversation. Test by issuing `/new` in Hermes and checking the
    queue file afterward.

14. **Hermes caches plugin bytecode in `__pycache__`.** Code changes to a plugin are
    invisible to the running gateway until you clear `__pycache__` AND restart with
    `hermes gateway restart`. `hermes restart` is incorrect; only `hermes gateway
    restart` reloads the plugin process.

