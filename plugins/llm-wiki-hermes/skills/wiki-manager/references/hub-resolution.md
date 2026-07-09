# Hub Path Resolution

Every wiki operation must resolve the hub path before doing anything else. Follow this protocol exactly.

## Why this protocol exists

The hub path can come from config (most common — iCloud, Dropbox, NAS), a symlink at `~/wiki/` pointing elsewhere, or `~/wiki/` directly (simple). Earlier versions checked `~/wiki/` first, but that fails in sandboxed environments where `~/wiki/` isn't an allowed path.

When a wiki folder is shared through iCloud, the same logical folder appears at a different absolute path on each Mac (`/Users/alice/...` vs `/Users/bob/...`). For that reason, `hub_path` is the portable source of truth and `resolved_path` is only a backward-compatible cache.

> **Note (v0.4.1):** The resolution steps are now inlined directly in each
> command file. Commands no longer depend on reading this file at runtime. This
> file remains as canonical developer documentation for the protocol, but is not
> load-bearing for command execution.

## Resolution Steps

**This is a sequential file-read protocol. Do NOT use Explore agents, `find`, `ls -R`, or any filesystem search. Each step is a single Read tool call. Most configured sessions resolve by step 3.**

1. **Read `~/.config/llm-wiki/config.json`** (expand `~` to `$HOME`).

2. **If config has `hub_path`** → expand the leading `~` ONLY (see Tilde Expansion below), set that expanded path as the preferred **HUB** candidate.

3. **If the expanded `hub_path` exists** → **HUB** = expanded `hub_path`. Done. Later verification still checks whether `_index.md` exists before treating it as initialized.

4. **If the expanded `hub_path` is unavailable and config has `resolved_path` with `_index.md`** → **HUB** = `resolved_path` as a backward-compatible fallback. Done.

5. **If config has `hub_path` but neither path is initialized yet** → **HUB** = expanded `hub_path`. Use this for initialization. Done.

6. **If config has only `resolved_path`** → **HUB** = `resolved_path`. Done.

7. **If no config exists** → try `$HOME/wiki/_index.md`. If it exists, **HUB** = `$HOME/wiki`. Done.

8. **If nothing found** → ask the user where they want the wiki before creating anything.

Preferred config:
   ```json
   {
     "hub_path": "~/Library/Mobile Documents/com~apple~CloudDocs/wiki"
   }
   ```

Most sessions hit steps 1-3 and resolve from config. The `~/wiki/` fallback is only for users with no config file.

> **CRITICAL — Do NOT confuse directory existence with hub existence.**
> A directory may exist (e.g., leftover `.DS_Store`, empty folder, or a symlink to an uninitialized path) without being an initialized hub. Only `_index.md` existing at the hub root counts as an initialized hub.

> **Config is authoritative.** If `~/.config/llm-wiki/config.json` exists with a `hub_path` or `resolved_path`, ALL initialization MUST happen at the config path. Prefer `hub_path` for initialization when present. Never create a hub at `~/wiki/` when config points elsewhere.

> **Never access `~/wiki/` when config exists.** In sandboxed environments, `~/wiki/` may not be an allowed path. The config path is the only path the agent should touch.

> **Do not write `resolved_path` into shared configs.** Older configs may contain it, but new config writes should keep only `hub_path` unless the user explicitly wants a machine-local absolute config. This prevents one Mac's `/Users/<name>/...` path from breaking another Mac.

> **Permission-denied is not path-missing.** On macOS/iCloud, `stat` can succeed for `HUB`, `HUB/wikis.json`, and `HUB/topics`, while actual reads or directory listings fail with `Operation not permitted` (`errno=1`). In that case the configured `hub_path` is correct. Stop and tell the user to grant Full Disk Access or iCloud Drive access to the exact app launching the agent, then restart the agent. Do not fall back to `~/wiki`, do not use `resolved_path`, and do not suggest moving the wiki just because reads are denied.

## Optional setup: symlink

For users who want the convenience of `~/wiki/` without granting sandbox access to their real wiki path, a symlink works:

```bash
ln -s "/Users/jane/Library/Mobile Documents/com~apple~CloudDocs/wiki" ~/wiki
```

This is optional — config-based resolution (steps 1-2) works without it. The symlink is a convenience for shell access, not a requirement for the agent.

## Tilde Expansion — Correct Method

Replace ONLY the leading `~` with the current user's home directory. **Do NOT expand tildes anywhere else** — characters like `~` in `com~apple~CloudDocs` are literal directory names.

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

## Registry Path Resolution

`HUB/wikis.json` is commonly stored inside the shared wiki folder, so its paths
must be portable across machines. For topic wikis under the hub, prefer relative
paths:

```json
{
  "default": "<HUB>",
  "wikis": {
    "hub": { "path": "<HUB>", "description": "Hub" },
    "bitcoin": { "path": "topics/bitcoin", "description": "Bitcoin wiki" }
  },
  "local_wikis": []
}
```

When reading an entry path, resolve in this order:

1. `<HUB>` or `HUB` → the resolved hub path
2. `<HUB>/...` or `HUB/...` → relative to the resolved hub path
3. Leading `~/...` → expand `~` on the current machine
4. Absolute path → use as written
5. Any other path → resolve relative to HUB

If a registry entry's path is missing but `HUB/topics/<entry-name>/_index.md`
exists, use `HUB/topics/<entry-name>` and repair the registry on the next
wikis.json sync. If a command explicitly includes archived content and the
active fallback is missing but `HUB/topics/.archive/<entry-name>/_index.md`
exists, use `HUB/topics/.archive/<entry-name>` and ensure the registry entry
has `status: archived`. Normal semantic commands should reject archived entries
unless they explicitly support archived inclusion. If `wikis.json` is unreadable
but `HUB/topics/` is populated, list active topic directories by reading each
topic's `config.md` and `_index.md`; read `topics/.archive/` only for archive
or explicit archived maintenance workflows.
