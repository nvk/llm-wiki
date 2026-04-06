# Progress Metrics

## Purpose
Quantify research quality per round to enable principled termination and low-yield detection.

## Progress Score Formula (0-100)

| Component | Calculation | Max Points |
|-----------|-------------|-----------|
| Sources ingested | count x 3 | 30 |
| Articles created/updated | count x 5 | 30 |
| Cross-references added | count x 2 | max(20, existing_articles x 2) — scales with wiki maturity |
| Average credibility score | avg x 4 | 20 |

**Scaling note**: The cross-reference cap starts at 20 for new wikis and grows as the wiki matures. A wiki with 10 existing articles has a cap of 20; one with 15 articles has a cap of 30. This prevents the component from saturating on Round 1 when the wiki is small, while still rewarding dense cross-linking in mature wikis.

**Interpretation**:
- 0-40: Minimal yield — consider changing strategy
- 41-70: Moderate — research is productive, continue
- 71-90: Strong — good coverage being built
- 91-100: Comprehensive — near-complete coverage

## Termination Decision Tree

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

## Low-Yield Response Options

When progress_score < 40 for two consecutive rounds:
1. Switch to `--deep` mode if not already
2. Try different search angle framing
3. Narrow the topic to a more specific subtopic
4. Report early completion: "Research appears exhausted for this topic"

## Trajectory-Based Triggers

In addition to per-round thresholds, monitor the round-over-round trend:

**Declining trajectory warning**: If 3 consecutive rounds show declining scores totaling 30+ points of cumulative drop (e.g., 98→95→68→58 = -40 total), warn:
> "Research yield is declining across rounds (trajectory: {scores}). Consider: narrowing topic focus, switching to --deep mode, or completing early if core gaps are filled."

**Plateau detection**: If 2 consecutive rounds score within 5 points of each other AND no new high-impact gaps are identified, recommend early completion:
> "Research has plateaued at {score}. No new high-impact gaps found. Early completion recommended."

**Stalled detection**: If any single round scores <20, immediately flag:
> "Round yielded near-zero value. Stop and reassess: is the topic too narrow, the search terms wrong, or the knowledge base already comprehensive?"

## Tracking Across Rounds

In `.research-session.json`, each round records its progress_score. The final report includes:
- Score per round: [65, 72, 45]
- Trajectory: improving / plateauing / declining
- Cumulative: sum of round scores
