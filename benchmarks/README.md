# Token-Efficiency Benchmarks

This suite separates cheap, deterministic context budgets from cost-bearing
model measurements. It is designed to answer two different questions:

1. Did checked-in prompt or skill material get larger?
2. Did a candidate change reduce real Codex or Claude tokens, or the exact Pi
   provider payload sent to local DS4, without reducing answer quality or
   changing the fixture?

## Recommended harness matrix

| Harness | Query preset | Full preset | Quality/accounting gate |
|---------|--------------|-------------|-------------------------|
| Claude Code | `--route command` exercises the real read-only `/wiki:query` command | `--route skill` exercises plugin activation | Reads, citations, no writes, tokens, cache, cost, TTFT |
| Codex | `--profile query` explicitly loads `$wiki-query` | `--profile full` loads `@wiki` | Dynamic fixture reads, citations, no writes, app-server tokens and cache reads |
| Pi / DS4 | `scripts/pi-wiki-query`, or isolated `pi-ds4-wiki-query`, plus `read,grep,find,ls` | generated OpenCode `wiki-manager/SKILL.md` for comparison only | Exact serialized DS4 provider bytes, reads, citations, abstention, no writes |
| OpenCode | generated `wiki-query/SKILL.md` | generated `wiki-manager/SKILL.md` | Static size and sync validation only; live model behavior is best effort |
| Portable agents | `profiles/query-lite/SKILL.md` | root `AGENTS.md` | Static size budgets |

Use query presets for retrieval. Use full presets only when the task needs
research, ingestion, compilation, lint repairs, or another write workflow.

## Layer 1: deterministic budgets

Run on every commit and in CI:

```bash
./scripts/benchmark-token-efficiency static --check
```

The command measures bytes or characters for the portable protocol, Claude,
Codex, OpenCode, and query-lite skills and activation descriptions, Claude
plugin manifest and commands, Codex agent metadata, lazy references, and the
Pi launchers plus DS4 adapter. Baselines and hard ceilings live in
`tests/budgets/token-budgets.json`.

These are context-size proxies, not tokenizer estimates. Provider-specific
measurements come from the live layers below.

## Layer 2: Codex app-server

This command makes real model calls and consumes account quota:

```bash
mkdir -p benchmarks/results
./scripts/benchmark-token-efficiency live \
  --model gpt-5.6-sol \
  --profile query \
  --repeats 2 \
  --output benchmarks/results/current.json
```

The runner:

- starts Codex app-server over JSON-RPC;
- uses an isolated temporary `HOME` and `CODEX_HOME`, copying only `auth.json`
  when file-based auth is available;
- explicitly loads the selected Codex skill from the checkout under test;
- copies the synthetic golden wiki into an ephemeral project;
- disables Codex code mode and injects one deterministic, read-only
  `wiki_fixture_read` dynamic tool;
- requires every cold turn to read fixture evidence;
- records app-server `last` token usage, including input, cached input, output,
  reasoning output, and total tokens;
- records uncached input as `input_tokens - cached_input_tokens`, TTFT, total
  latency, compactions, tool calls, and deterministic quality checks;
- hashes the fixture before and after each run and fails if anything changed.

The controlled read tool prevents local shell configuration, MCP servers,
code-mode helper packaging, and filesystem permissions from becoming hidden
variables in a wiki-quality benchmark.

`--repeats 2` runs the same case twice in one thread. The first turn is the
cold quality/context measurement. The second turn measures warm-thread and
provider-cache behavior; it may reuse evidence already present in the thread.

Use `--profile query` for the production `$wiki-query` path and
`--profile full` for `@wiki`. Do not compare reports from different profiles as
if they were code-only changes; record the profile as part of the experiment.

## Layer 3: Claude Code

Claude Code exposes cache creation, cache reads, cost, TTFT, API duration, and
tool-use events in its stream-json result:

```bash
./scripts/benchmark-token-efficiency claude-live \
  --model claude-sonnet-4-6 \
  --route command \
  --repeats 2 \
  --output benchmarks/results/claude-current.json
```

The Claude runner loads the checkout with `--plugin-dir`, disables user
settings and MCP servers, and requires successful reads from the synthetic
`.wiki`. `--route command` invokes the actual `/wiki:query` command and permits
only `Read`, `Glob`, and `Grep`. `--route skill` tests natural plugin activation
with only `Read` and `Skill`. Each repeat is a fresh Claude Code process so
cache behavior reflects reusable prompt prefixes rather than conversation
history. Claude input accounting is:

```text
total input = input_tokens + cache_creation_input_tokens + cache_read_input_tokens
uncached input = input_tokens + cache_creation_input_tokens
```

The report also records `total_cost_usd`. Local subscription runs are useful
for token and behavior comparisons; CI should use a dedicated
`ANTHROPIC_API_KEY` when billed cost must be reproducible.

For model calibration, run the same cases and route in reverse AB/BA order.
`claude-sonnet-4-6` is the default efficiency gate. Compare it against the
current Opus alias or an explicit resolved ID, for example `claude-opus-4-8`,
without changing the fixture, route, budget, or test window. Model comparisons
are observational and should not replace the fixed-model code-regression gate.

## Layer 4: local DS4 through Pi

The DS4 lane runs Pi in JSON mode against an isolated custom provider config:

```bash
PI_CLI="$(npm root -g)/@mariozechner/pi-coding-agent/dist/cli.js"

./scripts/benchmark-token-efficiency ds4-live \
  --pi-command "node $PI_CLI" \
  --repeats 2 \
  --output benchmarks/results/ds4-lite.json
```

Start the DS4 server first. The default endpoint is
`http://127.0.0.1:8000/v1`; override it with `--base-url` or `DS4_BASE_URL`.
The runner:

- gives Pi a temporary `HOME` and `PI_CODING_AGENT_DIR` with only the DS4
  provider definition;
- eagerly appends the compact `profiles/query-lite/SKILL.md` to the stable
  system-prompt prefix;
- exposes only `read`, `grep`, `find`, and `ls`;
- disables discovered extensions, skills, prompts, themes, and session writes;
- loads the read-only DS4 query adapter and then a passive payload meter;
- records exact serialized provider-request bytes, a clearly labeled
  character-based token estimate, model-reported usage when available, TTFT,
  latency, tool reads, answer quality, and fixture immutability; and
- uses DS4-specific cases for exact path citations and honest abstention.

The DS4 server currently does not return usage in Pi's streaming mode, so
`provider_payload_bytes` is the primary comparable context metric. It is exact
for the serialized requests Pi sends. `provider_payload_estimated_tokens` is a
heuristic (`characters / 3`), not a tokenizer result.

Compare the full wiki-manager instructions against the compact query profile
in AB/BA order:

```bash
./scripts/benchmark-token-efficiency ds4-pair \
  --pi-command "node $PI_CLI" \
  --output-dir benchmarks/results/ds4-paired
```

This sequence is full, lite, lite, full. The comparison gate uses measured
provider payload bytes and also requires every quality, citation, abstention,
read-evidence, and no-mutation check to pass.

For normal interactive Pi use, prefer the generic repo-owned launcher. Use the
DS4 launcher when connecting to the local DS4 endpoint:

```bash
./scripts/pi-wiki-query
./scripts/pi-ds4-wiki-query
```

Both disable extension/skill/prompt/theme discovery, select only read-only
tools, and load the same query profile used by the benchmark. The DS4 variant
also isolates Pi state, creates the provider entry when missing, and loads the
DS4 adapter. Use `--dry-run` to inspect either command without starting Pi.

## Codex paired AB/BA comparison

Use two clean worktrees and the same model, machine, account, and test window:

```bash
./scripts/benchmark-token-efficiency pair \
  --baseline-root /path/to/llm-wiki-baseline \
  --candidate-root /path/to/llm-wiki-candidate \
  --model gpt-5.6-sol \
  --profile query \
  --repeats 2 \
  --output-dir benchmarks/results/paired
```

The sequence is baseline, candidate, candidate, baseline. This reduces simple
ordering bias from transient latency and cache conditions. The aggregate
comparison fails unless:

- both reports are independently valid;
- the backend and selected query/full profile match;
- the case-file and fixture-tree SHA-256 identities match;
- the observed model and turn count match;
- the candidate completes every turn;
- deterministic answer quality is preserved;
- the fixture remains unchanged; and
- uncached input-token regression is at most 2% by default.

Change the final gate only when the experiment has a documented reason:

```bash
--max-input-regression-pct 5
```

## Claude paired AB/BA comparison

```bash
./scripts/benchmark-token-efficiency claude-pair \
  --baseline-root /path/to/llm-wiki-baseline \
  --candidate-root /path/to/llm-wiki-candidate \
  --model claude-sonnet-4-6 \
  --route command \
  --output-dir benchmarks/results/claude-paired
```

Claude comparisons add a 5% cost-regression ceiling by default. Override it
only for a documented experiment. The comparison also rejects reports produced
with different `--route` values:

```bash
--max-cost-regression-pct 10
```

To compare existing reports without rerunning models:

```bash
./scripts/benchmark-token-efficiency compare \
  baseline.json candidate.json --check
```

## Cases and results

- Cases: `benchmarks/cases/wiki-query.jsonl`
- DS4 cases: `benchmarks/cases/ds4-wiki-query.jsonl`
- Optional Morph Compact case: `benchmarks/cases/wiki-query-deep-compact.jsonl`
- Static budgets: `tests/budgets/token-budgets.json`
- Deterministic protocol test: `tests/test-token-benchmarks.sh`
- Local result directory: `benchmarks/results/` (gitignored)

### Optional: Morph Compact token-savings lane

`benchmarks/cases/wiki-query-deep-compact.jsonl` targets a `--deep` query
against `tests/fixtures/golden-wiki/raw/articles/2026-01-04-reliability-patterns-long.md`,
a deliberately long, multi-topic raw source with one required fact
(`pass@k`/`pass^k`) buried among many unrelated reliability-pattern sections
-- real filler for `scripts/morph-compact` to drop. Run it explicitly, since
it is not part of the default `wiki-query.jsonl` case set:

```bash
./scripts/benchmark-token-efficiency claude-live \
  --cases benchmarks/cases/wiki-query-deep-compact.jsonl \
  --claude-command claude --repeats 2 --output compact-on.json
```

**Known limitation**: `tests/fixtures/fake-claude-cli.py` (used by
`tests/test-morph-compact.sh` and the deterministic CI lane) is a scripted
stand-in that picks a canned answer from a keyword in the prompt -- it never
actually reads raw content or shells out to `scripts/morph-compact`, so it
cannot demonstrate a real token reduction. Proving the token-savings claim
requires a real `claude` CLI session (so the agent actually follows the
optional instruction added to `query-lite.md`'s Evidence Rules) with
`MORPH_API_KEY`/`MORPH_API_BASE_URL` pointed at either the real Morph API or
`tests/fixtures/fake-morph-compact-server.py`, run twice (compaction off vs
on) via `claude-pair`, comparing `uncached_input_tokens` between the two
reports. This is the opt-in, real-key-optional lane -- never required for
default CI.

OpenCode intentionally has no model-specific live command in this suite. Its
generated profiles are covered by sync tests and static budgets, while users
may attach any provider/model combination. Add a live lane only after pinning a
specific OpenCode model and endpoint so results are reproducible.

Cases use exact required and forbidden strings rather than another LLM grader.
Add cases when a routing or workflow optimization could change behavior.

## Interpreting cache numbers

For Codex, `cached_input_tokens` is the cache-read count surfaced by app-server;
the protocol does not expose cache writes or billing. For Claude, cache creation
and cache reads are separate and the CLI reports estimated USD cost. Do not
compare latency, cost, or cache ratios across different models, machines,
accounts, or substantially different test windows. For DS4, compare exact
provider payload bytes and quality within the same Pi, adapter, server, model,
and endpoint configuration.
