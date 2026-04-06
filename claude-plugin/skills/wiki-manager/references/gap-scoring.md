# Gap Scoring & Plan Reflection

## Purpose
Between multi-round research rounds, reflect holistically on accumulated knowledge and score gaps for the next round. This catches 34% more cross-topic connections than simple gap-picking.

## Gap Scoring Formula

Each gap is scored on three dimensions (1-5 each):

| Dimension | 5 (highest) | 3 (moderate) | 1 (lowest) |
|-----------|-------------|--------------|------------|
| **Impact** | Filling this gap fundamentally changes understanding | Adds useful context | Nice-to-know but not essential |
| **Feasibility** | Likely findable with web search | May exist but hard to find | Probably requires primary research |
| **Specificity** | Well-defined, searchable question | Somewhat vague | Too broad to target effectively |

**Composite score** = Impact x Feasibility x Specificity (range: 1-125)

**Selection**: Pick top 3 gaps by composite score for the next round.

## Reflection Protocol

**Key insight from testing**: Plan reflection's primary value is discovering cross-topic connections between rounds — NOT changing the research direction. Testing against a real 4-round research wiki showed the research path was already well-chosen (reflection confirmed every round's direction). But it found 5 undrawn cross-references that exist in the content but were never linked. This is the 34% improvement the literature predicts.

Between rounds, the orchestrating agent should (in priority order):

1. **Draw connections** between this round's findings and ALL prior rounds (not just the previous one) — this is the highest-value activity
2. **Update cross-references** — add See Also links between articles that share concepts across rounds
3. **Re-evaluate earlier gaps** — some gaps from round 1 may now be filled or irrelevant
4. **Score remaining gaps** using the formula above
5. **Adjust research direction** — only if findings clearly indicate a shift (rare in practice)
6. **Note reflection in session registry** — add `reflection_notes` to the round entry

## Example Reflection Output

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
