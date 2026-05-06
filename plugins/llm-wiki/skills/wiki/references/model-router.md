# Experimental Model Router

The model router is an optional sidecar for calling local or OpenAI-compatible
model endpoints from llm-wiki workflows. It is disabled by default. Normal wiki
behavior must not change unless the user explicitly enables it.

## Activation

Only use this workflow when one of these is true:

- The user explicitly asks to use the model router or multi-model local stack.
- `LLM_WIKI_MODEL_ROUTER=1` is present in the environment.
- A command or workflow explicitly includes `--experimental-model-router`.

If none of those are true, ignore this reference and use the normal wiki
workflow.

## Configuration

Runtime config is local machine state, not wiki content. Prefer this precedence:

1. Command flag: `--model-router-config <path>`
2. `LLM_WIKI_MODEL_ROUTER_CONFIG`
3. Active topic: `<topic>/.runtime/model-router.yaml`
4. Hub default: `<hub>/.runtime/model-router.yaml`
5. User default: `~/.config/llm-wiki/model-router.yaml`

Do not write endpoints, API keys, or LAN hostnames into `config.md`, `raw/`,
compiled `wiki/` articles, or normal output artifacts. `.runtime/` directories
are operational state and should be ignored by indexes, lint, and compilation.

## Roles

Use roles, not hardcoded model names, from wiki workflows:

```yaml
models:
  synthesize:
    model: qwen3.6-35b-a3b
    endpoint: http://m5-max:11434/v1
    use_for: [query, research_summary, source_synthesis, planning]

  compiler:
    model: qwen3-coder-next
    endpoint: http://spark:8000/v1
    use_for: [compile, article_update, frontmatter, crosslinks, indexes]

  embed:
    model: qwen3-embedding-8b
    endpoint: http://spark:8081/v1
    use_for: [search, dedup, source_recall, article_similarity]

  rerank:
    model: qwen3-reranker-8b
    endpoint: http://spark:8082/v1
    use_for: [claim_support, source_ordering, contamination_control]

  critic:
    model: qwen3.6-35b-a3b
    endpoint: http://m5-max:11434/v1
    use_for: [verify_article, find_unsupported_claims, staleness_check]
```

## Command Wiring

### Query

```text
embed query
-> retrieve raw/wiki candidates
-> rerank
-> synthesize answer with citations
```

Query is the first experiment because it can stay read-only.

### Compile

```text
embed source/article candidates
-> rerank support docs
-> compiler drafts an article/update proposal
-> critic checks source support
-> orchestrator applies edits
```

The compiler model returns a proposal. The orchestrating agent owns every file
write, index update, log append, and checkpoint update.

### Research

```text
orchestrator collects sources
-> synthesize summaries and gaps
-> embed/rerank against existing wiki
-> compiler proposes raw notes or outputs
-> critic pass before durable writes
```

### Librarian / Audit

```text
extract claims
-> retrieve supporting sources
-> rerank
-> critic labels supported / weak / contradicted / stale
```

## Write Barrier

Model workers must not edit files directly. They return JSON or markdown
proposals. The orchestrator validates paths, citations, and ownership before
writing anything.

Preferred proposal shape:

```yaml
role: compiler
model: qwen3-coder-next
target_files:
  - wiki/topics/example.md
proposal_type: patch
citations:
  - raw/articles/source.md
unsupported_claims: []
confidence: medium
```

Reject or revise a proposal when:

- It targets files outside the active wiki.
- It cites sources that do not exist.
- It contains unsupported durable claims.
- It would overwrite unrelated user edits.
- It tries to edit generated indexes without also updating source files, unless
  the workflow is explicitly rebuilding derived indexes.

## Logging

When the router is active, append model provenance to `.session-events.jsonl`:

```json
{"phase":"router","role":"synthesize","model":"qwen3.6-35b-a3b","endpoint":"http://m5-max:11434/v1","input_artifacts":["raw/articles/a.md"],"output_artifacts":["output/experiments/query.json"]}
```

Do not log prompts containing secrets or full private documents unless the user
explicitly asked for that provenance detail. Prefer artifact ids and file paths.

## Packaging

The package may ship:

- This reference document.
- `examples/model-router.yaml` with placeholder endpoints only.
- `scripts/wiki-router`, a small OpenAI-compatible helper.
- Tests that validate disabled/default behavior and config parsing.

The package must not ship real endpoints, API keys, personal LAN hostnames, or
machine-specific runtime config.

## First Safe Experiment

Use read-only query shadow mode:

```text
normal wiki query
parallel router query: embed -> rerank -> synthesize
save comparison under output/experiments/
do not modify raw/wiki/index/log files except the explicit experiment output
```

After that works, test compile proposal mode:

```text
compiler proposal -> critic review -> human/orchestrator applies patch
```

## Guardrails

- Router is opt-in and disabled by default.
- Worker models return proposals; orchestrator writes.
- Retrieval/reranking should precede durable claims.
- Use a critic pass before compilation writes.
- Keep cloud fallback for high-stakes audits and disputed claims.
- Do not let router config become wiki knowledge.

