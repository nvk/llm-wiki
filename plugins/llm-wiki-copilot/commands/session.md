---
description: "Capture, list, rehydrate, and promote llm-wiki session context. Supports automated hook capture into HUB/.sessions plus explicit promotion into topic raw notes."
argument-hint: "enable|disable|status|capture|list|show|rehydrate|promote [options]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(mkdir:*), Bash(python3:*), Bash(scripts/llm-wiki-session:*)
---

## Your task

Manage llm-wiki session context. Session context is operational memory for agent
sessions, not canonical topic knowledge. Use `HUB/.sessions/` as the canonical
store and promote only explicit distilled learnings into topic `raw/notes/`.

First read `references/sessions.md`, then resolve HUB by the standard hub
resolution protocol from `references/hub-resolution.md`. If a deterministic
helper is available, prefer it:

```bash
scripts/llm-wiki-session --hub "$HUB" <subcommand>
```

If the helper is not available, perform the equivalent file operations described
in `references/sessions.md`.

### Parse $ARGUMENTS

- `enable [--mode capture-only|balanced|aggressive] [--tool-events N]`: re-enable
or reconfigure automated capture by writing `HUB/.sessions/config.json`. Default
mode is `balanced`; default threshold is 50 observed tool events.
- `disable`: opt out by setting `enabled: false` in `HUB/.sessions/config.json`.
- `status`: report whether capture is enabled, where `.sessions/` lives, and how
many sessions are indexed.
- `capture`: force a manual digest checkpoint for the current or specified
session. Accept optional `--harness`, `--session-id`, `--cwd`, `--topic`, and
`--summary` hints.
- `list`: list sessions by recency, optionally filtered by `--harness`, `--cwd`,
or `--topic`.
- `show <session-id>`: show the latest digest for a session.
- `rehydrate [--session-id <id>|--cwd <path>|--topic <slug>]`: print a compact
context block that the harness should read before continuing.
- `promote <session-id> --topic <slug>`: create a topic `raw/notes/` promotion
note from the distilled digest. Do not copy raw transcripts.

### Policy

1. Automated capture is default-on when trusted hooks are installed. Users can
opt out with `session disable`, which writes `enabled: false` and causes hooks
using `--if-enabled` to no-op.
2. Hooks should be fast and deterministic: append redacted JSONL event metadata,
update state, and write markdown digests at checkpoints. Do not call an LLM from
every tool hook.
3. Raw transcript archiving is off by default. Store transcript pointers/hashes,
not transcript bodies.
4. Auto-promotion is forbidden. Sessions can be untagged or topic-tagged, but
canonical wiki knowledge requires explicit promotion.
5. Rehydration may inject a short context block in balanced/aggressive modes;
strict forced continuation remains opt-in and must have loop guards.

### Examples

```bash
# Opt out of automated capture.
scripts/llm-wiki-session --hub "$HUB" disable

# Re-enable or tune automated capture and soft rehydration.
scripts/llm-wiki-session --hub "$HUB" enable --mode balanced --tool-events 50

# Capture now with a short human summary.
scripts/llm-wiki-session --hub "$HUB" capture --harness manual --summary "Design decision: sessions live under HUB/.sessions and promote into topic raw notes only by command."

# Continue a previous task.
scripts/llm-wiki-session --hub "$HUB" rehydrate --cwd "$PWD"

# Promote a distilled digest into a topic wiki.
scripts/llm-wiki-session --hub "$HUB" promote codex:abc123 --topic meta-llm-wiki
```

Report absolute paths for every created digest, config file, or promotion note.
Append topic `log.md` when promoting into a topic wiki.
