# Hub Path Resolution

Every wiki operation must resolve the hub path before doing anything else. Follow this protocol exactly.

## Why this protocol exists

The hub path can be `~/wiki/` (simple), a symlink at `~/wiki/` pointing to an iCloud path (common), or a custom path from config (rare). Earlier versions of this protocol required LLMs to read a config file, expand tildes carefully (only the leading one — `com~apple~CloudDocs` has literal tildes), and quote paths with spaces. That was three fragile steps that LLMs got wrong regularly. The v0.2 protocol below eliminates most of this by: (a) preferring the `~/wiki/` symlink path which just works, and (b) caching the resolved absolute path in config so tilde expansion happens at most once.

## Resolution Steps

1. **Try `~/wiki/_index.md`** (expand `~` to `$HOME`). This works whether `~/wiki/` is a real directory or a symlink to an iCloud/custom path.

2. **If it exists** → **HUB** = `$HOME/wiki`. Done. Skip everything below.

3. **If it does not exist** → read `~/.config/llm-wiki/config.json`.

4. **If config has `resolved_path`** → **HUB** = that value verbatim (it's already an absolute path — no expansion needed). Done.

5. **If config has only `hub_path`** (no `resolved_path`) → expand the leading `~` ONLY (see Tilde Expansion below), set **HUB**, then **write `resolved_path` back to config** so this expansion never has to happen again:
   ```json
   {
     "hub_path": "~/Library/Mobile Documents/com~apple~CloudDocs/wiki",
     "resolved_path": "/Users/jane/Library/Mobile Documents/com~apple~CloudDocs/wiki"
   }
   ```

6. **If no config exists** → **HUB** = `$HOME/wiki` (for initialization).

Most sessions hit step 1 or step 4 and never touch tilde expansion. The fragile path (step 5) runs at most once per install.

> **CRITICAL — Do NOT confuse directory existence with hub existence.**
> The `~/wiki/` DIRECTORY may exist (e.g., leftover `.DS_Store`, empty folder, or a symlink to an uninitialized path) without being an initialized hub. Only `~/wiki/_index.md` existing counts as an initialized hub. If the directory exists but `_index.md` does not, fall through to config — do NOT initialize there.

> **NEVER initialize a new hub at `~/wiki/` if config exists with a `hub_path` or `resolved_path`.** The config is authoritative for where hubs are created. If step 3 reads a config, all initialization MUST happen at the config path, never at `~/wiki/`.

## Recommended setup: symlink

For users whose wiki lives outside `~/wiki/` (iCloud, Dropbox, NAS), the most robust setup is a symlink:

```bash
ln -s "/Users/jane/Library/Mobile Documents/com~apple~CloudDocs/wiki" ~/wiki
```

After this, step 1 always succeeds immediately. The complex iCloud path never appears in LLM context — agents just see `~/wiki/`. The config still exists as a record of the real path but is never consulted during resolution.

macOS handles this correctly: iCloud syncs the target directory, not the symlink itself. If the symlink is deleted, the wiki data at the iCloud path is unaffected.

## Tilde Expansion — Correct Method

Only needed when step 5 runs (first use with an old config that lacks `resolved_path`). Replace ONLY the leading `~` with the user's home directory. **Do NOT expand tildes anywhere else** — characters like `~` in `com~apple~CloudDocs` are literal directory names.

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
