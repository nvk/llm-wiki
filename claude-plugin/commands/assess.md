---
description: "Assess a local repo against the wiki's research body and the broader market. Gap analysis, opportunities, competitive landscape."
argument-hint: "<repo-path> [--wiki <name>] [--local] [--retardmax]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(find:*), Bash(head:*), WebFetch, WebSearch, Agent
---

## Your task

First, resolve **HUB** by following the protocol in `references/hub-resolution.md` (read config, expand leading `~` only, quote paths with spaces). Then check if a wiki exists by trying to read `HUB/_index.md` (global hub) and `.wiki/_index.md` (local).

Compare a local repository against the wiki's knowledge base and the broader market. Produce a comprehensive gap analysis.

### Resolve wiki location

1. `--wiki <name>` → look up in `HUB/wikis.json`
2. `--local` → `.wiki/` in current directory
3. Otherwise → ask which topic wiki to compare against

If wiki does not exist, stop: "No wiki found. Run `/wiki init <topic>` first."

### Parse $ARGUMENTS

- **repo-path**: Path to the local repository to analyze
- **--wiki <name>**: Which topic wiki to compare against
- **--retardmax**: Skip planning, scan everything, cast wide net on web search
- **--local**: Use project-local wiki

### Compare Protocol

#### Phase 1: Repo Analysis (parallel agents)

Launch 3 agents IN PARALLEL to understand the repo:

| Agent | Focus | What to read |
|-------|-------|-------------|
| **Structure** | What the repo IS — architecture, tech stack, directory layout | README, package.json/requirements.txt, directory tree, config files, CLAUDE.md |
| **Features** | What the repo DOES — capabilities, commands, APIs, skills | Command files, skill files, source code entry points, route handlers, CLI help |
| **Docs** | What the repo CLAIMS — documentation, examples, known limitations | README, docs/, examples/, CHANGELOG, issues if accessible |

Each agent returns a structured summary:
- List of features/capabilities with brief descriptions
- Technologies and dependencies used
- Target audience and use cases
- Known limitations or TODOs mentioned in the code

#### Phase 2: Wiki Knowledge Scan

1. Read the target wiki's `_index.md` and all category indexes
2. Read all wiki articles (or index summaries if many)
3. Build a knowledge map: what concepts, techniques, tools, and practices does the wiki cover?
4. Note confidence levels — high-confidence wiki knowledge is established, low-confidence is frontier

#### Phase 3: Gap Analysis

Compare repo features against wiki knowledge:

**A. Repo implements, wiki covers** — alignment. Note where the repo's implementation matches or differs from what the research says is best practice.

**B. Repo implements, wiki silent** — blind spots in research. The repo does things the wiki hasn't researched yet. These are candidates for `/wiki:research` to fill the gap.

**C. Wiki covers, repo doesn't implement** — opportunities. The research suggests capabilities the repo hasn't built yet. These are feature candidates.

**D. Neither covers** — discovered in Phase 4.

#### Phase 4: Market Scan (parallel agents)

Launch agents IN PARALLEL to find what's out there:

| Agent | Focus |
|-------|-------|
| **Competitors** | Search for similar tools, projects, products in the same space. What features do they have? |
| **Best Practices** | Search for industry best practices, standards, and recommendations the repo should follow. |
| **Emerging** | Search for cutting-edge developments, new techniques, or upcoming changes in the field. |

In `--retardmax` mode, add:

| Agent | Focus |
|-------|-------|
| **Adjacent** | Tools from adjacent fields that solve similar problems differently |
| **Failures** | What has been tried and failed in this space? What to avoid? |

#### Phase 5: Report

Generate a comprehensive comparison report saved to the wiki's `output/` directory.

File: `output/assess-{repo-name}-{YYYY-MM-DD}.md`

```markdown
---
title: "Repo Comparison: {repo-name} vs {wiki-name} Wiki vs Market"
type: comparison
sources: [wiki articles referenced]
generated: YYYY-MM-DD
---

# {repo-name} vs {wiki-name} Knowledge Base vs Market

## Executive Summary
[2-3 paragraph overview of findings]

## Repo Overview
- **What it is**: [one-line]
- **Tech stack**: [list]
- **Key features**: [numbered list with brief descriptions]

## Alignment (Repo + Wiki agree)
| Feature | Repo Implementation | Wiki Research | Notes |
|---------|-------------------|---------------|-------|

## Research Gaps (Repo does it, Wiki doesn't cover it)
| Repo Feature | What's missing from wiki | Suggested research |
|-------------|------------------------|-------------------|

## Opportunities (Wiki knows it, Repo doesn't do it)
| Wiki Knowledge | Potential feature | Priority | Complexity |
|---------------|------------------|----------|-----------|

## Market Gaps (Neither covers, but competitors/market does)
| Capability | Who has it | Relevance | Notes |
|-----------|-----------|-----------|-------|

## Competitive Landscape
| Competitor/Tool | Overlap with repo | Unique features | Weaknesses |
|----------------|------------------|----------------|-----------|

## Emerging Trends
[What's coming that both the repo and wiki should prepare for]

## Recommended Actions
1. **Research**: `/wiki:research "topic"` commands to fill wiki gaps
2. **Build**: Feature candidates ranked by impact and feasibility
3. **Monitor**: Things to watch in the market

## Confidence Notes
[Which findings are high-confidence vs speculative]
```

#### Phase 6: Update Wiki & Log

1. Save report to `output/`
2. Update `output/_index.md`
3. Update master `_index.md`
4. Append to topic `log.md`: `## [YYYY-MM-DD] assess | {repo-name} → N alignments, N research gaps, N opportunities, N market gaps`
5. Append to hub `HUB/log.md`

6. Optionally suggest: specific `/wiki:research` commands for each gap found
