---
description: "Bulk-ingest source collections such as Git doc repos, MediaWiki sources, CSV/JSON message archives, and Wayback CDX snapshots into raw sources."
argument-hint: "<repo-url|repo-path|mediawiki-url|dump.xml[.bz2|.gz]|csv-json-path|cdx-url|archived-url> [--adapter auto|git|mediawiki-dump|mediawiki-api|csv-messages|wayback-cdx] [--wiki <name>] [--local] [--new-topic <name>] [--limit <N>] [--namespace <id>] [--include <pattern>] [--exclude <pattern>] [--from YYYYMMDD] [--to YYYYMMDD] [--dry-run] [--compile]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(mkdir:*), Bash(mv:*), Bash(cp:*), Bash(rm:*), Bash(basename:*), Bash(find:*), Bash(git:*), Bash(curl:*), Bash(python3:*), Bash(bunzip2:*), Bash(gunzip:*)
---

## Your task

Bulk-ingest a collection into the wiki as immutable raw sources. A collection is a bounded upstream corpus, not a single article: a Git repository full of specs, a BIP repository, a MediaWiki XML dump/API site, a CSV/JSON message archive, or a Wayback CDX snapshot set. Do **not** compile one wiki article per upstream page by default. First preserve raw sources with provenance, then compile synthesized topic/concept/reference articles.

**Resolve the wiki.** Follow the same resolution flow as `/wiki:ingest`:
1. Read `$HOME/.config/llm-wiki/config.json`. If it has `resolved_path` → HUB = that value. If only `hub_path`, expand leading `~` only, set HUB, and write `resolved_path` back.
2. If no config → read `$HOME/wiki/_index.md`. If it exists → HUB = `$HOME/wiki`. If nothing found, ask the user where to create the wiki.
3. Wiki location, first match: `--local` → `.wiki/`; `--wiki <name>` → `HUB/wikis.json`; current directory has `.wiki/` → use it; else → HUB.
4. If `<wiki>/_index.md` is missing and `--new-topic <name>` is set, create the topic wiki using the init protocol before ingesting. If no wiki exists and no `--new-topic`, stop and ask for a target wiki.

Read `skills/wiki-manager/references/ingestion.md` and `skills/wiki-manager/references/wiki-structure.md`, then follow the collection ingestion protocol.

## Parse arguments

- **Source**: repo URL/path, MediaWiki site URL, dump file/URL, CSV/TSV/JSON/JSONL path/URL, CDX API URL, or original URL to query through the Wayback CDX API.
- **--adapter**: `auto` default. Supported: `git`, `mediawiki-dump`, `mediawiki-api`, `csv-messages`, `wayback-cdx`.
- **--limit <N>**: maximum child sources to ingest. Useful for API imports and dry runs.
- **--namespace <id>**: MediaWiki namespace. Default `0`.
- **--include <pattern> / --exclude <pattern>**: filter upstream paths, page titles, message fields, or original snapshot URLs. Treat as shell globs for Git paths and regex for MediaWiki titles, message text, and Wayback original URLs unless the user specifies otherwise.
- **--from YYYYMMDD / --to YYYYMMDD**: bound Wayback CDX capture timestamps.
- **--dry-run**: list what would be ingested, write nothing.
- **--compile**: after raw ingestion, run the normal compile workflow with collection-aware clustering.

## Adapter detection

Use `--adapter` if supplied. Otherwise:

1. Source ending in `.xml`, `.xml.bz2`, or `.xml.gz` → `mediawiki-dump`.
2. Source contains `github.com/`, `gitlab.com/`, ends in `.git`, or is a local directory with `.git/` → `git`.
3. Source ending in `.csv`, `.tsv`, `.json`, or `.jsonl` with message-like fields, or user asks for per-message markdown → `csv-messages`.
4. Source contains `web.archive.org/cdx`, user says "Wayback"/"CDX", or source is an original URL plus snapshot/archive intent → `wayback-cdx`.
5. Source URL contains `/wiki/`, `/w/`, or has a reachable `api.php` endpoint → `mediawiki-api`.
6. If still ambiguous, ask the user to choose `git`, `mediawiki-dump`, `mediawiki-api`, `csv-messages`, or `wayback-cdx`.

Never recursively crawl HTML pages as a collection import. Use structured upstream APIs, repository files, official dumps, dataset rows, or CDX inventories.

## Shared collection flow

1. Derive a stable collection slug from the upstream name, e.g. `bitcoin-bips`, `bitcoin-wiki`.
2. Fetch an inventory of candidate items with stable upstream IDs and revision markers.
3. Apply filters and `--limit`.
4. If more than 500 child sources would be written and the user did not explicitly provide `--limit`, show the count and ask for confirmation before writing.
5. For each child item, skip it if a raw source already has the same `collection`, `upstream_id`, and `revision`/`sha`. If the upstream item changed, write a new immutable raw source; do not overwrite the old one.
6. Write one manifest source to `raw/repos/` with `tags: [collection, collection-manifest, <adapter>]`.
7. Write child sources to `raw/articles/` unless the adapter-specific rule says otherwise. `csv-messages` usually writes children to `raw/notes/`.
8. Rebuild affected raw indexes from frontmatter after the batch. Do not hand-edit hundreds of table rows one by one.
9. Append to `log.md`:
   ```
   ## [YYYY-MM-DD] ingest-collection | <collection> via <adapter>: N new, M skipped, K total candidates
   ```
10. Report the manifest path, counts, skipped duplicates, filters, and next compile suggestion.

## Raw frontmatter

Manifest source:

```yaml
---
title: "Collection: <name>"
source: "<upstream URL or path>"
type: repos
ingested: YYYY-MM-DD
tags: [collection, collection-manifest, <adapter>]
summary: "Manifest for a collection ingest of <name>: N child sources captured from <revision>."
collection: "<collection-slug>"
adapter: git|mediawiki-dump|mediawiki-api|csv-messages|wayback-cdx
revision: "<commit sha, dump filename/date, API snapshot timestamp, dataset hash, or CDX query timestamp>"
canonical_url: "<canonical upstream URL>"
license: "<detected license or unknown>"
---
```

Child source:

```yaml
---
title: "<upstream title>"
source: "<canonical upstream URL or file path>"
type: articles
ingested: YYYY-MM-DD
tags: [collection, <collection-slug>, ...]
summary: "2-3 sentence factual summary."
collection: "<collection-slug>"
adapter: git|mediawiki-dump|mediawiki-api|csv-messages|wayback-cdx
upstream_id: "<path, page id, message id, capture timestamp, or title>"
upstream_type: git-file|mediawiki-page|message-row|wayback-snapshot
revision: "<revision id, timestamp, or commit sha>"
sha: "<blob sha or content hash when available>"
canonical_url: "<per-item URL>"
content_format: markdown|mediawiki|wikitext|text|csv|tsv|json|jsonl|html
license: "<detected license or unknown>"
authors: [optional names]
categories: [optional upstream categories]
outlinks: [optional upstream links]
fetched: YYYY-MM-DD
---
```

Keep the full upstream text in the body, preserving tables, code blocks, proposal metadata, and references as much as possible. Do not summarize away normative requirements in specs.

## Git adapter

Use a shallow clone for remote repositories unless the user provides a local path:

```bash
git clone --depth 1 <url> <tmpdir>
git -C <tmpdir> rev-parse HEAD
git -C <tmpdir> ls-tree -r --format='%(objectname) %(path)' HEAD
```

Candidate files:
- Include text-like source files: `.md`, `.mediawiki`, `.wiki`, `.rst`, `.txt`, `.adoc`.
- Exclude `.git/`, `.github/`, generated assets, binaries, images, archives, vendored dependencies, scripts, and test vectors by default.
- For BIP-style repositories, prioritize root-level `bip-####.mediawiki` and `bip-####.md` files; treat sibling images/test vectors as referenced assets, not primary raw sources unless the user includes them.

For each file:
- `upstream_id`: repository-relative path.
- `revision`: HEAD commit SHA.
- `sha`: Git blob SHA.
- `canonical_url`: GitHub/GitLab blob URL pinned to the commit when possible.
- Parse proposal headers when present, especially `BIP`, `Layer`, `Title`, `Authors`, `Status`, `Type`, `Requires`, `License`, and `Discussion`.

For `bitcoin/bips`, classify the collection manifest as `raw/repos/` and each BIP proposal as `raw/articles/`. During later compile, prefer synthesized articles around concepts and standards clusters rather than one compiled article per BIP.

## MediaWiki dump adapter

Use official XML dumps when available. They are better than crawling and carry revision metadata.

1. Download or read the dump file.
2. Decompress with `bunzip2 -c` or `gunzip -c` when needed.
3. Parse streaming XML with Python stdlib `xml.etree.ElementTree.iterparse` to avoid loading the whole dump into memory.
4. Default to namespace `0`. Skip redirects, talk/user/file/special pages, and pages whose title contains `:` unless `--namespace` or filters explicitly include them.
5. For each page:
   - `upstream_id`: page id if present, else title.
   - `revision`: revision id and timestamp.
   - `canonical_url`: site URL plus normalized title when derivable.
   - `content_format`: `wikitext`.
   - Preserve the latest revision text in the body.

If the dump has many pages, write in batches and rebuild indexes at the end.

## MediaWiki API adapter

Use the API for targeted imports or when dumps are unavailable.

1. Discover `api.php` from the source URL. Common forms:
   - `https://example.org/w/api.php`
   - `https://example.org/wiki/api.php`
2. Fetch page inventory with:
   ```
   action=query&list=allpages&apnamespace=<namespace>&aplimit=max&format=json
   ```
   Follow `continue` until done or `--limit` is reached.
3. Fetch content in batches with `prop=revisions` and `rvslots=main&rvprop=ids|timestamp|user|comment|content`.
4. Optionally fetch `categories` and `links` for provenance and later graph compilation.
5. Respect rate limits. If the API throttles, slow down and continue; do not fall back to HTML crawling.

## CSV/JSON messages adapter

Use `csv-messages` for bounded exports where each CSV/TSV row, JSON array item,
or JSONL line is a message, post, email, transcript item, or similar record.
Examples include Cypherpunks-style mailing-list CSVs and message-like JSON
exports.

1. Read local files directly or download URL sources to a temporary file.
2. Parse `.csv`, `.tsv`, `.json`, and `.jsonl` with Python stdlib. Do not split
   arbitrary nested JSON unless the user identifies the message array path.
3. Infer fields conservatively:
   - id: `id`, `message_id`, `Message-ID`, `url`, or stable row number.
   - date: `date`, `created_at`, `timestamp`, `sent`, or `time`.
   - author: `author`, `from`, `sender`, `name`, or `handle`.
   - subject/title: `subject`, `title`, or first non-empty text fragment.
   - body: `body`, `text`, `content`, `message`, `plain`, or `markdown`.
4. In `--dry-run`, report row count, detected columns/keys, inferred mapping,
   and a few representative titles without writing.
5. If body field detection is ambiguous, ask before writing. If stable ids are
   missing, use row number plus content hash as `upstream_id`.
6. Write the manifest to `raw/repos/` and children to `raw/notes/` unless the
   dataset is explicitly articles/formal documents.
7. Preserve per-record provenance in frontmatter where known: `row_number`,
   `message_id`, `author`, `date`, `subject`, `dataset_sha`, and
   `source_columns`.

## Wayback CDX adapter

Use `wayback-cdx` for bounded archived web captures. The CDX result set is the
inventory; never recursively crawl live or archived HTML.

1. Accept either a CDX API URL or an original URL/prefix. For original URLs,
   query `https://web.archive.org/cdx` with JSON output and
   `fl=timestamp,original,statuscode,mimetype,digest,length`.
2. Use `filter=statuscode:200` and `collapse=digest` by default. Apply
   `--from`, `--to`, `--include`, `--exclude`, and `--limit`.
3. Fetch captures with the `id_` replay form:
   `https://web.archive.org/web/<timestamp>id_/<original-url>`.
4. Convert HTML to markdown with readability. Prefer a temporary Python venv
   using `readability-lxml` plus `markdownify` or `html2text`. If dependency
   installation is unavailable, use WebFetch with an extraction prompt and
   record that fallback in `extraction_tool`.
5. Write the manifest to `raw/repos/` and children to `raw/articles/`.
6. Preserve snapshot provenance in frontmatter: `wayback_timestamp`,
   `wayback_original`, `wayback_digest`, `statuscode`, `mimetype`, `length`,
   `canonical_url`, and `extraction_tool`.
7. Skip binary, empty, duplicate, or mostly-navigation captures; report skip
   counts by reason.

## Compile guidance

If `--compile` is set, run normal compilation after ingestion with these collection-specific rules:

- Use the collection manifest to understand scope, but do not require compiled articles to cite the manifest.
- Compile clusters into useful wiki articles: concepts, standards families, timelines, glossary/reference indexes, and thesis files when a claim is being tested.
- For BIPs, likely clusters include activation mechanisms, wallet standards, script upgrades, peer services, Taproot/Schnorr, mining/RPC, and the BIP process.
- For community wikis, treat pages as explanatory sources with medium confidence unless corroborated by authoritative specs, code, papers, or multiple independent sources.
- Preserve confidence nuance: a BIP being published means it met repository process criteria; it does not by itself prove adoption, consensus, or desirability.

## Report format

End with:

- Adapter and collection slug.
- Manifest path.
- New/skipped/error counts.
- Filters and namespace used.
- Top 10 child sources by title/path.
- Whether compile was run or the exact suggested next command.
