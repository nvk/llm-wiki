# Research Infrastructure

Shared subsystems used by `/wiki:research` (including `--mode thesis`). Consolidated from five separate files (agent-prompts, credibility-scoring, progress-metrics, gap-scoring, session-registry) into one because all five were consumed by exactly the same pipeline and the cross-file navigation was pure noise. Thesis mode was later merged into research (Move 2), so this file now serves one command.

## Agent Prompt Templates

### Why

Well-structured prompts are the #1 predictor of agent success. These templates ensure every research agent receives the same context shape (objective, focus, constraints, return format, quality guide) regardless of which mode spawned it.

### Research Agent Template (Topic Mode)

```
You are a research agent. Your task:

**Objective**: Research "{topic}" from the {Agent Role} angle.
**Focus**: {Role-specific focus}
**Search strategy**: {Strategy from role table}
**Current wiki state**: {Brief summary from Phase 1 — what's already covered}
**Constraints**:
- Run 2-3 WebSearch queries (vary terms)
- WebFetch full content for promising results
- Skip: paywalled, SEO spam, thin, duplicate
- Target 3-5 high-quality sources

**Return format**: For each source:
- Title, URL, quality score (1-5)
- Key findings (3-5 bullets)
- Why ingest (1 sentence)

**Quality scoring**:
- 5: Peer-reviewed, landmark, primary data
- 4: Authoritative blog, official docs, well-sourced report
- 3: Decent coverage, some original insight
- 2: Thin, mostly derivative
- 1: SEO spam, no original content
```

### Research Agent Template (Question Mode)

Same as above but replace objective line:
```
**Objective**: Answer this sub-question: "{sub-question}"
**Deliverable**: Evidence that answers this specific question.
```

### Thesis Agent Template

```
You are investigating: "{thesis}"
Key variables: {variables}
Your lens: {Agent Focus} — {Thesis Lens description}

For each source, evaluate:
- Relevance: direct | indirect | tangential (SKIP tangential)
- Evidence strength: meta-analysis > RCT > cohort > case > opinion > anecdotal
- Direction: supports | opposes | nuances
- Key finding: 1-2 sentences
- Quality: 1-5

Return ranked by (relevance × evidence strength), strongest first.
```

### Retardmax Variants

- All templates: increase to 4-5 searches
- Lower quality threshold: accept 2+ (not 3+)
- Add: "Follow interesting citations and references from pages you find"
- Rabbit Hole agents: "Start with '{topic}', follow the most compelling result, then search for what THAT references. Go deep."

---

## Credibility Scoring (Phase 2b)

### Why

Independent assessment of source credibility before ingestion. Prevents the "fox guarding the henhouse" problem where agents self-rate their own source quality. Credibility scores carry forward into article `confidence:` frontmatter tags during compilation.

### Scoring Rubric

| Signal | Points | How to Detect |
|--------|--------|---------------|
| Peer-reviewed | +2 | DOI present, journal/conference name, PubMed ID, arxiv with venue |
| Recent (<=3 years) | +1 | Publication date check |
| Older (>3 years) | 0 | — |
| Very old (>10 years) | -1 | Unless it's a foundational/landmark paper |
| Known author/institution | +1 | Recognized university, major lab, cited expert |
| Unknown author | 0 | — |
| Potential bias detected | -1 | Industry-sponsored without disclosure, activist org, predatory journal |
| Vendor primary source | -1 | First-party vendor docs or blog about own product (authoritative for facts, but inherent promotional framing) |
| Corroborated by other agents | +1 per agent (max +2) | Multiple agents found similar claims from independent sources |

**Non-stacking rule**: Bias signals do not stack. If a source triggers both "potential bias" and "vendor primary source," apply only the more specific one (-1 total, not -2). These are refinements of the same concern (promotional framing), not independent dimensions.

### Credibility Tiers

| Tier | Score Range | Action | Confidence Tag |
|------|------------|--------|---------------|
| High | 4-6 | Ingest | confidence: high |
| Medium | 2-3 | Ingest | confidence: medium |
| Low | 0-1 | Ingest only if unique angle | confidence: low |
| Reject | <0 | Skip | — |

### Bias Detection Signals

- Industry whitepaper with no independent validation
- Press release disguised as news article
- Predatory journal (check Beall's List indicators: rapid acceptance, broad scope, aggressive solicitation)
- Affiliate/sponsored content without disclosure
- Single-perspective advocacy org
- First-party vendor documentation or engineering blog about own product (authoritative for facts, but inherent promotional framing — e.g., Anthropic writing about Claude Code, LangChain surveying their own users, Factory.ai benchmarking their own compression algorithm)

### Retardmax Mode

Lower rejection threshold — accept Medium and above. Still score everything; scores carry forward into article confidence tags.

---

## Progress Scoring (0-100)

### Why

Quantify research quality per round to enable principled termination and low-yield detection. Without this, multi-round research either runs until the timer expires (wasting tokens on diminishing returns) or stops too early (missing important gaps). The score is the decision signal.

### Formula

| Component | Calculation | Max Points |
|-----------|-------------|-----------|
| Sources ingested | count x 3 | 30 |
| Articles created/updated | count x 5 | 30 |
| Cross-references added | count x 2 | max(20, existing_articles x 2) — scales with wiki maturity |
| Average credibility score | avg x 4 | 20 |

**Scaling note**: The cross-reference cap starts at 20 for new wikis and grows as the wiki matures. A wiki with 10 existing articles has a cap of 20; one with 15 articles has a cap of 30. This prevents the component from saturating on Round 1 when the wiki is small, while still rewarding dense cross-linking in mature wikis.

### Interpretation

- 0-40: Minimal yield — consider changing strategy
- 41-70: Moderate — research is productive, continue
- 71-90: Strong — good coverage being built
- 91-100: Comprehensive — near-complete coverage

### Termination Decision Tree

```
progress_score >= 80?
  |-- YES -> Any high-impact gaps remaining?
  |           |-- YES -> Continue (but note quality is high)
  |           +-- NO  -> Cross-ref density > 60%?
  |                      |-- YES -> RECOMMEND EARLY COMPLETION
  |                      +-- NO  -> One more round focusing on connections
  +-- NO  -> progress_score < 40?
             |-- YES -> LOW YIELD WARNING
             |          -> Suggest: different terms, --deep, narrower topic
             +-- NO  -> Continue normally
```

### Low-Yield Response Options

When progress_score < 40 for two consecutive rounds:
1. Switch to `--deep` mode if not already
2. Try different search angle framing
3. Narrow the topic to a more specific subtopic
4. Report early completion: "Research appears exhausted for this topic"

### Trajectory-Based Triggers

In addition to per-round thresholds, monitor the round-over-round trend:

**Declining trajectory warning**: If 3 consecutive rounds show declining scores totaling 30+ points of cumulative drop (e.g., 98→95→68→58 = -40 total), warn:
> "Research yield is declining across rounds (trajectory: {scores}). Consider: narrowing topic focus, switching to --deep mode, or completing early if core gaps are filled."

**Plateau detection**: If 2 consecutive rounds score within 5 points of each other AND no new high-impact gaps are identified, recommend early completion:
> "Research has plateaued at {score}. No new high-impact gaps found. Early completion recommended."

**Stalled detection**: If any single round scores <20, immediately flag:
> "Round yielded near-zero value. Stop and reassess: is the topic too narrow, the search terms wrong, or the knowledge base already comprehensive?"

---

## Gap Scoring & Reflection

### Why

Between multi-round research rounds, reflect holistically on accumulated knowledge and score gaps for the next round. **Key insight from testing**: plan reflection's primary value is discovering cross-topic connections between rounds — NOT changing the research direction. Testing against a real 4-round research wiki showed the research path was already well-chosen (reflection confirmed every round's direction). But it found 5 undrawn cross-references that exist in the content but were never linked. This is the 34% improvement the literature predicts.

### Gap Scoring Formula

Each gap is scored on three dimensions (1-5 each):

| Dimension | 5 (highest) | 3 (moderate) | 1 (lowest) |
|-----------|-------------|--------------|------------|
| **Impact** | Filling this gap fundamentally changes understanding | Adds useful context | Nice-to-know but not essential |
| **Feasibility** | Likely findable with web search | May exist but hard to find | Probably requires primary research |
| **Specificity** | Well-defined, searchable question | Somewhat vague | Too broad to target effectively |

**Composite score** = Impact x Feasibility x Specificity (range: 1-125)

**Selection**: Pick top 3 gaps by composite score for the next round.

### Reflection Protocol

Between rounds, the orchestrating agent should (in priority order):

1. **Draw connections** between this round's findings and ALL prior rounds (not just the previous one) — this is the highest-value activity
2. **Update cross-references** — add See Also links between articles that share concepts across rounds
3. **Re-evaluate earlier gaps** — some gaps from round 1 may now be filled or irrelevant
4. **Score remaining gaps** using the formula above
5. **Adjust research direction** — only if findings clearly indicate a shift (rare in practice)
6. **Note reflection in session registry** — add `reflection_notes` to the round entry

### Example Reflection Output

```
## Round 2 Reflection

### Cross-Topic Connections Discovered
- Round 1 finding about X connects to Round 2 finding about Y
- This suggests a new gap: "How does X influence Y?"

### Gap Re-Evaluation
- Gap "A" from Round 1: now filled by Round 2 sources (remove)
- Gap "B" from Round 1: still unfilled, upgraded to high-impact (keep)
- New gap "C": emerged from Round 2 findings (add)

### Scored Gaps for Round 3
1. Gap B: Impact 5 x Feasibility 4 x Specificity 5 = 100
2. Gap C: Impact 4 x Feasibility 5 x Specificity 4 = 80
3. Gap D: Impact 3 x Feasibility 3 x Specificity 4 = 36

### Direction Shift
Research initially focused on X but findings consistently point to Y as the more important subtopic. Round 3 should emphasize Y.
```

---

## Session Registry

### Why

Persistent state for multi-round research and thesis sessions, enabling crash recovery and round-to-round continuity. Without this, a crashed `--min-time` session loses all round state and the user has to start over. The file is ephemeral (never committed to git, never indexed), cheap to lose (worst case: user is asked "continue or start fresh?"), but valuable to have.

### Research Session Schema (.research-session.json)

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

### Thesis Session Schema (.thesis-session.json)

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

### Lifecycle

| Event | Action |
|-------|--------|
| --min-time research starts | Create .research-session.json |
| Round N completes | Update rounds_completed, cumulative counts, status |
| Research completes normally | Delete file (data persists in log.md) |
| Session interrupted | File persists with status: "in_progress" |
| Next invocation detects file | Ask: continue or start fresh? |
| File > 7 days old | Structural Guardian warns about stale session |

### Resume Protocol

1. Detect `.research-session.json` or `.thesis-session.json` in wiki root
2. Read file, extract last completed round
3. Ask user: "Found interrupted session (Round N, M sources). Continue or start fresh?"
4. If continue: use round N's gaps/reflection as starting point for round N+1
5. If fresh: delete file, proceed normally

### Notes

- Session files are ephemeral — never commit to git
- Never include in index counts or structural health checks
- One session per wiki at a time (new session overwrites old)

---

## Research Plan Schema

### Why

The `--plan` flag decomposes a research topic into 3-5 independent paths that execute in parallel. The plan is stored in the session registry so it persists across crashes and can be resumed path-by-path. The plan is ephemeral — it lives only in `.research-session.json` and is deleted on completion.

The architectural insight: parallel ingest is safe (each path writes unique raw files with path-prefixed slugs), but parallel compilation is not (multiple agents updating the same `_index.md` and creating overlapping articles). So the pipeline splits: search + ingest run in parallel across paths, then a single sequential compilation pass runs after all paths complete. This gives the compiler full visibility across all paths for better cross-referencing.

### Schema Extension

When `mode: "plan"` is set in `.research-session.json`, the following fields are added:

| Field | Type | Purpose |
|-------|------|---------|
| `mode` | `"plan"` | Distinguishes plan-mode sessions from single-path (`"single"`) |
| `paths` | array | Research paths with scope and execution status |
| `paths[].name` | string | Human-readable path name |
| `paths[].focus` | string | One-line description of what this path investigates |
| `paths[].search_angles` | string[] | 2-3 specific search strategies for this path |
| `paths[].status` | enum | `pending`, `in_progress`, `completed`, `failed` |
| `paths[].sources_ingested` | number | Sources ingested by this path (updated on completion) |
| `paths[].agent_mode` | string | `standard`, `deep`, or `retardmax` (inherited from session flags) |

### Example

```json
{
  "session_id": "2026-04-16-143022",
  "topic": "quantum computing threats to Bitcoin",
  "mode": "plan",
  "start_time": "2026-04-16T14:30:22Z",
  "paths": [
    {
      "name": "Cryptographic foundations",
      "focus": "Shor's algorithm vs ECDLP, key sizes, quantum gate counts",
      "search_angles": ["shor algorithm elliptic curve", "quantum gate count ECDLP", "NIST post-quantum standards"],
      "status": "completed",
      "sources_ingested": 4,
      "agent_mode": "standard"
    },
    {
      "name": "Hardware timeline",
      "focus": "IBM/Google roadmaps, logical qubit milestones, error correction overhead",
      "search_angles": ["IBM quantum roadmap 2026", "logical qubit error correction overhead", "Google Willow scaling"],
      "status": "completed",
      "sources_ingested": 3,
      "agent_mode": "standard"
    },
    {
      "name": "Migration proposals",
      "focus": "BIP proposals, hash-based signatures, precommitment schemes",
      "search_angles": ["bitcoin post-quantum BIP", "hash-based signature bitcoin", "PQC precommitment soft fork"],
      "status": "in_progress",
      "sources_ingested": 0,
      "agent_mode": "standard"
    }
  ],
  "current_round": 1,
  "rounds_completed": [],
  "cumulative_sources": 7,
  "cumulative_articles": 0,
  "status": "in_progress"
}
```

### Resume Protocol (plan mode)

On resume, check `paths[].status`:

- **All `completed`** → skip to compilation (all sources are ingested, just need to compile)
- **Some `pending`** → re-launch only pending paths (completed paths are not repeated)
- **Some `in_progress`** → treat as `pending` (agent died mid-execution; raw files from partial execution are fine — deduplication handles any overlap)
- **Some `failed`** → ask user: "Path '<name>' failed. Retry or skip?"

### File Ownership

Each path prefixes its raw file slugs with the path index to prevent filename collisions between parallel agents:

```
raw/<type>/YYYY-MM-DD-p<N>-<source-slug>.md
```

Where `N` is the 1-indexed path number. Example: `raw/articles/2026-04-16-p2-ibm-quantum-roadmap.md` is a source from path 2.

Index updates are skipped during parallel ingest. The Derived Index Protocol (`indexing.md`) rebuilds them on the next read. This is safe because indexes are derived caches, not source of truth.

### Interaction with Other Flags

| Flag | Behavior with `--plan` |
|------|----------------------|
| `--deep` | Each path-agent launches 8 sub-agents instead of 5 |
| `--retardmax` | Each path-agent launches 10 sub-agents, lower quality threshold |
| `--sources <N>` | Target N sources per path (not total) |
| `--min-time` | Round 1 executes the full plan; subsequent rounds generate new plans targeting remaining gaps |
| `--mode thesis` | Plan decomposes the thesis into evidence paths (supporting, opposing, mechanistic, etc.) |
| `--project <slug>` | All paths tag outputs with the same project |
| `--new-topic` | Creates the topic wiki first, then generates and executes the plan |
