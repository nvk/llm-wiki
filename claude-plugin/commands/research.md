---
description: "Deep multi-agent research on a topic, question, or thesis. Launches parallel agents to search the web, ingests sources, and compiles them into wiki articles. Thesis mode provides for/against evidence framing with a verdict."
argument-hint: "<topic|question> [--plan] [--mode thesis \"<claim>\"] [--new-topic] [--sources <N>] [--deep] [--retardmax] [--min-time <duration>] [--wiki <name>] [--local] [--project <slug>]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(mkdir:*), WebFetch, WebSearch, Agent
---

## Your task

Conduct deep research on the topic in $ARGUMENTS. This is an automated pipeline: search → ingest → compile.

### Parse $ARGUMENTS

- **topic/question**: The research subject — everything that is not a flag. Auto-detected as topic vs question (see Input Detection below).
- **--mode thesis "<claim>"**: Activate thesis mode. The claim is the scope constraint — sources that don't relate to it are skipped. Agents evaluate evidence for/against. A verdict is rendered at the end. See Thesis Research Mode below.
- **--new-topic**: Create a new topic wiki from the topic name and start researching into it. Works from any directory. Derives the wiki slug from the topic (e.g., "quantum error correction" → `quantum-error-correction`).
- **--sources <N>**: Target sources PER ROUND (default: 5, max: 20)
- **--deep**: 8 parallel agents with broader search angles
- **--retardmax**: 10 agents, skip planning, ingest aggressively
- **--min-time <duration>**: Minimum research time. Keep running research rounds until this duration is reached. Formats: `30m`, `1h`, `2h`, `4h`. Default: single round (no minimum).
- **--wiki <name>**: Target a specific existing topic wiki
- **--local**: Use project-local `.wiki/`
- **--plan**: Decompose the topic into 3-5 independent research paths, present the plan for confirmation, then execute all paths in parallel. Each path gets its own agent group (5 agents standard, 8 with `--deep`). Ingest runs in parallel across paths (each path writes unique raw files); compilation runs once after all paths complete (single pass sees all sources for better cross-referencing). Without `--plan`, research runs a single path as before. See Plan Mode below.
- **--project <slug>**: Tag all new outputs with this project. The research playbook/summary artifact is saved inside `output/projects/<slug>/` instead of flat `output/`. Compiled wiki articles get `project: <slug>` frontmatter. If the project doesn't exist, fail early with a helpful error. See `references/projects.md` for the projects architecture.

### `--project <slug>` flag

If `--project <slug>` is set, the research playbook/summary artifact is saved inside `output/projects/<slug>/` instead of flat `output/`, and compiled wiki articles get `project: <slug>` frontmatter. Verify the project exists at `<wiki-root>/output/projects/<slug>/WHY.md` before starting; if not, fail early with a suggestion to run `/wiki:project new <slug> "goal"` first.

There is no ambient project focus — pass `--project` explicitly when you want project scope. The focus-session mechanism was removed in the v0.2 projects simplification; see `references/projects.md` § "Focus" for the rationale.

### Resolve HUB and wiki

Follow the standard prelude in `skills/wiki-manager/references/command-prelude.md` (variant: **wiki-creating** — `--new-topic` creates a topic wiki on the fly; otherwise stop with "No wiki found. Use `--new-topic` to create one, or run `/wiki init <topic>` first.").

**When `--new-topic` is set**, override the standard resolution:
1. Derive a slug from the topic: lowercase, hyphens, no special chars, max 40 chars
2. If HUB doesn't exist, create it (wikis.json + _index.md + log.md + topics/)
3. Create the new topic wiki at `HUB/topics/<slug>/` following the full init protocol (directory structure, .obsidian/, empty _index.md files, config.md, log.md)
4. Register in `HUB/wikis.json` and update hub `_index.md`
5. Target this new wiki for all research that follows

**When `--new-topic` is NOT set**, the standard prelude resolution applies, with one deviation: step 4 (fallback to HUB) becomes "ask which topic wiki to target" — research against an empty hub doesn't make sense.

### Minimum Time Research (`--min-time`)

#### Multi-Round Session State

When `--min-time` is set, create and maintain a session registry file for crash recovery and round-to-round state:

**Location**: `<wiki-root>/.research-session.json`

**Schema**:
```json
{
  "session_id": "YYYY-MM-DD-HHmmss",
  "topic": "research topic",
  "mode": "single|plan",
  "start_time": "ISO 8601",
  "min_time_budget": "2h",
  "current_round": 1,
  "paths": [
    {
      "name": "Path name",
      "focus": "What this path investigates",
      "search_angles": ["angle1", "angle2"],
      "status": "pending|in_progress|completed|failed",
      "sources_ingested": 3
    }
  ],
  "rounds_completed": [
    {
      "round": 1,
      "sources_ingested": 5,
      "articles_compiled": 3,
      "gaps": ["gap1", "gap2"],
      "progress_score": 65
    }
  ],
  "cumulative_sources": 5,
  "cumulative_articles": 3,
  "status": "in_progress"
}
```

The `mode` field defaults to `"single"` for backward compatibility. When `--plan` is set, `mode` is `"plan"` and `paths` is populated. For single-path sessions, `paths` is omitted. See `references/research-infrastructure.md` § Research Plan Schema for the full schema and resume protocol.

**Lifecycle**:
1. **Create** at session start (Round 1 begins)
2. **Update** after each round completes — sources, articles, gaps, progress score
3. **On completion** → set status to "completed", delete file (data is in log.md)
4. **On interruption** → file persists with status "in_progress"

**Resume detection**: At command start, if `.research-session.json` exists with `status: "in_progress"`:
- Read the file to understand what was already done
- Ask: "Found interrupted session (Round N, M sources so far). Continue from Round N+1, or start fresh?"
- If continue: skip Phase 1, read round N's gaps as starting point for round N+1
- If fresh: delete the file and start over

**Cleanup**: Delete `.research-session.json` when research completes normally. The data lives in `log.md` permanently.

When `--min-time` is set, research runs in ROUNDS until the time budget is spent:

```
Round 1: Run full research protocol (Phase 1-5)
         → Produces gaps, progress score, and suggested follow-ups
         → Update .research-session.json
         → Check elapsed time

Reflect: Review ALL findings so far holistically (not just this round's gaps)
         → Score each gap: impact (1-5) × feasibility (1-5) × specificity (1-5)
         → Re-evaluate: Has the research direction shifted? Are earlier gaps still relevant?
         → Pick top 3 gaps by composite score for next round
         → If progress score ≥ 80 and no high-impact gaps → recommend early completion

Round 2: Run research on top 3 gaps as subtopics
         → Compile into wiki, discover new gaps
         → Update .research-session.json
         → Check elapsed time

Reflect: Same holistic reflection — look for cross-topic connections between rounds
         → Research shows this catches 34% more cross-topic connections than gap-picking alone

Round 3+: Continue pattern (research → reflect → decide) until:
          - --min-time is reached, OR
          - Progress score ≥ 80 with no high-impact gaps (early completion), OR
          - Two consecutive rounds with progress score < 40 (diminishing returns)

Final:   Run /wiki:lint --fix to clean up
         → Generate a summary of everything researched
         → Report total: rounds, sources, articles, progress trajectory, time spent
         → Delete .research-session.json
```

**Round strategy:**
- Each round picks the most important unfilled gaps from the previous round's report
- Subtopics get progressively more specific as rounds continue (broad → narrow → niche)
- If a round finds no new gaps, switch to `--deep` mode on existing articles to find connections and contradictions
- If still no gaps after deep mode, research is complete regardless of remaining time — report early completion
- Each round logs to `log.md` independently
- **Progress-based termination**: After each round, calculate a progress score (0-100). If score ≥ 80 and no high-priority gaps remain, recommend early completion even if time budget remains — more rounds of diminishing returns waste tokens without improving quality.
- **Low-yield detection**: If a round's progress score is < 40, the round produced little value. Switch strategy: try --deep angles, broaden search terms, or narrow topic focus. Don't keep doing the same thing.

**Time tracking:**
- Check wall clock at the start and after each round
- A round that would exceed the time budget by more than 50% should not start (e.g., if 45 min left and rounds average 40 min, run it; if 10 min left, don't)
- Report time spent in final summary

**Example:**
```
/wiki:research "CRISPR gene therapy" --new-topic --min-time 2h --deep
```
Creates `HUB/topics/crispr-gene-therapy/`, then runs ~3-5 research rounds over 2 hours, progressively drilling into subtopics the earlier rounds surfaced.

### Input Detection: Topic vs Question vs Thesis

Before starting research, detect the input mode:

- **Thesis** (explicit): `--mode thesis` flag is set → enter Thesis Research Mode (see below).
- **Thesis** (auto-detected): input contains "prove that", "is it true that", "verify", "test the claim", "test the hypothesis" → enter Thesis Research Mode. The claim text is the input minus the signal words.
- **Question**: starts with what/why/how/when/where/who, contains a "?", or is phrased as a goal ("how to...", "what makes...", "why does...") → enter Question Research Mode.
- **Topic**: a noun/phrase naming a subject area → proceed with standard research protocol.

**If topic** → proceed with standard research protocol below.

**If question** → enter Question Research Mode:

#### Question Research Mode

The question itself is the scope constraint — like a thesis constrains thesis research.

**Step 1: Decompose the question** into 3-5 focused sub-questions. Example:

Input: "What makes long form articles go viral and how to replicate it"
Decomposition:
- **What**: What patterns do viral long-form articles share? (structure, length, hooks, format)
- **Why**: What psychological/social mechanisms drive sharing? (emotion, identity, utility)
- **How**: What is the step-by-step process to write one? (research, outline, writing, distribution)
- **Who**: Who has done this successfully and what do they say? (case studies, practitioner interviews)
- **Data**: What does the data say? (studies on shareability, engagement metrics, platform algorithms)

Present the decomposition to the user. Then proceed.

**Step 2: One agent per sub-question.** Instead of generic angles (academic, technical, applied), each agent targets a specific sub-question. This keeps research focused and produces a complete answer.

| Agent | Sub-question | Search Strategy |
|-------|-------------|----------------|
| Agent 1 | What patterns? | Search for analyses of viral articles, content structure studies, BuzzSumo-style research |
| Agent 2 | Why psychologically? | Search for psychology of sharing, Jonah Berger's research, social currency, emotion triggers |
| Agent 3 | How to do it? | Search for practitioner playbooks, writing frameworks, distribution strategies |
| Agent 4 | Who does it well? | Search for case studies, specific viral articles and breakdowns of why they worked |
| Agent 5 | What does data say? | Search for studies on content virality, engagement data, platform algorithm research |

In `--deep` mode: add agents for adjacent sub-questions discovered during decomposition.
In `--retardmax` mode: add rabbit-hole agents + skip decomposition confirmation.

**Step 3: Compile with structure.** Articles are organized to answer the original question:
- Concept articles for each key finding
- A **topic article** that synthesizes the full answer to the original question — this is the "playbook"
- Reference articles for tools, examples, and further reading

**Step 4: Generate playbook.** After compilation, automatically create an output artifact:
- Save to `output/playbook-{slug}-{YYYY-MM-DD}.md`
- Structure: the original question, key findings per sub-question, actionable steps, examples, sources
- This is the deliverable — a practical, actionable answer filed back into the wiki

**Step 5: Derive theses.** From the findings, suggest 2-3 testable claims that could be investigated with `--mode thesis`. Example: "Articles with a personal narrative hook get 3x more shares than data-led hooks" — this is a specific claim that can be verified.

#### Thesis Research Mode (`--mode thesis`)

**Why this exists as a mode, not a separate command**: thesis research is 70% the same pipeline as topic/question research (agent dispatch, credibility scoring, session registry, multi-round --min-time, compilation, ingestion). The 30% that's different is: scope filtering by claim, for/against agent framing, evidence strength classification, and verdict rendering. Those differences are described below as modifications to the standard phases. Previously this was a separate `/wiki:thesis` command (224 lines) which duplicated all the shared infrastructure.

**Phase 0: Decompose the thesis.** Before any research, break the claim into:

1. **Core claim**: the central assertion in one sentence
2. **Key variables**: the specific things being connected (e.g., "sunlight exposure", "CAA progression", "vitamin D")
3. **Testable prediction**: what would be true if the thesis is correct?
4. **Falsification criteria**: what evidence would disprove it?
5. **Scope boundary**: what is NOT part of this thesis? (This is the bloat filter — if a source doesn't touch these variables, skip it.)

Present the decomposition to the user for confirmation before proceeding.

**Wiki setup modification**: In addition to the standard wiki resolution, create a thesis file at `wiki/theses/<slug>.md`:

```markdown
---
title: "Thesis: <thesis statement>"
type: thesis
status: investigating
created: YYYY-MM-DD
updated: YYYY-MM-DD
verdict: pending
confidence: pending
core_claim: "<one sentence>"
key_variables: [var1, var2, var3]
falsification: "<what would disprove this>"
---

# Thesis: <thesis statement>

## Core Claim
## Key Variables
## Testable Prediction
## Falsification Criteria
## Evidence For
(populated during research)
## Evidence Against
(populated during research)
## Nuances & Caveats
(populated during research)
## Verdict
**Status**: Investigating
```

**Phase 2 modification: thesis-directed agents.** Instead of the standard agent table (Academic, Technical, etc.), use:

| Agent | Focus | Thesis Lens |
|-------|-------|-------------|
| **Supporting** | Evidence that supports the thesis | Search for studies, data, mechanisms that confirm the claim. Strongest evidence first. |
| **Opposing** | Evidence that contradicts the thesis | Counter-evidence, failed replications, alternative explanations. Steelman the opposition. |
| **Mechanistic** | HOW/WHY the thesis could be true or false | Underlying mechanisms, pathways, causal chains connecting the variables. |
| **Meta/Review** | Meta-analyses, systematic reviews, expert consensus | Aggregate evidence on this specific question. These carry the most weight. |
| **Adjacent** | Related findings that nuance the thesis | Edge cases, moderating variables, conditions under which the thesis holds or fails. |

In `--deep` mode, add: **Historical** (evolution of thinking on this claim), **Quantitative** (effect sizes, confidence intervals, dose-response data), **Confounders** (variables that could make a spurious correlation look causal).

Each agent must evaluate: relevance (direct/indirect/tangential — SKIP tangential), evidence strength (meta-analysis > RCT > cohort > case > opinion > anecdotal), and direction (supports/opposes/nuances).

**Phase 4 modification: evidence compilation.** After standard compilation, update the thesis file:
- **Evidence For**: list each supporting finding with source, evidence strength, and one-line summary. Sort by evidence strength (meta-analyses first).
- **Evidence Against**: same format for opposing findings.
- **Nuances & Caveats**: conditions, moderators, edge cases.
- Each finding is marked "Strong" / "Moderate" / "Weak" based on combined credibility + evidence strength.

**Phase 5 modification: verdict.** After all rounds complete, render a verdict in the thesis file:

```markdown
## Verdict
**Status**: Supported | Partially Supported | Insufficient Evidence | Contradicted | Mixed
**Confidence**: High | Medium | Low
**Summary**: 2-3 sentences on what the evidence shows.
**Strongest supporting evidence**: [list]
**Strongest opposing evidence**: [list]
**Key caveats**: [list]
**What would change this verdict**: [specific future findings]
**Suggested follow-up theses**: [derived from findings]
```

Update frontmatter: `status: completed`, `verdict: <result>`, `confidence: <level>`.

**Multi-round modification: anti-confirmation-bias.** When `--min-time` is set:
- **Round 1**: Broad evidence gathering — supporting + opposing + mechanistic
- **Round 2**: Drill into the WEAKEST side. If Round 1 found mostly supporting evidence, Round 2 focuses harder on finding counter-evidence (and vice versa). This prevents confirmation bias — the most important methodological difference from standard research.
- **Round 3+**: Follow up on specific sub-questions, confounders, or moderating variables
- **Final**: Synthesize verdict, update thesis file

Session state uses `.thesis-session.json` instead of `.research-session.json`, tracking evidence for/against counts and current verdict direction per round. Same lifecycle: create → update → delete on completion. Resume detection: "Found interrupted thesis session (Round N, current leaning: X). Continue?"

### Plan Mode (`--plan`)

When `--plan` is set, insert a planning phase between Phase 1 and Phase 2. Plan mode works with topic, question, AND thesis input — it decomposes any of them into parallel paths. It is independent of `--min-time` (which controls multi-round iteration within a single path or after plan execution).

#### Phase 1.5: Research Plan Generation

After Phase 1 (existing knowledge check), generate a research plan:

1. Based on the topic, existing wiki state, and identified gaps, decompose into 3-5 independent research paths. Each path should:
   - Have a clear, non-overlapping scope
   - Be searchable independently (no dependencies on other paths' findings)
   - Target a specific aspect: foundational concepts, current state, practical applications, criticisms/limitations, adjacent connections

2. Present the plan to the user:

   ```
   ## Research Plan — <topic>

   ### Paths (will run in parallel)

   1. **<Path name>**
      Focus: <what this path covers>
      Search angles: <2-3 specific search strategies>
      Target: <N> sources

   2. **<Path name>**
      ...

   ### Estimated
   - <N> paths x <M> agents each = <total> parallel agents
   - Target sources: <total across all paths>
   - Compilation: single pass after all paths complete

   Proceed? (y/n/edit)
   ```

3. Wait for user confirmation. If "edit", let them modify paths. If "n", abort.

#### Phase 2 modification: Parallel Path Dispatch

On confirmation, launch one Agent per path (single message, multiple Agent tool calls). Each path-agent receives:

- Its specific focus and search angles from the plan
- The standard agent template from `references/research-infrastructure.md`
- Instructions to run the full search → credibility → ingest pipeline
- A path identifier used to prefix raw file slugs for deduplication

Each path-agent internally launches its own 5/8/10 sub-agents (standard/deep/retardmax) for the search phase, exactly as single-path research does today.

**File ownership rule**: Each path writes to `raw/<type>/YYYY-MM-DD-<path-slug>-<source-slug>.md`. The path-slug prefix prevents filename collisions between paths.

**Index updates**: Path agents skip `_index.md` updates during parallel ingest. Indexes rebuild on the next read per the Derived Index Protocol (`references/indexing.md`).

#### Phase 4 modification: Cross-Path Compilation

After all path agents return, run a single compilation pass that:

1. Reads ALL newly ingested sources from all paths
2. Follows the standard compilation protocol in `references/compilation.md`
3. Draws cross-references between findings from different paths — this is the plan's primary value: the compiler sees the full picture across all paths simultaneously
4. Creates articles that synthesize across paths where findings connect

#### Phase 5 modification: Plan Report

In addition to the standard report fields, include:

- **Per-path breakdown**: sources found, sources ingested, key findings per path
- **Cross-path connections**: relationships discovered during compilation that span paths
- **Low-yield paths**: paths that returned few sources — suggest follow-up or different search angles

#### Session Registry Extension

When `--plan` is active, `.research-session.json` includes additional fields. See `references/research-infrastructure.md` § Research Plan Schema for the full schema. The `mode` field distinguishes plan sessions from single-path sessions. Resume detection checks `paths[].status` to re-launch only incomplete paths.

#### Interaction with `--min-time`

`--plan` + `--min-time` work together: Round 1 executes the full plan (all paths in parallel). The reflection step identifies remaining gaps. Round 2 generates a NEW plan targeting those gaps (typically 2-3 paths). Each round is a full plan-dispatch-compile cycle. The time budget and progress scoring apply across all rounds, same as single-path `--min-time`.

### Research Protocol (Single Round — Topic Mode)

#### Phase 1: Existing Knowledge Check

1. Read `wiki/_index.md` and `raw/_index.md` to understand what the wiki already knows
2. Use Grep to search for the topic and related terms across existing articles
3. Identify gaps — what specific aspects, subtopics, and questions are NOT covered?
4. Generate a list of 5-8 specific search angles based on the gaps

#### Phase 2: Web Research — Parallel Agent Swarm

Launch agents IN PARALLEL (single message, multiple Agent tool calls) to maximize coverage and speed.

**Standard mode (default):** 5 parallel agents

| Agent | Focus | Search Strategy |
|-------|-------|----------------|
| **Academic** | Peer-reviewed papers, meta-analyses, systematic reviews | Search Google Scholar, PubMed, arxiv. Prioritize recent (last 2 years). Look for landmark papers. |
| **Technical** | Technical deep-dives, specifications, documentation | Search for technical guides, whitepapers, official documentation, engineering blogs. |
| **Applied** | Case studies, real-world implementations, practical guides | Search for how-to guides, industry reports, practitioner perspectives, tutorials. |
| **News/Trends** | Recent developments, announcements, emerging research | Search for news from last 6 months, conference talks, announcements, trend analyses. |
| **Contrarian** | Criticisms, limitations, counterarguments, failed approaches | Search for critiques, rebuttals, known limitations, what doesn't work, common mistakes. |

**Deep mode (`--deep`):** 8 parallel agents — adds:

| Agent | Focus | Search Strategy |
|-------|-------|----------------|
| **Historical** | Origin, evolution, key milestones of the topic | Search for history, foundational papers, how the field evolved, key figures. |
| **Adjacent** | Related fields, interdisciplinary connections | Search for cross-domain applications, analogies from other fields, unexpected connections. |
| **Data/Stats** | Quantitative data, benchmarks, statistics, datasets | Search for surveys, benchmarks, statistical analyses, market data, datasets. |

**Retardmax mode (`--retardmax`):** 10 parallel agents — ALL of the above plus:

| Agent | Focus | Search Strategy |
|-------|-------|----------------|
| **Rabbit Hole 1** | Whatever the first search surfaces — follow the most interesting link | Start with the topic, click the most compelling result, then search for what THAT references. Go deep. |
| **Rabbit Hole 2** | Same strategy, different starting search terms | Use synonyms or adjacent framing of the topic. Follow the trail wherever it goes. |

**Each agent must:**
- Run 2-3 different WebSearch queries (vary terms, don't repeat)
- For each promising result, use WebFetch to extract the full content
- Evaluate quality: Is this authoritative? Peer-reviewed? Recent? Unique perspective?
- Return a ranked list: title, URL, extracted content, quality score (1-5), and why it's worth ingesting
- Target 3-5 high-quality sources per agent
- Skip: paywalled content, SEO spam, thin articles, duplicate information

Retardmax differences:
- **Skip Phase 1 entirely** — don't check what already exists, just go
- Each agent runs 4-5 searches instead of 2-3
- **Lower quality threshold** — ingest anything that's not obviously spam
- **--sources default bumps to 15** (override with explicit --sources)
- Compile fast — don't agonize over article structure
- Rabbit hole agents chase citations and references from pages they find

**Deduplication:** After all agents return, deduplicate by URL and by content similarity. If two agents found the same source, keep it once. If two sources cover identical ground, keep the higher quality one. In retardmax mode, be more lenient.

#### Agent Prompt Template

Every research agent receives a structured prompt following this template. Well-structured prompts are the #1 predictor of agent success — "most sub-agent failures aren't execution failures, they're invocation failures."

**Standard template (all modes)**:
```
You are a research agent. Your task:

**Objective**: Research "{topic}" from the {Agent Role} angle.
**Focus**: {Role-specific focus from the table above}
**Search strategy**: {Strategy from the table above}
**Current wiki state**: The wiki already covers: {brief summary from Phase 1}. Search for what's NOT covered.
**Constraints**:
- Run 2-3 WebSearch queries (vary terms, don't repeat)
- For each promising result, use WebFetch to extract full content
- Skip: paywalled, SEO spam, thin, duplicate
- Target 3-5 high-quality sources

**Return format**: For each source found:
- Title, URL, quality score (1-5)
- Key findings (3-5 bullet points)
- Why it's worth ingesting (1 sentence)

**Quality scoring guide**:
- 5: Peer-reviewed, landmark paper, primary data
- 4: Authoritative blog, official docs, well-sourced industry report
- 3: Decent coverage, some original insight, reasonable sourcing
- 2: Thin, mostly derivative, limited sourcing
- 1: SEO spam, no original content, unverifiable claims
```

**Question mode variant**: Replace "from the {Agent Role} angle" with "answering: {specific sub-question}". Add: "Your deliverable is evidence that answers this specific sub-question."

**Thesis mode variant**: Add thesis filter:
```
**Thesis**: "{thesis statement}"
**Key variables**: {extracted variables}
**Your lens**: {Agent Focus from thesis table}
**Evaluation**: For each source, rate:
- Relevance: direct | indirect | tangential (skip tangential)
- Evidence strength: meta-analysis > RCT > cohort > case study > expert opinion > anecdotal
- Direction: supports | opposes | nuances the thesis
```

#### Phase 2b: Credibility Review

After all agents return and before ingestion, run a credibility assessment. This prevents the "fox guarding the henhouse" problem where agents self-rate their own source quality.

**For each source returned by agents, evaluate**:

| Signal | Scoring |
|--------|---------|
| Peer-reviewed? (DOI, journal name, conference) | +2 if yes, 0 if no |
| Publication recency (last 3 years) | +1 if recent, 0 if older, -1 if >10 years |
| Author authority (known expert, cited elsewhere) | +1 if established, 0 if unknown |
| Potential bias (industry-sponsored, activist org) | -1 if detected, 0 if clean |
| Corroboration (multiple agents found similar claims) | +1 per additional agent, max +2 |

**Credibility tiers**:
- **High** (4-6 points): Peer-reviewed, recent, authoritative, unbiased → ingest with confidence: high
- **Medium** (2-3 points): Published but not peer-reviewed, or older, or unknown author → ingest with confidence: medium
- **Low** (0-1 points): Blog, press release, unverifiable, biased → ingest only if no better source covers this angle; set confidence: low
- **Reject** (<0 points): Obvious spam, predatory journal, fabricated data → skip entirely

**Process**:
1. Score all sources from all agents
2. Deduplicate (same URL = keep once; >80% content overlap = keep higher-credibility one)
3. Rank by (credibility score × agent quality score)
4. Select top N for ingestion (--sources count)
5. Report skipped sources with reasons in Phase 5

In **retardmax mode**: lower the rejection threshold (accept Medium and above without filtering), but still score — the scores carry forward into confidence tags.

#### Phase 3: Ingest

For each high-quality source (up to --sources count, ranked by quality score):

1. Write to `raw/{type}/YYYY-MM-DD-slug.md` with proper frontmatter (title, source URL, type, tags, summary)
2. Auto-detect type: academic → papers, news → articles, code → repos, guides → articles, data → data
3. Update `raw/{type}/_index.md` and `raw/_index.md`
4. Update master `_index.md` source count

#### Phase 4: Compile

1. Read all newly ingested sources
2. Follow the compilation protocol in `skills/wiki-manager/references/compilation.md`:
   - Extract key concepts, facts, relationships
   - Map to existing wiki articles
   - Create new articles or update existing ones
   - Use dual-link format for all cross-references
   - Set confidence levels based on source quality and corroboration:
     - Multiple agents found corroborating sources → high
     - Single source or recent/unverified → medium
     - Contrarian agent only, or anecdotal → low
   - Add bidirectional See Also links
3. Update all `_index.md` files
4. Update master `_index.md` with new stats

#### Phase 5: Report & Log

1. Append to topic wiki `log.md`: `## [YYYY-MM-DD] research | "topic" → N sources ingested, M articles compiled`
2. Append to hub `HUB/log.md`: same entry

3. Report:
   - **Topic researched**: the query
   - **Round**: N of M (if --min-time)
   - **Agents launched**: N (list which angles)
   - **Sources found**: N total across all agents
   - **Sources ingested**: M (list with URLs and quality scores)
   - **Sources skipped**: list with reason (low quality, duplicate, paywall, thin)
   - **Articles created**: list with paths and summaries
   - **Articles updated**: list with what was added
   - **Confidence map**: which claims are high/medium/low confidence and why
   - **New connections**: cross-references discovered between new and existing articles
   - **Remaining gaps**: what's still not covered
   - **Suggested follow-ups**: specific subtopics for next round (or manual `/wiki:research` commands)
   - **Time spent**: this round / total elapsed (if --min-time)
   - **Progress score**: 0-100, calculated as:
     - Sources ingested this round × 3 (max 30)
     - Articles created/updated this round × 5 (max 30)
     - Cross-references added × 2 (max 20)
     - Average source credibility score × 4 (max 20)
     - Score interpretation: 0-40 = minimal, 41-70 = moderate, 71-90 = strong, 91-100 = comprehensive
   - **Cumulative progress** (if --min-time): total across all rounds, round-over-round delta
   - **Termination recommendation**: If progress score ≥ 80 AND remaining gaps are low-priority AND cross-reference density is high (>60% of articles linked) → "Research quality ceiling reached. Consider early completion." If progress score < 40 → "Low yield this round. Consider: different search terms, --deep mode, or narrower topic focus."
