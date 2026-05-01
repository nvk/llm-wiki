# Contributing to llm-wiki

Thanks for your interest in contributing. This guide covers the dev loop, the
test layers, and the few non-obvious rules that will save you a round-trip
on review.

If you're an LLM agent reading this, the deeper "why" lives in
[`CLAUDE.md`](../CLAUDE.md) at the repo root. This file is the human-facing
quickstart.

## Quick start

```bash
git clone https://github.com/nvk/llm-wiki.git
cd llm-wiki
./tests/test-plugin-validate.sh   # ~1s, no API key required
./tests/test-structure.sh         # ~1s, no API key required
```

If both pass, your environment is good.

## Repository layout

The single source of truth is `claude-plugin/`. Everything in `plugins/` is
**generated** — never hand-edit those files.

```
claude-plugin/                         # Source of truth for the Claude plugin
  commands/*.md                        # Slash commands
  skills/wiki-manager/SKILL.md         # Skill definition + fuzzy router
  skills/wiki-manager/references/      # Behavioral reference docs

plugins/llm-wiki/                      # GENERATED — Codex plugin mirror
plugins/llm-wiki-opencode/             # GENERATED — OpenCode mirror

scripts/sync-codex-plugin.sh           # Regenerates plugins/llm-wiki/
scripts/sync-opencode-plugin.sh        # Regenerates plugins/llm-wiki-opencode/

AGENTS.md                              # Portable single-file protocol

tests/                                 # See "Test layers" below
```

If you change anything under `claude-plugin/skills/wiki-manager/`, both sync
scripts must run before your PR will pass CI.

## Test layers

There are three tiers of tests. Run them in order — the cheap ones first.

### 1. Structural (instant, no API key)

These run on every PR. Run them locally before pushing.

```bash
./tests/test-plugin-validate.sh   # plugin manifest + command frontmatter
./tests/test-structure.sh         # wiki fixture validation (~90 assertions)
./tests/test-codex-sync.sh        # Codex mirror matches Claude source
./tests/test-opencode-sync.sh     # OpenCode mirror matches Claude source
```

The two sync tests are **self-healing**: if they fail, the sync script has
already regenerated the target directory. Stage the changes, commit, re-run.
Read the FAIL message — it tells you exactly what to do.

If you changed the golden wiki fixture, regenerate defect fixtures first:

```bash
./tests/generate-defect-fixtures.sh
```

### 2. Codex runtime smoke test (~30s, optional)

Run this when you touch Codex packaging or the bootstrap flow.

```bash
./tests/test-codex-runtime.sh
```

### 3. Behavioral evals (slow, costs money)

Run these when you change command logic or the fuzzy router.

```bash
npx promptfoo@latest eval -c tests/promptfooconfig.yaml
```

Requires `ANTHROPIC_API_KEY`. ~$2-5 per run. CI runs this automatically on
every PR using the repo's API key.

## The non-obvious rules

A few rules that aren't enforced by the tests but will get a PR rejected:

1. **Never hand-edit `plugins/llm-wiki/` or `plugins/llm-wiki-opencode/`.**
   They are generated from `claude-plugin/`. If you need a runtime-specific
   wording change, edit the corresponding sync script's replacement list.

2. **Re-run both sync scripts after any change to
   `claude-plugin/skills/wiki-manager/`.** The two sync tests will fail
   otherwise.

3. **Update `AGENTS.md` when the portable protocol changes.** AGENTS.md is
   the single-file fallback for non-Claude agents — it has to stay in sync
   with the canonical SKILL.md and references.

4. **If you add a new lint rule:** add a defect fixture in
   `generate-defect-fixtures.sh` and a negative test case in
   `test-structure.sh`. CLAUDE.md has the full "When to update tests" list.

5. **If you add a new reference file under
   `claude-plugin/skills/wiki-manager/references/`:** `test-plugin-validate.sh`
   has three `for ref in ...` loops (Claude existence, Codex copied-reference
   validation, OpenCode symlink reachability) — add the new filename to all
   three.

## Pull request checklist

Before opening a PR, please confirm:

- [ ] Structural tests pass locally (`./tests/test-plugin-validate.sh && ./tests/test-structure.sh`)
- [ ] If you edited `claude-plugin/skills/wiki-manager/`, both sync scripts have been re-run and the resulting `plugins/` changes are committed
- [ ] If you added or removed a command, both `SKILL.md` and `README.md`'s command table are updated
- [ ] If the portable protocol changed, `AGENTS.md` is updated to match
- [ ] If you added a new lint rule, the defect fixture and structural test were both updated

## Filing issues

Use the issue templates — they ask for the information reviewers actually need:

- **Bug report** — for something that's broken or behaves unexpectedly
- **Feature request** — for new commands, new flags, or behavior changes

## Questions?

Open a `question`-labeled issue or comment on an existing one. Small process
suggestions (better dev ergonomics, missing tests, doc gaps) are very
welcome — most of them become good-first-issue tickets.
