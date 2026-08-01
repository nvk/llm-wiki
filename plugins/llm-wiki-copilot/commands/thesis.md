---
description: "Deprecated — use /wiki:research --mode thesis instead. Thesis-driven research with for/against evidence framing and verdicts."
argument-hint: "<thesis statement> [--min-time <duration>] [--deep] [--retardmax] [--wiki <name>]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(mkdir:*), WebFetch, WebSearch, Agent
---

## Deprecated

This command has been merged into `/wiki:research --mode thesis "<claim>"`. The thesis-specific logic (Phase 0 decomposition, for/against agent framing, evidence compilation, verdict rendering, anti-confirmation-bias Round 2) now lives as a mode inside research.md, sharing the same infrastructure (agents, credibility scoring, session registry, multi-round --min-time) without duplication.

**For backward compatibility**, this shim executes the same logic:

1. Read `commands/research.md` and follow it with `--mode thesis` prepended to `$ARGUMENTS`
2. All flags (`--min-time`, `--deep`, `--retardmax`, `--wiki`) pass through unchanged
3. The input (everything that is not a flag) becomes the thesis claim

**Migration**: replace `/wiki:thesis "<claim>"` with `/wiki:research --mode thesis "<claim>"` in any saved workflows or documentation. This shim will be removed in a future release.
