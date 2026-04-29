---
description: "Truth-seeking umbrella audit for llm-wiki. Combines wiki maintenance, output drift checks, provenance review, and fresh research when trust is in doubt."
argument-hint: "scan [--artifact <path>] [--project <slug>] [--wiki-only] [--outputs-only] [--quick] [--fresh] | report [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(mkdir:*), WebFetch, WebSearch, Agent
---

## Your task

**Resolve the wiki.** Do NOT search the filesystem or read reference files until the wiki location is known — follow these steps:
1. Read `$HOME/.config/llm-wiki/config.json`. If it has `resolved_path` -> HUB = that value, skip to step 3. If only `hub_path`, expand leading `~` only (not tildes in `com~apple~CloudDocs`), set HUB, write `resolved_path` back, skip to step 3.
2. If no config -> read `$HOME/wiki/_index.md`. If it exists -> HUB = `$HOME/wiki`. If nothing found, ask the user where to create the wiki.
3. **Wiki location** (first match): `--local` -> `.wiki/` in CWD; `--wiki <name>` -> `HUB/wikis.json` lookup; CWD has `.wiki/` -> use it; else -> HUB.
4. Read `<wiki>/_index.md` to verify. If missing -> stop with "No wiki found. Run `/wiki init` first."

Read the audit reference at `skills/wiki-manager/references/audit.md`. If you need a fresh wiki-only pass, also read `commands/librarian.md` and reuse its scan protocol rather than inventing a parallel one.

### Parse $ARGUMENTS

Default subcommand is `scan`.

- **scan**: Run the umbrella trust audit
- **report**: Display the latest `.audit/REPORT.md`

Flags:

- **--artifact <path>**: Audit one artifact relative to the wiki root. Supports `wiki/...` articles or `output/...` artifacts.
- **--project <slug>**: Audit outputs in `output/projects/<slug>/`
- **--wiki-only**: Only run the wiki-content pass
- **--outputs-only**: Skip the wiki-wide pass and focus on outputs plus their dependency chains
- **--quick**: Local-only audit. Skip fresh web research unless the user explicitly demands it.
- **--fresh**: Ignore cached `.librarian/scan-results.json` and run a fresh wiki-content pass first
- **--wiki <name>**: Target a specific topic wiki
- **--local**: Use project-local `.wiki/`

### Scan Protocol

#### 0. Initialize scope

1. Create `.audit/` if it does not exist.
2. Derive the audit scope:
   - `--artifact` -> just that artifact
   - `--project` -> markdown deliverables under `output/projects/<slug>/`, excluding `WHY.md`
   - `--wiki-only` -> all wiki articles
   - `--outputs-only` -> all markdown outputs under `output/`, excluding `_index.md` and `WHY.md`
   - default -> full umbrella audit
3. Record the scope, timestamp, and selected flags for the report.

#### 1. Wiki-content pass

Skip this pass only when `--outputs-only` is set and the targeted artifact does not depend on wiki articles.

1. If `.librarian/scan-results.json` exists and is recent enough for the current task, reuse it unless `--fresh` is set.
2. Otherwise run the librarian scan protocol from `commands/librarian.md`.
3. Pull forward the findings that matter for trust:
   - stale wiki articles
   - low-quality wiki articles
   - weak or broken source chains

#### 2. Output dependency and drift pass

Skip this pass only when `--wiki-only` is set.

1. Build the output artifact list from scope.
2. For each artifact:
   - Read frontmatter and capture `sources:`, `generated:`, `project:`
   - Flag `missing-provenance` if `sources:` is absent or empty
   - Resolve every dependency path
   - Flag `broken-source-ref` if a dependency does not exist
   - Compare dependency dates (`updated:`, `ingested:`, `generated:`) against the artifact's `generated:` date
   - Flag `drifted-dependency` if any dependency is newer than the artifact
   - If a dependency is a wiki article, inherit relevant librarian findings
   - If a dependency is another output artifact, recurse one hop into its `sources:` chain
3. Classify each artifact as `clean`, `drifted`, `provenance-gap`, `weak-evidence`, `contradicted`, or `unresolved`.

#### 3. Truth escalation pass

This is the defining behavior of `/wiki:audit`. Do not stop at "it looks stale" if the truth can be resolved with more investigation.

Escalate when:
- the user explicitly asks whether they can trust an artifact
- an output is drifted or has a provenance gap
- upstream wiki material is stale, weak, or contradictory
- the topic is volatile or the stakes are high

For each escalated item:

1. Re-read the artifact and identify the specific claims under scrutiny.
2. Re-read local dependencies and any cited raw sources.
3. If raw sources map to live URLs, fetch the primary material again when possible.
4. Unless `--quick` is set, run targeted fresh research:
   - one line of search that tries to confirm the claim
   - one line of search that tries to disprove or weaken the claim
5. Prefer primary sources, official docs, papers, and direct evidence.
6. If Agent is available and the item is important, you may split the work into support and attack branches in parallel.
7. End each escalated item with a truth verdict:
   - `supported`
   - `weakened`
   - `contradicted`
   - `unresolved`

#### 4. Session provenance pass

1. Check for `.session-events.jsonl`, `.session-checkpoint.json`, `.research-session.json`, and `.thesis-session.json`.
2. Classify provenance as:
   - `replayable`
   - `partial`
   - `missing`
3. Report provenance limitations clearly, but do not confuse them with content errors.

#### 4b. Maintain durable audit provenance

1. At audit start, append an `audit_started` event to `.session-events.jsonl`.
2. After the output scan and any fresh truth-seeking research, append milestone events such as:
   - `audit_output_scan_completed`
   - `audit_truth_escalation_completed`
3. Refresh `.session-checkpoint.json` with:
   - `command: "audit"`
   - audit scope
   - targeted artifact paths
   - current trust verdict counts
   - provenance state
   - hashes or paths for `.audit/scan-results.json` and `.audit/REPORT.md` once written
4. After the report files are written, append `audit_completed` and refresh `.session-checkpoint.json` one last time.
5. Do not delete `.session-events.jsonl` or `.session-checkpoint.json` on normal completion.

#### 5. Write reports

1. Write `.audit/scan-results.json` with summary counts, wiki findings, output findings, truth investigations, and provenance state.
2. Write `.audit/REPORT.md` as the human-readable report.
3. Append to `.audit/log.md`:
   `## [YYYY-MM-DD] scan | scope=<scope>, outputs=N, drifted=M, escalations=K`
4. Append to the wiki root `log.md`:
   `## [YYYY-MM-DD] audit | scope=<scope>, outputs=N, drifted=M, escalations=K`

#### 6. Present results

Lead with the trust verdicts, not raw diagnostics.

Your summary should answer:
1. Can the user trust the targeted artifact or wiki right now?
2. What is drifted, contradicted, or unresolved?
3. What additional research did the audit perform?
4. What should the user do next?

Use concrete next-step commands when helpful:
- `/wiki:librarian` for focused wiki maintenance
- `/wiki:refresh <path>` for stale wiki articles
- `/wiki:research ...` when the audit found a real knowledge gap

### Report subcommand

When the user runs `report`:

1. If `.audit/REPORT.md` does not exist, respond: "No audit report found. Run `/wiki:audit` first."
2. Read and display `.audit/REPORT.md`.
3. Mention when the audit ran and whether it reused or refreshed the librarian pass.
