# Hub Path Resolution

Every wiki operation must resolve the hub path before doing anything else. Follow this protocol exactly.

## Resolution Steps

1. **Read config**: Use the Read tool on `~/.config/llm-wiki/config.json`
2. **If config exists** and contains a `hub_path` field, use that value
3. **If config does not exist** or has no `hub_path`, default to `~/wiki/`
4. **Expand the leading tilde**: If the path starts with `~/`, replace ONLY the leading `~` with the user's home directory. **Do NOT expand tildes anywhere else in the path** — characters like `~` in directory names (e.g., `com~apple~CloudDocs`) are literal and must be left unchanged.
5. Store the result as **HUB** for the rest of the operation.

### Tilde Expansion — Correct Method

If you need to expand the path in Bash, use this pattern:

```bash
hub_path="~/Library/Mobile Documents/com~apple~CloudDocs/wiki"  # from config
expanded="${hub_path/#\~/$HOME}"
# Result: /Users/jane/Library/Mobile Documents/com~apple~CloudDocs/wiki
#                                  ↑ these tildes are UNTOUCHED
```

**Never** use `eval` or unquoted expansion — these break on paths with spaces.

### Paths with Spaces

The resolved path may contain spaces (e.g., `Mobile Documents` in iCloud paths). When using the path in Bash commands, **always double-quote it**:

```bash
ls "$HUB/topics/"           # correct
mkdir -p "$HUB/topics/new"  # correct
ls $HUB/topics/             # WRONG — breaks on spaces
```

The Read, Write, Edit, Glob, and Grep tools handle spaces natively — no special quoting needed for those.

### Worked Example (iCloud)

Config file (`~/.config/llm-wiki/config.json`):
```json
{ "hub_path": "~/Library/Mobile Documents/com~apple~CloudDocs/wiki" }
```

Resolution on a machine with home directory `/Users/jane`:

| Step | Value |
|------|-------|
| Raw from config | `~/Library/Mobile Documents/com~apple~CloudDocs/wiki` |
| After leading `~` expansion | `/Users/jane/Library/Mobile Documents/com~apple~CloudDocs/wiki` |
| `com~apple~CloudDocs` | Unchanged — this is a literal directory name, not a tilde to expand |

**HUB** = `/Users/jane/Library/Mobile Documents/com~apple~CloudDocs/wiki`

### Default (no config)

If `~/.config/llm-wiki/config.json` does not exist, **HUB** = `~/wiki/` (expanded to `$HOME/wiki/`).

## After Resolution

Once HUB is resolved, determine which wiki to target:

1. `--local` flag → `.wiki/` in current directory
2. `--wiki <name>` flag → look up in `HUB/wikis.json`
3. Current directory has `.wiki/` → use it
4. Otherwise → HUB (the hub itself)
