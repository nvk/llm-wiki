# Ingestion Protocol

## Overview

Ingestion converts external material into a standardized raw source file in the wiki's `raw/` directory. Sources are immutable after ingestion.

## Source Types

| Type | Directory | Auto-detect signals |
|------|-----------|-------------------|
| articles | raw/articles/ | General web URLs, blog posts |
| papers | raw/papers/ | arxiv.org, scholar.google, .pdf URLs/files, academic language |
| repos | raw/repos/ | github.com, gitlab.com URLs |
| notes | raw/notes/ | Freeform text, tweets, no URL |
| data | raw/data/ | .csv, .json, .tsv URLs or files, dataset references |

## Collection Ingestion

Collection ingestion is for bounded upstream corpora: Git document repositories,
BIP-style proposal sets, MediaWiki XML dumps/API sites, message archives, and
Wayback CDX snapshot sets. Treat these as **source collections**, not as
compiled wiki content. The ingest step preserves raw sources and provenance;
the compile step later synthesizes useful concept/topic/reference articles.

Use `/wiki:ingest-collection` when the user asks to import, mirror, bulk ingest,
ingest another wiki/repository, split a dataset into per-message sources, or
capture archived snapshots. Do not recursively crawl HTML. Use structured
upstream interfaces:

| Adapter | Use for | Primary access path |
|---------|---------|---------------------|
| `git` | GitHub/GitLab/local repos containing specs, proposals, docs | `git clone --depth 1`, `git ls-tree`, raw file reads |
| `mediawiki-dump` | Full MediaWiki imports or large snapshots | Official `.xml`, `.xml.bz2`, `.xml.gz` dumps |
| `mediawiki-api` | Targeted MediaWiki imports or dumpless sites | `api.php` with `allpages` + `revisions` |
| `csv-messages` | CSV/TSV/JSON/JSONL message archives such as mailing-list exports | Python stdlib `csv`/`json`, one child source per message row/object |
| `wayback-cdx` | Internet Archive snapshots for known URLs or URL prefixes | CDX API inventory, snapshot fetch, readability-to-markdown extraction |

### Collection Manifest

Every collection import writes a manifest source to `raw/repos/`:

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

The manifest is operational provenance. Lint should not treat
`collection-manifest` sources as coverage failures just because no compiled
article cites them directly.

### Child Sources

Each upstream page/proposal/spec becomes its own immutable raw source, usually
under `raw/articles/`:

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

Deduplication key: `collection` + `upstream_id` + `revision`/`sha`. If the exact
same upstream item was already ingested, skip it. If the item changed upstream,
write a new raw source; never overwrite the old one.

### Git Collections

Use Git for repositories such as `bitcoin/bips`; do not scrape GitHub HTML.

1. Clone shallowly or use the local repo path.
2. Record HEAD commit SHA and each blob SHA.
3. Include text-like files (`.md`, `.mediawiki`, `.wiki`, `.rst`, `.txt`,
   `.adoc`).
4. Exclude `.git/`, `.github/`, generated assets, binaries, images, archives,
   vendored dependencies, scripts, and test vectors unless explicitly included.
5. For BIP-style repos, prioritize root `bip-####.mediawiki` and `bip-####.md`
   files. Parse proposal headers such as `BIP`, `Layer`, `Title`, `Authors`,
   `Status`, `Type`, `Requires`, `License`, and `Discussion`.

For BIPs, publication in the repo is provenance for the proposal text, not proof
of adoption or consensus. Compilation must preserve that distinction.

### MediaWiki Dumps

Use official dumps when available. They are stable, polite to the upstream site,
and carry revision metadata.

1. Download or read the dump file.
2. Decompress `.bz2` with `bunzip2 -c` or `.gz` with `gunzip -c`.
3. Parse streaming XML; do not load a large dump entirely into memory.
4. Default to namespace `0`. Skip redirects and titles with `:` unless the user
   explicitly includes them.
5. Store page id/title, latest revision id, timestamp, contributor when
   available, and raw wikitext.

### MediaWiki API

Use the API for targeted imports or when dumps are unavailable:

1. Discover `api.php` from the site URL.
2. List pages via `action=query&list=allpages&apnamespace=0&aplimit=max`.
3. Follow continuation tokens.
4. Fetch content in batches with `prop=revisions`, `rvslots=main`, and
   `rvprop=ids|timestamp|user|comment|content`.
5. Optionally fetch categories and links for graph-aware compilation.
6. Respect throttling; never fall back to uncontrolled HTML crawling.

### CSV/JSON Message Archives

Use this adapter for bounded exports where each row/object is a message,
document, post, email, or transcript item. Examples include Cypherpunks-style
mailing-list CSVs and JSON exports with message-like objects.

1. Read local files directly or download URL sources to a temporary file.
2. Support `.csv`, `.tsv`, `.json`, and `.jsonl` using Python stdlib parsers.
   Do not split arbitrary nested JSON unless the user identifies the message
   array path.
3. Infer message fields conservatively:
   - id: `id`, `message_id`, `Message-ID`, `url`, or stable row number.
   - date: `date`, `created_at`, `timestamp`, `sent`, or `time`.
   - author: `author`, `from`, `sender`, `name`, or `handle`.
   - subject/title: `subject`, `title`, or the first non-empty text fragment.
   - body: `body`, `text`, `content`, `message`, `plain`, or `markdown`.
4. On ambiguous schemas, run `--dry-run` first and report detected columns,
   candidate field mapping, row count, and a sample. Ask before writing if the
   body field cannot be identified with high confidence.
5. Write the manifest to `raw/repos/` and each message to `raw/notes/` unless
   the dataset is explicitly a set of articles or formal documents.
6. Preserve row/object provenance in frontmatter: `row_number`, `message_id`,
   `author`, `date`, `subject`, `dataset_sha`, and `source_columns` when known.
7. Deduplicate by stable message id when present; otherwise use
   `dataset_sha + row_number + content hash`.

Message bodies should be markdown documents with a small provenance header
followed by the original message text. Preserve quoting, code blocks, URLs, and
mailing-list headers that may matter for later source criticism.

### Wayback CDX Snapshots

Use this adapter for bounded archived web captures. The CDX API is the
inventory; never recursively crawl live or archived HTML beyond the CDX result
set.

1. Accept either a CDX API URL or an original URL/prefix. For original URLs,
   query `https://web.archive.org/cdx` with JSON output, `fl=timestamp,original,statuscode,mimetype,digest,length`, and a conservative `filter=statuscode:200`.
2. Use `collapse=digest` by default to avoid duplicate captures with identical
   content. Respect `--from`, `--to`, `--include`, `--exclude`, and `--limit`
   if provided.
3. Fetch each selected capture with the `id_` replay form so the archived HTML
   is returned with minimal Wayback UI rewriting:
   `https://web.archive.org/web/<timestamp>id_/<original-url>`.
4. Convert HTML to markdown with a readability pipeline. Prefer a temporary
   Python virtual environment using `readability-lxml` plus `markdownify` or
   `html2text`; if dependency installation is unavailable, use WebFetch with an
   extraction prompt and record the fallback in `extraction_tool`.
5. Write the manifest to `raw/repos/` and each readable snapshot to
   `raw/articles/`. Preserve snapshot provenance in frontmatter:
   `wayback_timestamp`, `wayback_original`, `wayback_digest`, `statuscode`,
   `mimetype`, `length`, `canonical_url`, and `extraction_tool`.
6. Skip captures whose body is empty, binary, or mostly navigation after
   readability extraction. Count and report skips by reason.

For volatile pages, later compilation should treat Wayback captures as evidence
of what an archived page said at a specific timestamp, not as evidence that the
claim remains true.

### Collection Compilation

After collection ingestion, compile selectively:

- Prefer synthesized clusters over one compiled article per page.
- Use reference articles for indexes/timelines/glossaries.
- For BIPs, likely clusters are activation mechanisms, wallet standards, script
  upgrades, peer services, Taproot/Schnorr, mining/RPC, and the BIP process.
- For community wikis, default confidence to `medium` unless corroborated by
  authoritative specs, code, papers, or multiple independent sources.

## URL Ingestion

1. **Detect X.com / Twitter URLs**: If the URL matches `x.com/*/status/*` or `twitter.com/*/status/*`, follow this fallback chain in order:

   **a) Grok MCP (preferred)**: Check if the `grok` MCP server is available by looking for tools matching `mcp__grok__*` (e.g., `mcp__grok__search`). If available, use it to fetch the tweet/thread content. Extract: author handle, display name, full text, date, media descriptions, thread context.
   > Install: [github.com/nvk/ask-grok-mcp](https://github.com/nvk/ask-grok-mcp)

   **b) FxTwitter proxy**: If Grok MCP is not available, rewrite the URL:
   - `x.com/user/status/123` → `https://api.fxtwitter.com/user/status/123`
   - WebFetch this API URL — it returns JSON with full tweet text, author, media, and thread data.
   - Parse the JSON response for `tweet.text`, `tweet.author`, `tweet.created_at`.

   **c) VxTwitter proxy**: If FxTwitter fails, try:
   - `x.com/user/status/123` → `https://api.vxtwitter.com/user/status/123`
   - Same JSON extraction as FxTwitter.

   **d) Direct WebFetch**: Last resort — WebFetch the original `x.com` URL. This often returns limited content (login walls), but sometimes works for public tweets.

   **e) Manual fallback**: If all above fail, report: "Could not fetch tweet content. Options: install [ask-grok-mcp](https://github.com/nvk/ask-grok-mcp) for X.com access, or paste the tweet text manually via `/wiki:ingest \"text\" --title \"@author tweet\"`."

   Type: notes (unless overridden).

2. **Detect PDF URLs**: If the URL ends in `.pdf` or returns a PDF content type,
   download it to a temporary file and follow the PDF file ingestion flow.
   Type: papers by default unless the content is clearly legal/regulatory
   correspondence better treated as articles.

3. **GitHub repo URLs**: Use WebFetch with prompt:

   > "Extract from this GitHub repository: name, description, key technologies, main purpose, README content. Format as markdown."

4. **General URLs**: Use WebFetch to retrieve content. Prompt:

   > "Extract the complete article content from this page. Return: title, author(s) if listed, date published if listed, and the full article text preserving all factual claims, data points, code examples, and technical details. Format as clean markdown."

5. **Failure handling**: If WebFetch fails (auth wall, paywall), report the failure. Suggest: paste content manually via `/wiki:ingest "text" --title "Title"`.

## File Ingestion

1. Read the file directly
2. Markdown → preserve formatting
3. Plain text → wrap in markdown
4. PDF → extract to markdown using the PDF ingestion flow below
5. JSON/CSV/structured data → describe schema + representative sample for
   single-source ingest, or hand off to `ingest-collection --adapter
   csv-messages` when the user wants one source per row/message
6. Images → create a metadata stub noting the image path and any visible content description

### PDF Ingestion

PDFs are single-source ingests, not collection imports. Use them for court
filings, regulatory papers, academic PDFs, reports, and scanned documents whose
content should become one raw markdown source.

1. Determine source type:
   - `papers` for academic, technical, regulatory, or report-like PDFs.
   - `articles` for legal filings, court exhibits, notices, or web-published
     documents that are not papers.
2. Try `pdftotext -layout <pdf> -` only if it is available and produces
   non-trivial text. If local poppler is broken, missing, or returns garbled
   output, do not keep retrying it.
3. Fallback to a temporary Python virtual environment and a PDF library:
   - Prefer `pypdf` for text-first PDFs because it is lightweight.
   - Use `pymupdf` when layout fidelity or extraction quality matters.
   - Record `extraction_tool` and any dependency/version in frontmatter or a
     short provenance note.
4. If the PDF is image-only and no OCR tool is available, create a metadata stub
   with `extraction_status: ocr-needed`, page count if detectable, file hash,
   and the original path/URL. Do not invent text from the filename.
5. Preserve page boundaries in the body with `## Page N` headings when the
   extractor exposes them. Keep footnotes, docket numbers, tables, citations,
   and regulatory/legal identifiers intact.
6. Include extra frontmatter when known: `content_format: pdf`, `sha256`,
   `page_count`, `extraction_tool`, `extraction_status`, and `fetched` for URL
   PDFs.

## Freeform Text Ingestion

1. User provides quoted text as the argument
2. If `--title` not provided, derive a title from the first sentence or ask
3. Auto-tag based on content keywords

## Inbox Processing

The `inbox/` directory is a drop zone. Users dump files there via Finder, `cp`, etc.

### Processing `--inbox`:

1. Scan `inbox/` for all files (exclude `.processed/` subdirectory and hidden files)
2. For each file:
   - `.url` or `.webloc` files → extract the URL, then follow URL ingestion flow
   - `.md` or `.txt` files → ingest as notes or articles (auto-detect)
   - `.pdf` files → extract to markdown with the PDF ingestion flow
   - `.json`, `.csv`, `.tsv` → ingest as data, or hand off to
     `ingest-collection --adapter csv-messages` for per-message sources
   - Other files → create a metadata stub noting file type and path
3. Move each processed file to `inbox/.processed/` (or delete if user did not pass `--keep`)
4. Report each item processed
5. If 5+ items were processed, suggest: "You've ingested N new sources. Want me to compile? Run `/wiki:compile`"

## Slug Generation

1. Take the title, lowercase, replace spaces with hyphens, remove special characters
2. Prepend today's date: `YYYY-MM-DD-`
3. Truncate to 60 characters max (not counting .md extension)
4. Example: "Attention Is All You Need" → `2026-04-04-attention-is-all-you-need.md`
5. If a file with that slug already exists, append `-2`, `-3`, etc.

## Post-Ingestion Index Updates

After writing each source file, update indexes in order:

1. `raw/{type}/_index.md` — add row to Contents table
2. `raw/_index.md` — add row to Contents table
3. `_index.md` (master) — increment source count, add to Recent Changes

## Batch Ingestion

If the user provides multiple URLs or paths (comma-separated, space-separated, or one per line), process each sequentially. Report progress after each item.

## Compilation Nudge

After ingestion, count uncompiled sources (sources ingested after last compile date). If 5+, suggest running `/wiki:compile`.
