# Feedback Curator Reference

Use this reference for `feedback`, `user feedback`, `capture the correction`,
`the user said that was right`, approval signals, plan acceptance, and promotion
of feedback lessons into topic wikis.

## Purpose

The feedback curator decides which user responses are worth remembering. It is a
candidate layer between raw session hooks and durable wiki knowledge:

1. hooks or manual commands distill small feedback candidates;
2. candidates live under `HUB/.sessions/feedback/`;
3. the user or agent reviews candidates;
4. only selected candidates are promoted into a topic wiki `raw/notes/` file.

This keeps the wiki from learning noise while still preserving corrections,
preferences, and validation that should influence future sessions.

## Signal Taxonomy

| Signal | Value | Capture? | Notes |
|---|---:|---|---|
| Correction/redirection | high | yes | "wrong", "actually", "do not", "use X instead" |
| Preference/rule | high | yes | "I prefer", "default should", "always", "never", "next time" |
| Explicit approval | medium | yes | "that worked", "that fixed it", "yes, that's right" |
| Plan acceptance | medium | yes | "do it", "go ahead", "ship it", "release it" |
| Generic acknowledgement | low | no | "ok", "cool", "thanks" without context |

Approval and plan-acceptance candidates are useful, but they are scoped to the
immediately preceding conversation unless a session digest gives stronger
context.

## Storage Layout

```text
HUB/.sessions/
├── feedback/
│   ├── candidates.jsonl
│   └── status.json
└── indexes/
    └── feedback.json
```

- `feedback/candidates.jsonl` is append-only. Each row is a distilled candidate,
  not a transcript.
- `feedback/status.json` records promotions by candidate id.
- `indexes/feedback.json` is a derived cache for list/show workflows.

Candidate fields include `id`, `llm_wiki_session_id`, `feedback_type`,
`confidence`, `scope_hint`, `text_preview`, `text_sha256`, `distilled_lesson`,
`promotion_recommendation`, `cwd`, `git_remote`, and `git_branch`.

## Capture Rules

Capture a candidate when a user turn contains one of these durable signals:

- correction: the user says the agent was wrong or redirects the approach;
- preference: the user states a desired default, workflow, environment rule, or
  future behavior;
- approval: the user says the prior result worked or was correct;
- decision: the user accepts a proposed plan or asks the agent to proceed.

Do not capture every short acknowledgement. If the only text is `ok`, `thanks`,
`cool`, or equivalent, ignore it unless the user explicitly asks to capture it.

## Promotion

Promotion is explicit:

```bash
llm-wiki-session feedback promote fb-abc123 --topic meta-llm-wiki
```

Promotion writes:

```text
HUB/topics/<topic>/raw/notes/YYYY-MM-DD-feedback-<type>-<id>.md
```

The note contains the distilled lesson, redacted user-feedback preview, metadata,
and guidance. It does not copy the raw transcript. Append the topic `log.md` with
a `feedback` entry.

## Relationship to Lessons Learned

Feedback candidates are small, automatic, and reviewable. `/wiki:ll` is broader:
it scans a whole session for error→fix patterns, discoveries, and gotchas.
Promoted feedback notes can later feed `/wiki:ll`, compilation, or rule updates,
but feedback capture alone should not rewrite AGENTS.md or skills.

## Privacy Defaults

- Store redacted previews and hashes, not complete prompts or transcripts.
- Redact obvious token/password/authorization material.
- Keep generic acknowledgements out of durable memory.
- Require explicit promotion into topic wikis.
- Treat approval as contextual validation, not a global fact.
