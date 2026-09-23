---
name: wiki
description: >
  Manage LLM-compiled wikis in Codex: ingest/import, shape/promote Ideas,
  review portfolios, track inventory/datasets, archive, compile/query/lint/audit,
  research/plan, manage sessions, private adapters, personal specialists, and outputs.
  Activates when the user mentions wiki workflows, knowledge-base management,
  ingestion, collection ingestion, import wiki, collect, catalog, curate,
  find all, idea, turn idea into project, portfolio, business ideas, projects, inventory, source queue,
  candidate list, watch list, backlog, dataset, large data, data registry,
  dataset manifest, compilation, querying, linting, audit, research, librarian,
  scan quality, article quality, content review, output drift, provenance,
  archive wiki, archive topic, restore wiki, private adapter, adapter registry, skill-factory,
  checkpoints,
  personal specialist, specialist skill, specialist reviewer, expert lens,
  adapter route, adapter doctor, adapter run, edit an external resource, session capture, capture context, rehydrate,
  resume from session, implementation plan, or uses
  /wiki-style shorthand in a repo with .wiki/, ~/wiki/, or a configured hub path.
---

# LLM Wiki Manager

You manage an LLM-compiled knowledge base. Source documents are ingested into `raw/`, then incrementally compiled into a wiki of interconnected markdown articles. Codex is both the compiler and the query engine.

## Codex Plugin Notes

Codex plugins package skills, MCP servers, apps, and metadata. They do not register Claude-style custom `/wiki:*` commands. Treat any `/wiki`, `/wiki:*`, or command-flag examples in this skill and its references as shorthand for the same workflow expressed in natural language, or via explicit `@wiki` invocation.

## Hub Path

**Resolution**: At the start of every operation, resolve **HUB** by reading `${LLM_WIKI_CONFIG_DIR:-~/.config/llm-wiki}/config.json` first. Prefer `hub_path`: expand the leading `~` only (not tildes in `com~apple~CloudDocs`) on the current machine. Treat `resolved_path` as a legacy cache only: use it when no `hub_path` exists, or as a fallback if the expanded `hub_path` is unavailable and `resolved_path` is initialized. Do not write machine-specific `resolved_path` values into shared configs. If no config file exists, try `~/wiki/_index.md` as a fallback. If `stat`/existence checks succeed but reading `wikis.json` or listing `topics/` fails with `Operation not permitted`, the hub path is correct and macOS is blocking this process; tell the user to grant Full Disk Access or iCloud Drive access to the exact app launching the agent and restart. Do not switch to `~/wiki` or `resolved_path` for that error. See [references/hub-resolution.md](references/hub-resolution.md) for the full protocol.

The config file looks like:

```json
{
  "hub_path": "~/Library/Mobile Documents/com~apple~CloudDocs/wiki"
}
```

If no config exists and `~/wiki/` has `_index.md`, that works too. But config is checked first — in sandboxed environments `~/wiki/` may not be accessible. All references to `~/wiki/` below mean HUB.

## Wiki Location

**Topic sub-wikis are the default.** HUB is a hub — content lives in `HUB/topics/<name>/`. Each topic gets isolated indexes, sources, and articles. This keeps queries focused and prevents unrelated topics from polluting each other's search space.

For collection families that will grow across subjects, prefer kind-first topic
slugs such as `memes-bitcoin`, `memes-ethereum`, `tools-bitcoin`, or
`examples-seedqr`. Use subject-first slugs when the subject is the primary
research area and the collection is only one artifact within that topic.

Resolution order:

1. `--local` flag → `.wiki/` in current project
2. `--wiki <name>` flag → named wiki from `HUB/wikis.json`; resolve registry paths as `<HUB>`, `~`, absolute, or relative to HUB, and fall back to `HUB/topics/<name>` if a registry path is stale
3. Current directory has `.wiki/` → use it
4. Otherwise → HUB (the hub)

When a command targets the hub and the hub has no content, suggest creating a topic sub-wiki instead.

See [references/wiki-structure.md](references/wiki-structure.md) for the complete directory layout and all file format conventions.

## Core Principles

1. **Indexes are a derived cache.** The `.md` files and their YAML frontmatter are the source of truth. `_index.md` files are a cached view rebuilt on read when stale. Always read indexes first for navigation — but before trusting one, stale-check it (file count vs row count). See [references/indexing.md](references/indexing.md) for the Derived Index Protocol.

2. **Raw is immutable.** Normal workflows never modify ingested sources. Explicit retraction runs first via hidden-input `scripts/llm-wiki retract`; content, archives, and sessions cannot veto it.

3. **Articles are synthesized, not copied.** A wiki article draws from multiple sources, contextualizes, and connects to other concepts. Think textbook, not clipboard.

4. **Dual-linking for Obsidian + Codex.** Cross-references use both `[[wikilink]]` (for Obsidian graph view) and standard markdown `[text](path)` (for Codex navigation) on the same line: `[[slug|Name]] ([Name](../category/slug.md))`. Bidirectional when it makes sense.

5. **Frontmatter is structured data.** Every `.md` file has YAML frontmatter with title, summary, tags, dates. This makes the wiki searchable without full-text scans.

6. **Incremental over wholesale.** Compilation processes only new sources by default. Full recompilation is expensive and explicit (`--full`).

7. **Honest gaps.** When answering questions, if the wiki doesn't have the answer, say so. Never hallucinate. Suggest what to ingest to fill the gap.

8. **Multi-wiki awareness.** When querying, answer from the primary wiki first. Then peek at sibling wiki indexes (via `HUB/wikis.json`) for relevant overlap. Flag connections but never merge content across wikis.

9. **Chunk large writes.** Never create files longer than ~200 lines in a single Write call — the API stream idles during large generations, causing timeout errors. Write the skeleton (frontmatter + headers + first section) first, then use sequential Edit calls to append remaining sections. For plans, articles, and raw notes: write one section per tool call.

10. **Archive is quiet preservation.** Archived topic wikis live under
`HUB/topics/.archive/<slug>/` and are hidden from normal semantic workflows.
They remain structurally maintainable through explicit archive/lint operations.
Deep queries may surface archived index matches separately, but archived content
must not influence new synthesis unless the user explicitly includes it.

11. **Session capture is operational memory.** Harness session digests live in
`HUB/.sessions/` or `.wiki/.sessions/`, not in topic `raw/` by default.
Automated hooks may capture redacted checkpoints, but promotion into topic wikis
is explicit and user-directed.

12. **Feedback is candidate memory.** User corrections, preferences, approvals,
and plan-acceptance signals may be captured as redacted candidates under
`HUB/.sessions/feedback/`, but generic acknowledgements are ignored and durable
wiki promotion remains explicit.

13. **Private adapters are a content-free external execution plane.** Their
machine-local registry lives under `~/.config/llm-wiki/`, not in the hub.
Adapter repositories contain tool code only; real inputs and all runtime
outputs remain in separately controlled external data planes. Only reviewed
`wiki-safe` candidates may enter the wiki through normal provenance and
compilation workflows. See
[references/adapters.md](references/adapters.md).

14. **Specialists are bounded methods, not credentials.** Personal,
instruction-only specialist packages live locally under `HUB/.skills/` and are
enabled per active topic. Loading one never grants tools, write access, professional
authority, or permission to spawn agents. Select the minimum useful method,
preserve disagreement, and record its version/hash. See
[references/specialists.md](references/specialists.md).

15. **Project checkpoints need comprehensive coverage and a privacy seal.** See
[references/checkpoints.md](references/checkpoints.md).

## Adapter Routing

For an action plus URL, run `adapter route --intent <effect> --resource <url>
--json` before ingestion. On a match, read its adapter-owned guide; provider
steps live there. A URL alone is not write authorization. See
[references/adapters.md](references/adapters.md).

Explicit `wiki skill-factory <request>` selects the registered named adapter;
do not invent a URL route. Run show/doctor and read its guide. It never
activates ambiently, and its external candidates remain disabled; installation,
topic enablement, commit, and publication are separate actions.

## Ambient Behavior

When this skill activates outside of an explicit `@wiki` invocation or `/wiki`-style shorthand:

1. Resolve the hub path (see Hub Path section above), then check if `HUB/_index.md` or `.wiki/_index.md` exists
2. Read the master `_index.md` to assess if the wiki might cover the user's question
3. If relevant content exists → read the relevant articles and answer with citations
4. If no relevant content → answer normally, optionally suggest: "This could be added to your wiki; ask `@wiki` to ingest it."
5. When peeking at sibling wikis, only read their `_index.md` — do not read full articles unless the user asks. Skip archived sibling wikis by default; in deep mode, archived index matches may be reported separately.

When giving any boot, resume, or "where you left off" briefing, start with the
active wiki identity: `<wiki-name> booted from <wiki-root-path>`. Prefer the
`config.md` title; for local `.wiki/` projects, fall back to the parent
directory name; for `HUB/topics/<slug>/`, fall back to the slug. Include this
line even when there is nothing in flight to resume.

If the user asks whether they can trust a wiki artifact, requests an audit,
mentions provenance or drift, or asks for content verification beyond a normal
query, use the Audit workflow instead of treating it as plain Q&A.

## Workflows

Choose the smallest workflow that matches the request, then load only the
reference material you need for that workflow:

- `ingest` and `ingest-collection` → `references/ingestion.md`
- `adapter` and private-adapter execution → `references/adapters.md`
- `collect` → `references/inventory.md` and `references/research-infrastructure.md`
- `inventory` → `references/inventory.md`
- `idea` → `references/ideas.md`
- `dataset` → `references/datasets.md`
- `archive` → `references/archive.md`
- `compile` → `references/compilation.md` and `references/indexing.md`
- `query` → read the relevant `_index.md` files first, then only the articles
  needed to answer
- `lint` → `references/linting.md`
- `audit` → `references/audit.md`
- `research`, `plan`, `output`, `assess` → `references/research-infrastructure.md`
- `project` → `references/projects.md`
- `checkpoint` → `references/checkpoints.md`
- `librarian` → `references/librarian.md`
- wiki structure, indexes, log format, file placement, init → `references/wiki-structure.md`
- hub lookup and path handling → `references/hub-resolution.md`
- session capture, automated hooks, rehydration, promotion → `references/sessions.md`
- feedback curation, corrections, approvals, candidate promotion → `references/feedback.md`

Private adapters are explicitly trusted local executables. Resolve the bundled
`bin/llm-wiki` from the installed plugin root containing this skill; in a source
checkout use `scripts/llm-wiki`. Never clone or update an adapter, store its
registration in the hub, pass unregistered paths, or import outputs
automatically. Verify the manifest/handshake, run a v1 JSON request, keep
`private` and `bulk` artifacts external, and review `wiki-safe` candidates
before any normal wiki write.

Collect requests create bounded catalogs of discoverable things: artifacts,
examples, resources, entities, tools, media, memes, or source candidates. Infer
scale and media policy, record aliases plus `found_in_context` provenance,
deduplicate candidates, write a `type: collection` output at
`output/collect-<slug>-YYYY-MM-DD.md`, then create inventory only when the list
is small and durable enough; otherwise create or suggest one corpus record.
Download and hash bounded public binary media into
`output/assets/collect-<slug>/` by default for media-bearing collections, never
put binaries in `raw/`, and use defensive download settings: timeouts,
file-size caps, content-type checks, and IPv4 retry (`curl -4`) when media
hosts hang on IPv6. Use kind-first topic slugs such as `memes-bitcoin`,
`memes-ethereum`, or `tools-bitcoin` for collection families that can grow
across subjects. Never present "all" as exhaustive beyond the stated strategy
and limit.

Inventory is first-class operational state, not a silo. Ingest, collection, and
collect workflows should suggest inventory when the user wants to track or
decide later.
Dataset manifests should link to inventory records when next actions or
acceptance state matter. Compile and query may surface inventory gaps, but
factual claims still need raw/wiki sources. Collect, research, audit,
librarian, refresh, plan, output, and assess may propose durable follow-ups as
inventory records, but larger pivots should start with a small sample preview.

Ideas live under `inventory/ideas/`. Route fuzzy capture, research, shaping,
and promotion through `references/ideas.md`; require approval, preserve lineage,
and keep delivery truth in the Project.

Keep the first response short and action-oriented. Read deeper references only
after the user intent is clear or a write action is needed.

## Operational Rules

- Use absolute file paths in saved-output messages and markdown links for URLs.
- Append to `log.md` for every wiki write operation; never rewrite old log entries.
- Keep large writes chunked into multiple edits rather than one long generation.
- Read `_index.md` files before broader scans, and treat indexes as derived data.
- Use article `confidence` fields when answering and flag weak sourcing when seen.
- If structure or placement looks wrong, use the `lint --fix` workflow from
  `references/linting.md` instead of inventing a one-off repair path.

