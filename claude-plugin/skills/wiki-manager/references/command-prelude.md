# Command Prelude

Every `/wiki:*` command starts with the same handful of steps: resolve the hub path, figure out which wiki to use, and decide what to do if no wiki exists. This file is the canonical version of those steps so each command can reference it instead of restating it.

## Why this file exists

The prelude appeared verbatim in 11 command files. Every time the hub resolution protocol changed (v0.0.12, v0.0.13, v0.0.14, and again when the iCloud path handling got fixed), it had to be edited in every command. That's a drift trap and an LLM token tax — every command spent ~15 lines repeating the same boilerplate before getting to its actual work. Factoring it out means:

- **One place to update** when the resolution protocol evolves.
- **Commands read leaner** — the interesting work is front-and-center, not buried below 15 lines of setup.
- **No rationale loss** — the *why* of each step (why check `~/wiki/` first, why ask instead of guess, why stop if missing) lives here, cited by the commands that apply it.

## Standard prelude

Every command that needs a wiki follows these steps in order:

1. **Resolve HUB.** Follow the protocol in [`hub-resolution.md`](hub-resolution.md) — check `~/wiki/` first, then `~/.config/llm-wiki/config.json` for a custom `hub_path`, expand leading `~` only, quote paths with spaces. `~/wiki/` wins when it exists because it's the simplest and most reliable path; the config is the fallback for iCloud or custom storage. The resolved absolute path is called **HUB**.

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

## Focus-aware behavior (ingest, research, query, output)

Before finalizing wiki resolution, these commands additionally check `<wiki-root>/.wiki-session.json` for a `focused_project` field. If present and no explicit `--project` flag is passed, the focused project becomes an implicit `--project <slug>` for the operation. Explicit flags always override focus. The rationale is that when a user is deep in a project, they rarely want to type `--project foo` on every command; the focus session makes it sticky. See [`projects.md`](projects.md) for project model details.

## What commands still handle inline

Anything command-specific stays in the command file:

- `### Parse $ARGUMENTS` sections (flag docs)
- Command-specific deviations from the 4-step wiki resolution (e.g., `assess` asks which wiki to compare against when none is specified, `thesis` has its own `--new-topic`-equivalent branching in Phase 1)
- Per-command focus-aware behavior details (which flags are focus-sticky)
- The command's actual work (the reason the command exists)

## When to edit this file

Edit `command-prelude.md` when:

- The hub resolution protocol changes (e.g., new config location, new fallback path)
- The wiki resolution order changes (e.g., a new flag like `--wiki` or `--local` is added)
- A new wiki-requirement variant is introduced (e.g., a command that wants to lazy-create a wiki on write)
- The focus-session mechanism changes

Do **not** edit this file for command-specific changes. Those stay in the command.
