---
description: "Extract lessons learned from the current session. Scans conversation for error→fix patterns, user corrections, and discoveries, then saves structured lessons to the wiki."
argument-hint: "[\"topic hint\"] [--wiki <name>] [--local] [--dry-run] [--rules]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(mkdir:*)
---

## Your task

**Resolve the wiki.** Do NOT search the filesystem or read reference files — follow these steps:
1. Read `$HOME/.config/llm-wiki/config.json`. If it has `resolved_path` → HUB = that value, skip to step 3. If only `hub_path`, expand leading `~` only (not tildes in `com~apple~CloudDocs`), set HUB, write `resolved_path` back, skip to step 3.
2. If no config → read `$HOME/wiki/_index.md`. If it exists → HUB = `$HOME/wiki`. If nothing found, ask the user where to create the wiki.
3. **Wiki location** (first match): `--local` → `.wiki/` in CWD; `--wiki <name>` → `HUB/wikis.json` lookup; CWD has `.wiki/` → use it; else → HUB.
4. Read `<wiki>/_index.md` to verify. If missing and no wiki matches the session topic → offer to create one with `--new-topic`; otherwise target the most relevant existing wiki.

Extract lessons learned from the current session and save them to the wiki's knowledge pipeline.

Inventory awareness: if a lesson implies a durable follow-up, recurring watch
item, or source/corpus candidate, suggest an inventory record in addition to the
raw lesson note. Do not turn every lesson into inventory; only use it when there
is status, priority, or a next action to track.

### Parse $ARGUMENTS

- **topic hint** (positional, optional): A phrase describing what the session was about. If omitted, infer from conversation context.
- **--wiki <name>**: Target a specific topic wiki
- **--local**: Use project-local `.wiki/`
- **--dry-run**: Show extracted lessons without writing anything
- **--rules**: Also suggest CLAUDE.md / AGENTS.md rule additions

### What This Command Does

Lessons-learned captures knowledge that was **learned by doing** — not by reading. The source material is the current session: errors hit, fixes discovered, corrections from the user, configuration changes, gotchas, and patterns that only emerged during implementation.

This differs from other commands:
- **ingest** takes external material in (URLs, files, text from outside)
- **compile** synthesizes raw sources into articles
- **ll** takes internal experience out (session context → structured knowledge)

### Trigger Patterns (for router)

"learn this", "learn that lesson", "lesson learned", "lessons learned", "absorb this", "capture what we learned", "what did we learn", "session takeaways", "ll"

---

## Stage 1: Session Scan

Read the conversation history and identify lesson-worthy events. Look for these signals, in priority order:

### 1a. Error→Fix Patterns
Sequences where something failed, was diagnosed, and fixed. Extract:
- **Symptom**: The error message or failure behavior
- **Assumption**: What was initially believed (if different from root cause)
- **Root cause**: The actual problem
- **Fix**: What was done to resolve it

### 1b. User Corrections
Moments where the user redirected the approach: "no, not that", "wrong profile", "use X instead", "that's the wrong file." Each correction implies a lesson about what the correct approach is.

### 1c. Discoveries
Things that worked unexpectedly, or where the solution required non-obvious knowledge. The test: "would this have been obvious to someone starting the same task?"

### 1d. Configuration Changes
Files that were created or modified during the session — especially dotfiles, settings, profiles, shell configs. These represent materialized decisions.

### 1e. Gotchas & Quirks
Platform-specific behaviors, tool-specific edge cases, or undocumented behaviors encountered. Things that would trip up the next person doing similar work.

---

## Stage 2: Lesson Extraction

For each identified event, produce a structured lesson:

```markdown
## Lesson N: <title>

**Category**: gotcha | pattern | rule | discovery | correction
**Context**: <what was being done when this was learned>
**Symptom**: <the error or failure, if applicable>
**Root cause**: <why it happened>
**Fix**: <what was done>
**Rule**: <the generalizable principle — one sentence that applies beyond this specific case>
```

Guidelines:
- **Deduplicate**: If multiple events teach the same lesson, merge them into one with the clearest example
- **Generalize**: The "Rule" field must be useful outside the specific session. "Add user_caches_macos to custom-codex profile" is a fix. "Each AI tool needs its own nono profile extending that tool's built-in profile" is a rule.
- **Be specific**: Include exact error messages, file paths, tool names. Vague lessons ("be careful with symlinks") are useless. Specific lessons ("nono resolves symlinks before checking access, so the target path must also be in the allowed list") are actionable.
- **Count**: A typical session yields 2-7 lessons. If you find more than 10, you're being too granular. If you find fewer than 2, look harder.

---

## Stage 3: Wiki Targeting

Determine which wiki and which articles the lessons belong to.

1. If `--wiki <name>` is specified, use that wiki
2. Otherwise, scan the lesson topics against `HUB/wikis.json` descriptions. Pick the best-matching wiki.
3. If no wiki matches well, offer: "These lessons are about `<topic>`. Create a new wiki? (`--new-topic <name>`)" or ask which existing wiki to use.

For each lesson, grep the target wiki's articles for related keywords. If a relevant article exists, note it for Stage 5 updates.

---

## Stage 4: Write Raw Note

Create `raw/notes/YYYY-MM-DD-ll-<slug>.md` in the target wiki:

```markdown
---
title: "Lessons Learned: <session topic>"
type: lessons-learned
source: session
date: YYYY-MM-DD
tags: [lessons-learned, <topic-tags>]
lesson_count: N
category: notes
confidence: high
summary: "<one-line summary of what was learned>"
---

# Lessons Learned: <session topic>

> Extracted from session on YYYY-MM-DD. N lessons covering <brief scope>.

## Lesson 1: <title>

**Category**: <category>
**Context**: <context>
**Symptom**: <symptom>
**Root cause**: <root cause>
**Fix**: <fix>
**Rule**: <generalizable rule>

## Lesson 2: <title>
...
```

Follow the chunked writes principle (core principle #9): write the frontmatter and first lesson, then Edit to append remaining lessons one at a time.

---

## Stage 5: Article Updates (if applicable)

For each lesson where a relevant wiki article was identified in Stage 3:

1. Read the article
2. Find the most relevant section
3. Use Edit to append the lesson's **Rule** as a new subsection or bullet, with a back-reference to the raw note
4. Do NOT rewrite existing content — only append

If no article matches, skip this stage. The lesson stays in `raw/notes/` and will be integrated during the next `/wiki:compile`.

---

## Stage 6: Rule Suggestions (if --rules)

If `--rules` is passed, scan each lesson's "Rule" field and propose additions to:

1. **CLAUDE.md** — if the rule applies globally across projects
2. **Project CLAUDE.md** — if the rule is project-specific
3. **AGENTS.md** — if the rule applies to non-Claude agents too

Present each proposed rule with:
- The exact text to add
- Where to add it (which section, after which existing rule)
- Why it's useful

Do NOT auto-edit CLAUDE.md/AGENTS.md. Present the proposals and let the user approve each one.

---

## Stage 7: Log & Report

1. **Update indexes**: Add the raw note to `raw/notes/_index.md` (or invalidate for rebuild)
2. **Log**: Append to `log.md`:
   `## [YYYY-MM-DD] ll | "<session topic>" → raw/notes/YYYY-MM-DD-ll-<slug>.md (N lessons, M articles updated)`
3. **Report**: Show the user:
   - Number of lessons extracted
   - Each lesson title + rule (one line each)
   - Which articles were updated (if any)
   - Suggested rules (if `--rules`)

---

## --dry-run Behavior

When `--dry-run` is passed:
1. Run Stages 1-3 normally (scan, extract, target)
2. Display what would be written — the full raw note content and any article updates
3. Do NOT write any files
4. Ask: "Save these lessons? (y/n)"
5. If yes, proceed with Stages 4-7

---

## Examples

```bash
# Basic: extract lessons from current session
/wiki:ll

# With topic hint for better wiki targeting
/wiki:ll "nono sandbox setup"

# Target a specific wiki
/wiki:ll --wiki cli-ai-coding

# Preview before saving
/wiki:ll --dry-run

# Also suggest CLAUDE.md rules
/wiki:ll --rules

# Full: dry-run with rule suggestions
/wiki:ll "nono codex profile debugging" --wiki cli-ai-coding --dry-run --rules
```
