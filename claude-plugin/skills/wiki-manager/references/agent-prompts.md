# Agent Prompt Templates

## Purpose
Standardized prompt structures for research agents. Well-structured prompts are the #1 predictor of agent success.

## Research Agent Template (Topic Mode)

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

## Research Agent Template (Question Mode)

Same as above but replace objective line:
```
**Objective**: Answer this sub-question: "{sub-question}"
**Deliverable**: Evidence that answers this specific question.
```

## Thesis Agent Template

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

## Retardmax Variants
- All templates: increase to 4-5 searches
- Lower quality threshold: accept 2+ (not 3+)
- Add: "Follow interesting citations and references from pages you find"
- Rabbit Hole agents: "Start with '{topic}', follow the most compelling result, then search for what THAT references. Go deep."
