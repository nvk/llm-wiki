# Audit Reference

Umbrella truth-seeking audit for llm-wiki. If `/wiki:librarian` keeps the
`wiki/` layer in check, `/wiki:audit` answers a broader question: can the user
trust the current knowledge and outputs right now?

The audit is allowed to follow the evidence wherever it leads. It starts from
local wiki state, but it does not stop there if the local evidence is weak,
stale, contradictory, or missing. When needed, it re-reads upstream sources,
fetches fresh primary material, and runs targeted research to resolve whether a
claim is supported, weakened, contradicted, or still unresolved.

## Design Principles

1. **Truth over thrift.** Start with the local wiki and its outputs, but spend
   extra search/fetch effort when that is what the truth requires.
2. **One command, many passes.** The user asks for one audit. Internally the
   audit may run librarian, drift, provenance, and research passes.
3. **Read-only on knowledge artifacts.** Audit writes reports under `.audit/`
   and may reuse `.librarian/`, but it does not rewrite wiki or output content
   during a scan.
4. **Adversarial verification.** For material findings, look for both
   corroborating evidence and counter-evidence. Never search only for support.
5. **Explicit unresolved states.** If the evidence does not converge, say so.
   "Unresolved" is better than false confidence.

## Scope

An audit can cover the full artifact graph or a narrower slice:

- Full wiki audit: all relevant wiki articles, outputs, and provenance state
- `--artifact <path>`: one wiki article or one output artifact
- `--project <slug>`: outputs inside `output/projects/<slug>/`
- `--wiki-only`: just the wiki article layer
- `--outputs-only`: just output artifacts and their dependency chains
- `--quick`: local-only audit, skip fresh web research unless absolutely needed

Default scope is the whole topic wiki.

## Pass 1: Wiki Content Pass

The wiki-content pass is owned by the librarian logic.

1. If a fresh `.librarian/scan-results.json` exists and the user did not ask
   for `--fresh`, reuse it.
2. Otherwise run a fresh librarian scan before continuing.
3. Pull forward the wiki-level findings that matter for trust:
   - stale articles
   - low-quality articles
   - low-confidence source chains
   - unsupported or contradictory findings surfaced by deeper passes

The audit should treat librarian as a subsystem, not a competing command.

## Pass 2: Output Dependency and Drift Pass

Audit output artifacts across the full dependency graph, not just
`output -> wiki -> raw`.

### Target artifacts

By default, inspect markdown outputs under `output/` and `output/projects/`,
excluding:

- `_index.md`
- `WHY.md`

If `--artifact <path>` points at a single output, restrict to that file.
If `--project <slug>` is present, restrict to that project folder's markdown
deliverables.

### Checks

For each output artifact:

1. Read frontmatter and capture `sources:`, `generated:`, `project:`, and
   related metadata if present.
2. If `sources:` is missing or empty, flag `missing-provenance`.
3. Resolve each dependency path:
   - `raw/...`, `wiki/...`, `output/...` resolve from the wiki root
   - `../...` resolves relative to the artifact file
4. Flag `broken-source-ref` for any dependency that does not resolve.
5. Compare dependency freshness against the output's `generated:` date:
   - if dependency `updated:` / `ingested:` / `generated:` is newer than the
     output, flag `drifted-dependency`
6. If the dependency is a wiki article, inherit relevant librarian findings:
   - stale upstream article -> `stale-upstream`
   - low-confidence or low-quality upstream -> `weak-upstream`
7. If the dependency is another output artifact, recurse one hop into that
   artifact's own `sources:` field so the audit can keep tracing the chain.

### Output verdicts

Classify each artifact as one of:

- `clean` — provenance resolves and no important upstream drift is found
- `drifted` — upstream evidence changed after the artifact was generated
- `provenance-gap` — missing or broken source chain
- `weak-evidence` — chain resolves but relies on stale, thin, or low-confidence
  upstream material
- `contradicted` — fresh verification found the artifact materially wrong
- `unresolved` — the audit followed the trail, but the truth is still mixed

## Pass 3: Truth Escalation Pass

This is what makes audit broader than librarian. When trust is in doubt, audit
keeps going.

### Escalation triggers

Escalate beyond local files when any of these are true:

- the user explicitly asks whether they can trust an artifact
- an output is drifted or has a provenance gap
- a cited wiki article is stale, weak, or contradictory
- the source chain is thin and the claim matters
- the topic is `volatility: hot`
- there are conflicting local claims that need external resolution

### Research protocol

For each escalated item:

1. Re-read the local artifact and note the specific claims at issue.
2. Re-read or fetch its cited raw sources and wiki dependencies.
3. If a raw source points to a live primary URL, fetch it again when possible.
4. Run targeted research with both supportive and adversarial queries:
   - one query that tries to confirm the current claim
   - one query that tries to break or disprove it
5. Prefer primary sources, official docs, papers, or direct evidence over
   tertiary commentary.
6. If the tool/runtime supports parallel agents, split the work:
   - support branch
   - attack branch
   - optional primary-source branch
7. Stop only when the claim lands in one of the verdict buckets below, or when
   the audit can defend why it remains unresolved.

### Truth verdicts

Each escalated finding should end with one of:

- `supported`
- `weakened`
- `contradicted`
- `unresolved`

The audit should never hide mixed evidence behind a binary label.

## Pass 4: Session Provenance Pass

Check whether the wiki has enough execution history to replay how artifacts were
produced.

### Files to look for

- `.session-events.jsonl`
- `.session-checkpoint.json`
- `.research-session.json`
- `.thesis-session.json`

### Provenance states

- `replayable` — event log exists; session actions can be traced at fine granularity
- `partial` — only session summary/checkpoint files exist
- `missing` — no durable session artifacts exist; provenance is limited to file
  timestamps and frontmatter

This pass is diagnostic, not punitive. Missing event logs should usually be
reported as a limitation, not as a content failure.

Audits should also maintain their own durable provenance:

- append `audit_started`, `audit_output_scan_completed`,
  `audit_truth_escalation_completed`, and `audit_completed` events to
  `.session-events.jsonl`
- refresh `.session-checkpoint.json` with the current scope, verdict counts,
  provenance state, and written report artifact paths

## Report Outputs

Audit writes to `.audit/` in the topic wiki root:

- `.audit/scan-results.json` — machine-readable source of truth
- `.audit/REPORT.md` — human-readable summary
- `.audit/log.md` — append-only audit activity log

The topic wiki's main `log.md` also gets an `audit` entry.

### Recommended JSON shape

```json
{
  "audit_id": "2026-04-29T12:00:00Z",
  "scope": "full",
  "summary": {
    "wiki_findings": 3,
    "outputs_scanned": 8,
    "drifted_outputs": 2,
    "research_escalations": 4,
    "provenance_state": "partial"
  },
  "wiki": {},
  "outputs": {},
  "investigations": [],
  "provenance": {}
}
```

## Command Boundaries

| Command | Role |
|--------|------|
| `lint` | Structural correctness and schema hygiene |
| `refresh` | Re-fetch and compare source changes for wiki articles |
| `librarian` | Focused wiki maintenance and scoring for the `wiki/` layer |
| `audit` | Umbrella trust inspection across wiki articles, outputs, provenance, and fresh research |

If audit finds a stale wiki article, it can recommend or invoke refresh work as
part of the investigation. If it only needs to keep the `wiki/` layer tidy, it
should stay within librarian territory.
