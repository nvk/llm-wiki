<!--
Thanks for opening a PR. Please fill in the sections below — short answers
are fine, but each one helps reviewers understand intent and scope.
-->

## What does this PR do?

<!-- One or two sentences. The "why," not just the "what." -->

## Linked issue

<!-- e.g. Closes #42, Fixes #43, Refs #45. If there's no issue, briefly say why. -->

## Type of change

<!-- Check any that apply. -->

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that changes existing behavior)
- [ ] Docs / dev experience only (no plugin behavior change)
- [ ] Test or CI improvement

## Pre-flight checklist

- [ ] Structural tests pass locally (`./tests/test-plugin-validate.sh && ./tests/test-structure.sh`)
- [ ] If I edited `claude-plugin/skills/wiki-manager/`, I re-ran both sync scripts and committed the resulting `plugins/` changes
- [ ] If I edited a command or added a new one, the README command table is up to date
- [ ] If the portable protocol changed, `AGENTS.md` matches the canonical Claude source
- [ ] If I added a new lint rule, both `generate-defect-fixtures.sh` and `test-structure.sh` were updated
- [ ] No files in `plugins/llm-wiki/` or `plugins/llm-wiki-opencode/` were hand-edited

## Anything reviewers should know?

<!-- Tradeoffs, follow-up work, areas you'd specifically like a second pair of eyes on. -->
