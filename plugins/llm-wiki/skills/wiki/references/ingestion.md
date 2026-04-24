# Ingestion Protocol

## Overview

Ingestion converts external material into a standardized raw source file in the wiki's `raw/` directory. Sources are immutable after ingestion.

## Source Types

| Type | Directory | Auto-detect signals |
|------|-----------|-------------------|
| articles | raw/articles/ | General web URLs, blog posts |
| papers | raw/papers/ | arxiv.org, scholar.google, .pdf URLs, academic language |
| repos | raw/repos/ | github.com, gitlab.com URLs |
| notes | raw/notes/ | Freeform text, tweets, no URL |
| data | raw/data/ | .csv, .json, .tsv URLs or files, dataset references |

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

2. **General URLs**: Use WebFetch to retrieve content. Prompt:

   > "Extract the complete article content from this page. Return: title, author(s) if listed, date published if listed, and the full article text preserving all factual claims, data points, code examples, and technical details. Format as clean markdown."

3. **GitHub repo URLs**: Use WebFetch with prompt:

   > "Extract from this GitHub repository: name, description, key technologies, main purpose, README content. Format as markdown."

4. **Failure handling**: If WebFetch fails (auth wall, paywall), report the failure. Suggest: paste content manually via `/wiki:ingest "text" --title "Title"`.

## File Ingestion

1. Read the file directly
2. Markdown → preserve formatting
3. Plain text → wrap in markdown
4. JSON/CSV/structured data → describe schema + representative sample (not full dataset)
5. Images → create a metadata stub noting the image path and any visible content description

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
   - `.pdf` files → create a metadata stub, note the file path for reference
   - `.json`, `.csv`, `.tsv` → ingest as data
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
