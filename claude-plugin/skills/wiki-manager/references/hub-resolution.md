# Hub Path Resolution

Every wiki operation must resolve the hub path before doing anything else. Follow this protocol exactly.

## Why this protocol exists

The hub path can come from config (most common — iCloud, Dropbox, NAS), a symlink at `~/wiki/` pointing elsewhere, or `~/wiki/` directly (simple). Earlier versions checked `~/wiki/` first, but that fails in sandboxed environments where `~/wiki/` isn't an allowed path. The v0.3 protocol below checks config first (one file read), falling back to `~/wiki/` only when no config exists.

> **Note (v0.4.1):** The resolution steps are now inlined directly in each
> command file. Commands no longer depend on reading this file at runtime. This
> file remains as canonical developer documentation for the protocol, but is not
> load-bearing for command execution.

## Resolution Steps

**This is a sequential file-read protocol. Do NOT use Explore agents, `find`, `ls -R`, or any filesystem search. Each step is a single Read tool call. Most sessions resolve at step 1 or step 2.**

1. **Read `~/.config/llm-wiki/config.json`** (expand `~` to `$HOME`).

2. **If config has `resolved_path`** → **HUB** = that value verbatim (it's already an absolute path — no expansion needed). Done.

3. **If config has only `hub_path`** (no `resolved_path`) → expand the leading `~` ONLY (see Tilde Expansion below), set **HUB**, then **write `resolved_path` back to config** so this expansion never has to happen again:
   ```json
   {
     "hub_path": "~/Library/Mobile Documents/com~apple~CloudDocs/wiki",
     "resolved_path": "/Users/jane/Library/Mobile Documents/com~apple~CloudDocs/wiki"
   }
   ```

4. **If no config exists** → try `$HOME/wiki/_index.md`. If it exists, **HUB** = `$HOME/wiki`. Done.

5. **If nothing found** → ask the user where they want the wiki before creating anything.

Most sessions hit step 1-2 and resolve from config. The `~/wiki/` fallback (step 4) is only for users with no config file.

> **CRITICAL — Do NOT confuse directory existence with hub existence.**
> A directory may exist (e.g., leftover `.DS_Store`, empty folder, or a symlink to an uninitialized path) without being an initialized hub. Only `_index.md` existing at the hub root counts as an initialized hub.

> **Config is authoritative.** If `~/.config/llm-wiki/config.json` exists with a `hub_path` or `resolved_path`, ALL initialization MUST happen at the config path. Never create a hub at `~/wiki/` when config points elsewhere.

> **Never access `~/wiki/` when config exists.** In sandboxed environments, `~/wiki/` may not be an allowed path. The config path is the only path the agent should touch.

## Optional setup: symlink

For users who want the convenience of `~/wiki/` without granting sandbox access to their real wiki path, a symlink works:

```bash
ln -s "/Users/jane/Library/Mobile Documents/com~apple~CloudDocs/wiki" ~/wiki
```

This is optional — config-based resolution (steps 1-2) works without it. The symlink is a convenience for shell access, not a requirement for the agent.

## Tilde Expansion — Correct Method

Only needed when step 3 runs (first use with an old config that lacks `resolved_path`). Replace ONLY the leading `~` with the user's home directory. **Do NOT expand tildes anywhere else** — characters like `~` in `com~apple~CloudDocs` are literal directory names.

```bash
hub_path="~/Library/Mobile Documents/com~apple~CloudDocs/wiki"  # from config
expanded="${hub_path/#\~/$HOME}"
# Result: /Users/jane/Library/Mobile Documents/com~apple~CloudDocs/wiki
#                                  ↑ these tildes are UNTOUCHED
```

**Never** use `eval` or unquoted expansion — these break on paths with spaces.

## Paths with Spaces

The resolved path may contain spaces (e.g., `Mobile Documents`). When using the path in Bash commands, **always double-quote it**:

```bash
ls "$HUB/topics/"           # correct
ls $HUB/topics/             # WRONG — breaks on spaces
```

The Read, Write, Edit, Glob, and Grep tools handle spaces natively.

## After Resolution

Once HUB is resolved, determine which wiki to target:

1. `--local` flag → `.wiki/` in current directory
2. `--wiki <name>` flag → look up in `HUB/wikis.json`
3. Current directory has `.wiki/` → use it
4. Otherwise → HUB (the hub itself)
