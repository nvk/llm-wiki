---
description: "Thesis-driven research. Provide a specific claim or hypothesis — agents research evidence for and against, compile a focused wiki, and deliver a verdict. The thesis is the scope constraint — no bloat."
argument-hint: "<thesis statement> [--min-time <duration>] [--deep] [--retardmax] [--wiki <name>]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(mkdir:*), WebFetch, WebSearch, Agent
---

## Your task

Research a specific thesis (claim, hypothesis, or question). Unlike open-ended research, everything is filtered through the lens of this thesis. Sources that don't relate to the claim don't get ingested.

### Parse $ARGUMENTS

- **thesis**: The claim or hypothesis to investigate — everything that is not a flag. Should be a specific, testable statement.
- **--min-time <duration>**: Keep researching in rounds (`30m`, `1h`, `2h`, `4h`). Default: single round.
- **--deep**: 8 parallel agents per round
- **--retardmax**: 10 agents, aggressive ingestion, skip planning
- **--wiki <name>**: Add thesis research to an existing topic wiki instead of creating a new one

### Phase 0: Parse the Thesis

Before any research, decompose the thesis into:

1. **Core claim**: The central assertion in one sentence
2. **Key variables**: The specific things being connected (e.g., "sunlight exposure", "CAA progression", "vitamin D")
3. **Testable prediction**: What would be true if the thesis is correct?
4. **Falsification criteria**: What evidence would disprove it?
5. **Scope boundary**: What is NOT part of this thesis? (This is the bloat filter — if a source doesn't touch these variables, skip it.)

Present this decomposition to the user for confirmation before proceeding.

### Phase 1: Wiki Setup

**If `--wiki` is set**: Use the existing topic wiki. Create a `theses/` subdirectory if it doesn't exist. The thesis research lives there alongside the wiki's regular articles.

**If `--wiki` is NOT set**: Create a new topic wiki. First, resolve **HUB** by following the protocol in `references/hub-resolution.md` (read config, expand leading `~` only, quote paths with spaces).
1. Derive slug from the thesis (e.g., "sunlight reduces CAA independent of vitamin D" → `sunlight-caa-vitamin-d`)
2. Create `HUB/topics/<slug>/` with full wiki structure
3. Register in `HUB/wikis.json`, update hub `_index.md`
4. Set `config.md` description to the thesis statement

In both cases, create a thesis file at `wiki/theses/<slug>.md`:

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
<one sentence>

## Key Variables
- **Variable 1**: definition and relevance
- **Variable 2**: definition and relevance

## Testable Prediction
<what would be true if correct>

## Falsification Criteria
<what evidence would disprove it>

## Evidence For
(populated during research)

## Evidence Against
(populated during research)

## Nuances & Caveats
(populated during research)

## Verdict
**Status**: Investigating
(updated after research completes)
```

### Phase 2: Thesis-Directed Research

Launch parallel agents, but each agent has the thesis as a FILTER. Every source must be evaluated against the claim.

**Standard (5 agents):**

| Agent | Focus | Thesis Lens |
|-------|-------|-------------|
| **Supporting** | Find evidence that supports the thesis | Search for studies, data, mechanisms that confirm the claim. Prioritize strongest evidence. |
| **Opposing** | Find evidence that contradicts the thesis | Search for counter-evidence, failed replications, alternative explanations. Be thorough — steelman the opposition. |
| **Mechanistic** | Find explanations of HOW/WHY the thesis could be true or false | Search for underlying mechanisms, pathways, causal chains connecting the variables. |
| **Meta/Review** | Find meta-analyses, systematic reviews, expert consensus | Search for reviews that aggregate evidence on this specific question. These carry the most weight. |
| **Adjacent** | Find related findings that nuance the thesis | Search for edge cases, moderating variables, conditions under which the thesis holds or fails. |

**Deep (8 agents)** — adds:

| Agent | Focus | Thesis Lens |
|-------|-------|-------------|
| **Historical** | How has thinking on this evolved? | Track the history of this claim — who proposed it, what evidence changed the consensus. |
| **Quantitative** | What are the numbers? | Find effect sizes, confidence intervals, sample sizes, dose-response data. |
| **Confounders** | What else could explain the relationship? | Actively search for confounding variables that could make a spurious correlation look causal. |

**Retardmax (10 agents)** — adds rabbit hole agents that chase citations.

**Each agent must:**
- Run 2-3 searches focused on their specific angle
- For each source, evaluate: **Does this relate to the thesis?** If not → skip. This is the bloat filter.
- Rate relevance to thesis: direct (mentions the specific claim), indirect (related mechanisms), or tangential (skip)
- Rate evidence strength: meta-analysis > RCT > cohort > case study > expert opinion > anecdotal
- Return: title, URL, content, relevance rating, evidence strength, and whether it supports/opposes/nuances the thesis

#### Thesis Agent Prompt Template

Each thesis agent receives this structured prompt:
```
You are a thesis research agent investigating: "{thesis}"
Key variables: {variables}
Your lens: {Agent Focus} — {Thesis Lens}

Search for evidence that is {supporting/opposing/mechanistic/meta-review/adjacent} to this claim.

For each source:
- Relevance to thesis: direct | indirect | tangential (SKIP tangential — this is the bloat filter)
- Evidence strength: meta-analysis > RCT > cohort > case study > expert opinion > anecdotal
- Direction: supports | opposes | nuances
- Key finding: 1-2 sentences
- Quality score: 1-5

Return sources ranked by (relevance × evidence strength), strongest first.
```

### Phase 3: Evidence Compilation

Different from regular compilation — articles are organized around the thesis, not just by topic.

1. **Credibility Review**: Before ingestion, score each source on peer-review status, evidence strength tier (meta > RCT > cohort > case > opinion > anecdotal), author authority, and potential bias. Flag low-credibility sources. In the thesis file's Evidence sections, organize by evidence strength (strongest first) and mark each finding as "Strong" / "Moderate" / "Weak" based on combined credibility + evidence strength.

1. **Ingest** relevant sources to `raw/` (skip tangential sources — this is how we prevent bloat)

2. **Compile wiki articles** as normal (concepts, topics, references) following compilation protocol. But each article's abstract should note its relationship to the thesis.

3. **Update the thesis file** (`wiki/theses/<slug>.md`):
   - **Evidence For**: list each supporting finding with source, strength, and one-line summary
   - **Evidence Against**: list each opposing finding with source, strength, and one-line summary
   - **Nuances & Caveats**: conditions, moderators, edge cases
   - Sort by evidence strength (meta-analyses first)

4. **Cross-reference with existing wiki knowledge**: Read sibling wiki `_index.md` files. If existing articles in other topic wikis are relevant to the thesis, link to them in the thesis file — don't duplicate.

### Phase 4: Verdict

After all research rounds complete, assess the thesis:

```markdown
## Verdict

**Status**: Supported | Partially Supported | Insufficient Evidence | Contradicted | Mixed

**Confidence**: High | Medium | Low

**Summary**: 2-3 sentences on what the evidence shows.

**Strongest supporting evidence**:
1. [Study/source] — finding (evidence strength: X)

**Strongest opposing evidence**:
1. [Study/source] — finding (evidence strength: X)

**Key caveats**:
- caveat 1
- caveat 2

**What would change this verdict**:
- If [specific finding] were discovered, verdict would shift to [X]

**Suggested follow-up theses**:
- "More specific sub-claim derived from findings"
- "Related question surfaced during research"
```

Update the thesis file frontmatter:
```yaml
status: completed
verdict: supported|partially-supported|insufficient|contradicted|mixed
confidence: high|medium|low
```

### Phase 5: Report & Log

1. Append to topic `log.md`: `## [YYYY-MM-DD] thesis | "<thesis>" → verdict: X (confidence: Y), N sources, M articles`
2. Append to hub `HUB/log.md`: same

3. Report:
   - **Thesis**: the claim
   - **Verdict**: status + confidence
   - **Evidence summary**: N supporting, N opposing, N nuancing
   - **Sources**: N ingested, N skipped as irrelevant (this is the bloat metric — higher skip rate = tighter focus)
   - **Articles created/updated**: list
   - **Cross-wiki links**: connections to existing topic wikis
   - **Follow-up theses**: derived from findings
   - **Time spent**: per round and total (if --min-time)

### Multi-Round Thesis Research (`--min-time`)

When `--min-time` is set, rounds work differently from open research:

- **Round 1**: Broad evidence gathering — supporting + opposing + mechanistic
- **Round 2**: Drill into the WEAKEST side of the evidence. If Round 1 found mostly supporting evidence, Round 2 focuses harder on finding counter-evidence (and vice versa). This prevents confirmation bias.
- **Round 3+**: Follow up on specific sub-questions, confounders, or moderating variables that earlier rounds surfaced
- **Final**: Synthesize verdict, update thesis file, lint, generate thesis report

The goal is not just "more sources" — it's a more BALANCED and RIGOROUS assessment with each round.

#### Thesis Session State

When `--min-time` is set, create `<wiki-root>/.thesis-session.json` tracking:
- Round number, evidence for/against counts, current verdict direction
- Same lifecycle as research sessions: create → update per round → delete on completion
- Resume detection: "Found interrupted thesis session (Round N, current leaning: X). Continue?"
