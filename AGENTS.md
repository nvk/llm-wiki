# AGENTS.md — nvk/llm-wiki Development Guide

## Project Structure

This repo is the `llm-wiki` project with a Hermes plugin adapter at `plugins/llm-wiki-hermes/`.
The plugin replaces Hermes' built-in `llm-wiki` skill with the full `wiki-manager` skill.

### Key Files

| File | Purpose |
|------|---------|
| `plugins/llm-wiki-hermes/hooks/adapter.py` | Hook adapters for Hermes — the core of the plugin |
| `plugins/llm-wiki-hermes/__init__.py` | Plugin entrypoint — registers hooks, tools, and skill |
| `plugins/llm-wiki-hermes/hooks/llm_wiki_session.py` | Shared session engine (imported by adapter) |
| `plugins/llm-wiki/hooks/llm_wiki_session.py` | Upstream session engine (same file, different path) |

### Hook Flow

The Hermes plugin registers 5 hooks via `PluginContext.register_hook()`:

| Hook | Engine Event | Purpose |
|------|-------------|---------|
| `on_session_start` | `SessionStart` | Capture session start, prefetch context |
| `pre_llm_call` | `UserPromptSubmit` | Inject wiki memory + session rehydration + steering nudge |
| `post_tool_call` | `PostToolUse` | Record tool usage for session digests |
| `on_session_finalize` | `PreCompact` | Capture before session compaction (fires on `/new`, GC, CLI quit) |
| `on_session_end` | `SessionEnd` | Capture session end, write digest checkpoint |

### `pre_llm_call` Injection

This hook injects three components into the user message before the LLM call:

1. **Session rehydration** — `_capture("UserPromptSubmit", ...)` returns distilled session digests
2. **Wiki memory** — `retrieve_wiki_context()` scores wiki articles against the user query and returns top matches
3. **Steering nudge** — `_steer_to_our_skill()` adds a hint to use the `wiki-manager` skill for wiki-related queries

All three are joined with `"\n\n"` and injected as `plugin_user_context` by Hermes at `conversation_loop.py:797-798`.

### Critical: `_score_articles` Wikilink Parsing

The `_parse_article_entry()` function must handle **both** link formats:
- `[[Title]](path)` — Obsidian wikilinks (used by the user's wiki indexes)
- `[Title](path)` — Standard markdown links

The regex `\[\[?([^\]]+)\]\]?\(([^)]+)\)` handles both. If you only match `[Title](path)` (single bracket), wikilinks in `_index.md` files will be silently skipped and `retrieve_wiki_context` returns empty.

### Debugging Hooks in Production

#### Finding Evidence Hooks Are Called

**1. Plugin registration** (appears on gateway start):
```bash
journalctl --user -u hermes-gateway --no-pager | grep "llm-wiki-hermes registered"
```
Shows: `Plugin llm-wiki-hermes registered hook: pre_llm_call` etc.

**2. Session events** (appears in wiki session queue):
```bash
python3 -c "
import json
with open('/home/nathan/wiki/.sessions/queue/2026-07-09.jsonl') as f:
    for line in f:
        d = json.loads(line.strip())
        print(f\"{d['hook_event_name']:20s}  ts={d['ts']}\")
"
```
Shows events: `SessionStart`, `UserPromptSubmit`, `PostToolUse`, `PreCompact`, `SessionEnd`

**3. LLM request logs** (appears in Hermes agent logs):
```bash
strings ~/.hermes/logs/agent.log | grep "llm-wiki memory\|llm-wiki session\|llm-wiki-hermes"
```
Shows injected context blocks in the user message sent to the LLM.

**4. Hermes debug mode** (set `HERMES_DEBUG=1` on gateway process):
Shows plugin registration details including hook callbacks.

#### Common Pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| Hook registered but no output | `pre_llm_call` returns `None` because all sub-components returned empty | Check each component: rehydrate, memory, steer |
| Memory returns empty | `_score_articles` regex doesn't match wiki link format | Use `_parse_article_entry()` which handles `[[Title]](path)` |
| Memory returns empty | `cwd` passed as `query` argument (wrong order) | Call `retrieve_wiki_context(cwd=cwd, query=user_message)` |
| `PreCompact` never appears | Session still active — `on_session_finalize` only fires on `/new`, GC, or CLI quit | Trigger with `/new` in Hermes |
| Code changes not picked up | Hermes cached `__pycache__` bytecode | Clear `__pycache__` + restart gateway |
| Hook not registered at all | Plugin not in `~/.hermes/plugins/` or not enabled | Check `hermes plugins list` |

#### Testing `retrieve_wiki_context` Directly

```bash
source ~/.hermes/hermes-agent/venv/bin/activate
python3 -c "
import sys, os
sys.path.insert(0, os.path.expanduser('~/.local/share/llm-wiki/plugins/llm-wiki-hermes'))
from hooks.adapter import retrieve_wiki_context
result = retrieve_wiki_context(cwd='/home/nathan/.hermes', query='OPNsense')
print(result)
"
```

## Constraints

- One subagent at a time (never parallel)
- All install actions must be idempotent and fail-open
- Python 3.9+, stdlib only
- Do NOT hand-edit `plugins/llm-wiki/` or `plugins/llm-wiki-opencode/` (generated mirrors)

## Production Install

- Fork: `dfein38347g/llm-wiki` on `feat/hermes-plugin` branch
- Production copy: `~/.local/share/llm-wiki/` (symlinked to `~/.hermes/plugins/llm-wiki-hermes/`)
- Dev build: `/tmp/opencode/llm-wiki-upstream/` (mirrors fork)
- Hermes gateway: `hermes gateway restart` to reload plugins

## Known Issues

- `on_session_finalize` (`PreCompact`) only fires on session teardown (`/new`, GC, CLI quit), not during active conversation
- `LLM_WIKI_HERMES_DEBUG=1` env var on the gateway process enables debug logging to stderr (visible in `journalctl --user -u hermes-gateway`)
