# Command Prelude

Every `/wiki:*` command starts with the same handful of steps: resolve the hub path, figure out which wiki to use, and decide what to do if no wiki exists. This file is the canonical version of those steps so each command can reference it instead of restating it.

## Why this file exists

The prelude appeared verbatim in 11 command files. Every time the hub resolution protocol changed (v0.0.12, v0.0.13, v0.0.14, and again when the iCloud path handling got fixed), it had to be edited in every command. That's a drift trap and an LLM token tax — every command spent ~15 lines repeating the same boilerplate before getting to its actual work. Factoring it out means:

- **One place to update** when the resolution protocol evolves.
- **Commands read leaner** — the interesting work is front-and-center, not buried below 15 lines of setup.
- **No rationale loss** — the *why* of each step (why check `~/wiki/` first, why ask instead of guess, why stop if missing) lives here, cited by the commands that apply it.

## Standard prelude

Every command that needs a wiki follows these steps in order:

1. **Resolve HUB.** Follow the protocol in [`hub-resolution.md`](hub-resolution.md). Short version: try `~/wiki/_index.md` first (works for both real dirs and symlinks to iCloud). If that works, HUB = `$HOME/wiki`, done. If not, read `~/.config/llm-wiki/config.json` and use `resolved_path` (pre-computed absolute path — no tilde expansion needed). The full protocol has 6 steps but most sessions hit step 1 or 4 and resolve instantly.

2. **Resolve wiki location.** The target wiki is determined by this order (first match wins):
   1. `--local` flag → `.wiki/` in the current directory
   2. `--wiki <name>` flag → look up in `HUB/wikis.json`
   3. Current directory contains a `.wiki/` → use it
   4. Otherwise → HUB (use the hub's active topic wiki, or fail per the command's wiki-requirement variant below)

3. **Verify existence.** Try to read `<wiki-root>/_index.md`. If missing, follow the command's wiki-requirement variant below.

4. **Parse `$ARGUMENTS`.** Each command defines its own flags; parse them after the wiki is resolved so flag validation can use wiki state (for example, `--project <slug>` checking whether the project exists).

## Wiki-requirement variants

Commands differ in what they do when no wiki is found. Each command picks one of these variants and states it in its task section.

### Variant A: wiki-required (most read/write commands)

If no wiki exists, stop with:

> No wiki found. Run `/wiki init <topic>` first.

Commands using this variant: `compile`, `lint`, `query`, `output`, `plan`, `retract`, `assess`. The rationale is correctness — running these on an empty state would silently produce nothing or corrupt derived caches.

### Variant B: wiki-creating (ingest, research, thesis)

These commands accept `--new-topic <name>` (or equivalent) and will create a topic wiki on the fly when the flag is set. When `--new-topic` is **not** set and no wiki is found, they stop with:

> No wiki found. Use `--new-topic <name>` to create one, or run `/wiki init` first.

The rationale is ergonomics — research and ingestion are often the first operation on a new subject, so forcing a separate `init` step doubles the friction. `--new-topic` is explicit opt-in to creation so the default path still errs cautiously.

### Variant C: wiki-neutral (project, output without articles, status)

These commands either don't require wiki content (project manifest operations, wiki status) or have their own "no articles yet" message. They resolve HUB and wiki location, then handle missing state inline with command-specific messaging.

## Project scoping

Commands that accept `--project <slug>` (`ingest`, `research`, `output`, `compile`) apply it as an explicit flag only. There is no ambient project focus — earlier iterations of this plugin had a `.wiki-session.json` focus mechanism that made project scope sticky, but it was removed in the v0.2 projects simplification. The rationale is documented in [`projects.md`](projects.md) § "Focus": one explicit flag per command is simpler than a whole session-state mechanism, and if a user finds themselves typing `--project foo` on every invocation that's a signal to `cd` into the project folder directly.

## What commands still handle inline

Anything command-specific stays in the command file:

- `### Parse $ARGUMENTS` sections (flag docs)
- Command-specific deviations from the 4-step wiki resolution (e.g., `assess` asks which wiki to compare against when none is specified, `thesis` has its own `--new-topic`-equivalent branching in Phase 1)
- Per-command `--project` behavior details (which commands support it and how they scope outputs)
- The command's actual work (the reason the command exists)

## When to edit this file

Edit `command-prelude.md` when:

- The hub resolution protocol changes (e.g., new config location, new fallback path)
- The wiki resolution order changes (e.g., a new flag like `--wiki` or `--local` is added)
- A new wiki-requirement variant is introduced (e.g., a command that wants to lazy-create a wiki on write)
- The explicit project-scoping rules change

Do **not** edit this file for command-specific changes. Those stay in the command.
