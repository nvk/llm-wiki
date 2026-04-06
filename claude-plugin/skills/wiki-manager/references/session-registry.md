# Session Registry

## Purpose
Persistent state for multi-round research and thesis sessions, enabling crash recovery and round-to-round continuity.

## Research Session Schema (.research-session.json)

```json
{
  "session_id": "2026-04-06-143022",
  "topic": "research topic",
  "start_time": "2026-04-06T14:30:22Z",
  "min_time_budget": "2h",
  "current_round": 2,
  "rounds_completed": [
    {
      "round": 1,
      "start_time": "2026-04-06T14:30:22Z",
      "end_time": "2026-04-06T15:02:45Z",
      "sources_ingested": 5,
      "articles_compiled": 3,
      "gaps": ["gap1 description", "gap2 description"],
      "progress_score": 65,
      "reflection_notes": "Initial broad coverage complete. Gap1 is highest priority."
    }
  ],
  "cumulative_sources": 5,
  "cumulative_articles": 3,
  "status": "in_progress"
}
```

## Thesis Session Schema (.thesis-session.json)

```json
{
  "session_id": "2026-04-06-143022",
  "thesis": "claim statement",
  "current_round": 2,
  "rounds_completed": [
    {
      "round": 1,
      "evidence_for": 4,
      "evidence_against": 2,
      "verdict_direction": "partially-supported",
      "next_round_focus": "opposing"
    }
  ],
  "status": "in_progress"
}
```

## Lifecycle

| Event | Action |
|-------|--------|
| --min-time research starts | Create .research-session.json |
| Round N completes | Update rounds_completed, cumulative counts, status |
| Research completes normally | Delete file (data persists in log.md) |
| Session interrupted | File persists with status: "in_progress" |
| Next invocation detects file | Ask: continue or start fresh? |
| File > 7 days old | Structural Guardian warns about stale session |

## Resume Protocol

1. Detect `.research-session.json` or `.thesis-session.json` in wiki root
2. Read file, extract last completed round
3. Ask user: "Found interrupted session (Round N, M sources). Continue or start fresh?"
4. If continue: use round N's gaps/reflection as starting point for round N+1
5. If fresh: delete file, proceed normally

## Notes
- Session files are ephemeral — never commit to git
- Never include in index counts or structural health checks
- One session per wiki at a time (new session overwrites old)
