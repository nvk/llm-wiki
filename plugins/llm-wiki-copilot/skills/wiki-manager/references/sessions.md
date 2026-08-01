# Session Context Capture

Use this reference for `session`, `session capture`, `rehydrate`, "look at the
last session", automated hook capture, and promotion of session learnings into a
topic wiki.

## Purpose

Session capture preserves agent-session context without polluting curated topic
wikis. The session layer records redacted harness metadata and markdown digests
under the hub-level operational directory `HUB/.sessions/`. Topic wikis receive
session knowledge only through explicit promotion into `raw/notes/`.

This layer is separate from existing research-session files:

| Layer | Path | Meaning |
|---|---|---|
| Research crash state | `.research-session.json`, `.thesis-session.json` | In-progress wiki research/thesis runs |
| Durable research provenance | `.session-events.jsonl`, `.session-checkpoint.json` | Replayable provenance for wiki workflows |
| Harness sessions | `HUB/.sessions/` or `.wiki/.sessions/` | Cross-runtime Codex/Claude/OpenCode/Gemini session context |

## Storage Layout

```text
HUB/.sessions/
├── config.json
├── registry.jsonl
├── state/<harness>/<session_id>.json
├── queue/YYYY-MM-DD.jsonl
├── digests/YYYY/MM/<harness>-<session_id>.md
├── feedback/
│   ├── candidates.jsonl
│   └── status.json
└── indexes/
    ├── by-cwd.json
    ├── by-topic.json
    ├── feedback.json
    └── sessions.json
```

Use the same layout under `.wiki/.sessions/` for local project wikis.

- `config.json` controls automation and rehydration. If it is absent, capture defaults to `balanced`; `enabled: false` is the opt-out switch.
- `registry.jsonl` is append-only lifecycle metadata such as `session_seen` and
  `digest_written`.
- `queue/*.jsonl` stores small redacted hook events. Do not store full prompts,
  tool outputs, or transcript bodies by default.
- `state/` is the latest per-session machine state.
- `digests/` contains human/LLM-readable markdown checkpoints with YAML
  frontmatter.
- `feedback/` stores redacted, reviewable user-feedback candidates such as
  corrections, preferences, approvals, and plan acceptance.
- `indexes/` are derived caches rebuilt from `state/` and feedback candidates.

`.sessions/` is hidden because it is operational, cross-topic, and potentially
private. It should not be compiled as ordinary topic content. A future generated
`HUB/_sessions.md` can expose a human-friendly index, but the canonical store is
`.sessions/`.

## Config Modes

Default mode is `balanced`, even before a config file exists:

```json
{
  "schema_version": 1,
  "enabled": true,
  "mode": "balanced",
  "auto_capture": {
    "tool_events": 50,
    "pre_compact": true,
    "post_compact": true,
    "session_end": true,
    "stop": true
  },
  "rehydrate": {
    "session_start": true,
    "user_prompt": true,
    "strict": false
  },
  "raw_transcripts": false,
  "privacy": "redacted",
  "feedback": {
    "enabled": true,
    "capture_approvals": true,
    "min_confidence": "medium"
  }
}
```

Modes:

| Mode | Capture | Rehydrate | Use when |
|---|---|---|---|
| `off` | none | none | Disabled / user opt-out |
| `capture-only` | automatic checkpoints | no injected context | Maximum privacy/least surprise |
| `balanced` | automatic checkpoints | SessionStart/UserPromptSubmit soft context | Recommended default |
| `aggressive` | more frequent checkpoints | soft context | Long, high-context work |

## Capture Triggers

Hooks should write deterministic checkpoints for:

1. every configured number of observed tool events, default 50;
2. pre-compaction and post-compaction;
3. stop/session-end events;
4. manual `session capture` requests.

"Observed tool events" means events the current harness adapter exposes. Codex,
Claude, OpenCode, and Gemini have different hook coverage, so do not promise an
exact total count across all tool classes.

## Digest Schema

Session digest files are markdown with YAML frontmatter:

```yaml
title: "Session Digest: codex:abc123"
type: session-digest
schema_version: 1
harness: "codex"
native_session_id: "abc123"
llm_wiki_session_id: "codex:abc123"
cwd: "/path/to/project"
git_remote: "https://github.com/org/repo.git"
git_branch: "feature/example"
transcript_path: "/path/to/transcript.jsonl"
started_at: "2026-06-13T17:00:00Z"
last_seen_at: "2026-06-13T18:10:00Z"
tool_event_count: 50
event_count: 61
capture_trigger: "tool-count-50"
topics: []
topic_candidates: []
privacy: "redacted"
raw_transcripts: false
promoted_to: []
summary: "Automated checkpoint for codex:abc123."
```

The body should include session identity, summary, manual notes if any, recent
observed events, distillation notes, and open loops. It should not include full
transcript text by default.

## Hook Adapter Contract

Each runtime adapter should call the same deterministic helper shape:

```bash
llm-wiki-session hook --harness <codex|claude|opencode|gemini> --if-enabled
```

The command reads the harness hook JSON object from stdin and should:

1. resolve HUB from `~/.config/llm-wiki/config.json` unless `--hub` or `--local`
   is supplied;
2. exit 0 without writing if `--if-enabled` is set and `.sessions/config.json`
   has `enabled: false`; missing config means default-on balanced capture;
3. append a redacted event to `queue/YYYY-MM-DD.jsonl`;
4. update `state/<harness>/<session_id>.json`;
5. write a digest if a capture trigger fired;
6. optionally append a redacted feedback candidate for high-signal user turns;
7. optionally emit a short `additionalContext` block only for rehydration hooks
   when config enables it.

Hooks must be fast. If future versions do LLM distillation, enqueue work for a
background worker instead of doing it inline inside every tool hook.

## Codex Hook Packaging

Codex plugins can bundle hooks in `hooks/hooks.json`. Plugin-bundled hooks still
require the user to review/trust them. The bundled llm-wiki Codex hook should
call the copied helper in the plugin root and use `--if-enabled`, so users can
turn capture off with `session disable` without editing hook manifests.

Useful Codex events:

- `SessionStart` and `UserPromptSubmit` for soft rehydration;
- `PostToolUse` for observed tool counters;
- `PreCompact` and `PostCompact` for compaction checkpoints;
- `Stop` for final checkpoints.

## Claude/OpenCode/Gemini Adapters

For Claude Code, use command hooks on `SessionStart`, `UserPromptSubmit`,
`PostToolUse`, `PostToolBatch`, `PreCompact`, `PostCompact`, `Stop`, and
`SessionEnd` where available. Keep `SessionEnd` especially short or detached.

For OpenCode, use plugin events such as session/message/tool execution and the
compaction hook surface. For Gemini CLI, use `AfterTool`, `PreCompress`,
`AfterAgent`, `SessionStart`, and related hook events. All adapters normalize to
the same `.sessions/` files.

## Rehydration

Rehydration is a compact context block, not a bulk transcript paste:

```text
llm-wiki session context: review these distilled session digests before continuing.
- codex:abc123 — Automated checkpoint summary. Digest: /abs/path/HUB/.sessions/digests/2026/06/codex-abc123.md
Do not treat session digests as canonical topic knowledge until promoted into a topic wiki.
```

Soft rehydration can be injected on `SessionStart` or `UserPromptSubmit` in
balanced/aggressive modes. Manual rehydration should be available with:

```bash
llm-wiki-session rehydrate --cwd "$PWD"
llm-wiki-session rehydrate --session-id codex:abc123
llm-wiki-session rehydrate --topic meta-llm-wiki
```

Strict forced continuation is not the default. If implemented later, it must be
opt-in and guard against loops with per-turn counters and stop-hook-active flags.

## Feedback Candidates

User-prompt hooks may create feedback candidates under `.sessions/feedback/`
when the user gives a correction, preference, explicit approval, or plan
acceptance. Generic acknowledgements such as `ok`, `thanks`, and `cool` are
ignored by default. Review candidates with:

```bash
llm-wiki-session feedback list --unpromoted
llm-wiki-session feedback show fb-abc123
```

Promote selected feedback with:

```bash
llm-wiki-session feedback promote fb-abc123 --topic meta-llm-wiki
```

Feedback promotion writes a distilled raw note under the target topic and logs a
`feedback` entry. See [feedback.md](feedback.md) for taxonomy and policies.

## Promotion

Session digest promotion is explicit:

```bash
llm-wiki-session promote codex:abc123 --topic meta-llm-wiki
```

Promotion writes a topic raw note:

```text
HUB/topics/<topic>/raw/notes/YYYY-MM-DD-session-<harness>-<session>.md
```

The raw note links back to the digest and copies only the distilled digest body,
not the raw transcript. Append the topic `log.md` entry. Compilation into
`wiki/` articles remains a separate, explicit wiki compile/update step.

## Privacy Defaults

- Redact obvious token/password/authorization fields in event previews.
- Store transcript pointers and hashes, not transcript bodies.
- Keep raw transcript archiving disabled unless the user explicitly opts in.
- Do not auto-promote session material or feedback candidates into topic wikis.
- Do not let hook failures block normal agent work; fail closed to no capture,
  not to broken tool execution.
- To opt out, run `llm-wiki-session disable` or ask `@wiki session disable`; this writes `enabled: false`.
