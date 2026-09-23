---
description: "Manage personal specialist SKILL.md methods, topic allowlists, candidate discovery, and bounded specialist reviews."
argument-hint: "init|create <name> --description <text>|list [--wiki <topic>]|show <name>|validate [<name>]|refresh|enable|disable <name> --wiki <topic>|suggest [--wiki <topic|all>]|apply <name> <question> --wiki <topic>"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(python3:*), Bash(scripts/llm-wiki:*), Bash(${CLAUDE_PLUGIN_ROOT}/bin/llm-wiki:*), WebFetch, WebSearch, Agent
---

## Your task

Manage or apply personal specialist methods. Read
`skills/wiki-manager/references/specialists.md` before acting. A specialist is
a bounded evidence/review protocol, not a human credential or new authority.

Resolve HUB from `${LLM_WIKI_CONFIG_DIR:-$HOME/.config/llm-wiki}/config.json`, preferring `hub_path` and
expanding only a leading `~`. Use the bundled deterministic helper:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/llm-wiki" specialist <subcommand>
```

Use `scripts/llm-wiki` in a source checkout. Never assume a global install.

## Deterministic subcommands

Route `init`, `create`, `refresh`, `list`, `show`, `validate`, `enable`, and
`disable` directly to the helper with the user's arguments. For `create`, help
the user choose a descriptive method name rather than a credential costume,
then review and replace the scaffold's generic instructions and TODOs. Run
`validate`, then `refresh`; do not enable an unfinished scaffold.

`enable` and `disable` require an active hub topic. V1 does not persist
allowlists inside project-local `.wiki/` roots. Never edit `registry.json`
manually when the helper can make the change.

## `suggest`

Discover useful specialist candidates without creating them:

1. Read `HUB/_index.md`, active `wikis.json` entries, and `.skills/_index.md`
   when present.
2. Read each selected active topic's root `_index.md`. Do not bulk-read raw
   sources or recursively scan the hub.
3. Rank recurring decision patterns and evidence-review needs across topics.
   Use targeted category indexes and a small content sample only to verify the
   strongest patterns.
4. Return at most ten candidates. For each include: proposed method name,
   topics/use cases that justify it, mandate, exclusions, risk tier, source
   hierarchy, and two starter eval cases.
5. Separate broad reusable methods from narrow topic-only methods. Prefer the
   former only when recurrence is demonstrated.
6. Do not create or enable any candidate without a later explicit request.

If the user asks to save the result, write a dated report under the selected
topic's `output/`, update `output/_index.md` and the topic root `_index.md`, and
append `log.md`.

## `apply`

Apply one enabled specialist to a bounded question or artifact:

1. Resolve the active topic and confirm the specialist appears in
   `specialist list --wiki <topic> --json`.
2. Run `specialist validate <name>`. Stop on any finding.
3. Read only the selected `SKILL.md` and the smallest referenced Markdown
   needed.
4. Assemble a bounded evidence packet from topic indexes, selected articles or
   raw sources, intended use, as-of date, jurisdiction, stakes, and missing
   inputs.
5. Apply the specialist's method without expanding tools or write authority.
6. Verify citations, dates, uncertainty, and escalation rules.
7. Report the specialist name, version, and SHA-256 with the result.

Answer in chat by default. Save to `output/` only when requested, using normal
output provenance, index updates, and activity logging. High-stakes results
must identify the qualified human review required.
