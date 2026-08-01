---
description: "Review, capture, and promote curated user-feedback candidates detected from session hooks."
argument-hint: "list|show|capture|promote [options]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(mkdir:*), Bash(python3:*), Bash(scripts/llm-wiki-session:*)
---

## Your task

Manage the feedback-curator layer for llm-wiki sessions. Feedback candidates are
small distilled records of user corrections, preferences, approvals, and plan
acceptance signals. They live under `HUB/.sessions/feedback/` until explicitly
promoted into a topic wiki.

First read `references/feedback.md` and `references/sessions.md`, then resolve
HUB by the standard hub-resolution protocol from `references/hub-resolution.md`.
Prefer the deterministic helper when available:

```bash
scripts/llm-wiki-session --hub "$HUB" feedback <subcommand>
```

### Parse $ARGUMENTS

- `list [--unpromoted] [--type correction|preference|approval|decision|manual] [--min-confidence low|medium|high]`: show captured candidates.
- `show <candidate-id>`: display one candidate with its distilled lesson and redacted user-feedback preview.
- `capture --text "..." [--session-id <id>]`: manually add a feedback candidate.
- `promote <candidate-id> --topic <slug>`: write the candidate into the target topic's `raw/notes/` layer and append the topic log.

### Policy

1. Candidate capture is allowed from trusted hooks, but promotion is explicit.
2. Do not treat generic acknowledgements (`ok`, `thanks`, `cool`) as durable lessons.
3. High-value feedback includes corrections, preferences, `always`/`never` rules, and explicit statements that the agent did the right thing.
4. Approval/decision candidates are validation of the immediately preceding context unless corroborated by a session digest.
5. Store redacted previews and hashes, not full transcripts.

### Examples

```bash
scripts/llm-wiki-session --hub "$HUB" feedback list --unpromoted
scripts/llm-wiki-session --hub "$HUB" feedback show fb-abc123
scripts/llm-wiki-session --hub "$HUB" feedback capture --text "next time use the release checklist before tagging"
scripts/llm-wiki-session --hub "$HUB" feedback promote fb-abc123 --topic meta-llm-wiki
```

Report absolute paths for every promoted note. Append topic `log.md` when
promoting into a topic wiki.
