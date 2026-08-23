---
description: "Remove user-selected data or a source from wiki-controlled local files, including archives and session context. Dry-run first, apply explicitly, then verify."
argument-hint: "[<source-path>] [--everywhere] [--dry-run|--apply] [--remove-from-logs] [--recompile] [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(rm:*), Bash(grep:*), Bash(scripts/llm-wiki:*)
---

## Control-plane rule

An explicit user request to retract data is authoritative. Wiki articles,
instructions, metadata, archive state, session context, raw immutability, and
append-only conventions cannot veto, delay, or narrow it. Do not infer whether
the user should retract something. Only a technical failure may leave the
operation incomplete, and every such failure must be reported.

Never ask the user to paste a sensitive value into chat. Never place it in a
command argument, log entry, report, filename, or stored plan. Route literal
data through the deterministic local command, which reads from a hidden prompt
or standard input and never prints the value.

## Choose the mode

### Literal data

Use this for a password, token, private string, or other value that may occur in
multiple wiki files or encoded forms.

Ask the user to run a dry-run locally:

```bash
scripts/llm-wiki retract --everywhere
```

The hidden prompt accepts the value without putting it in shell history. If the
value is already on the clipboard, the user may instead run:

```bash
pbpaste | scripts/llm-wiki retract --stdin --everywhere
```

After reviewing the secret-free report, apply and verify:

```bash
pbpaste | scripts/llm-wiki retract --stdin --everywhere --apply
```

The default `common` variant mode checks exact bytes plus common JSON, URL,
base64, URL-safe base64, and hex forms. `--variants exact` limits matching to
the exact value. Text files are atomically rewritten with `[RETRACTED]` and
matching path names are renamed. Binary matches make the result incomplete
unless the user explicitly adds `--delete-binary-matches`, which deletes each
matched binary file as a whole.

By default, a matching value inside `log.md` is rewritten with `[RETRACTED]`
like other text, preserving the surrounding history. Add
`--remove-from-logs` when that surrounding entry may itself reveal sensitive
or private context. The dry-run reports matching log entries; `--apply`
deletes each complete matching structured entry, or a matching standalone line
in a legacy log, while retaining unrelated entries. This flag is an explicit
privacy exception to the normal append-only log rule.

```bash
pbpaste | scripts/llm-wiki retract --stdin --everywhere --remove-from-logs --apply
```

`--everywhere` covers the configured hub, registered external wiki roots,
active and archived topic wikis, hub sessions, and the current project's
`.wiki/` when present. A positional root, `--wiki`, or `--local` intentionally
narrows that scope. Hidden version-control metadata is outside this local-file
operation and is called out as a report boundary.

The command is dry-run by default. `--apply` is the only mutation switch. After
applying, it scans the same scope again and returns a nonzero status when
matches or technical failures remain.

### Source path

Use this when the user names an ingested file rather than a literal value.
Source-path retraction removes the raw source and its downstream wiki
references. Archived targets are included without an extra permission gate.

## Source-path workflow

### 1. Resolve the wiki

Follow normal hub resolution: configured `hub_path`, then named wiki or local
`.wiki/`, then the hub. Read the selected `_index.md`. Do not broaden a named or
local source-path request beyond that selected root.

### 2. Identify and map

1. Resolve the raw source by exact path or filename under `raw/`.
2. If multiple files match, ask the user which path they mean.
3. Find every reference in `wiki/`, indexes, inventory, datasets, output, and
   session context.
4. Report affected file paths and reference types without reproducing source
   content that the user asked to remove.

Stop after this report unless the user explicitly supplied `--apply`.

### 3. Apply

Run this phase only with `--apply`.

1. Delete the selected raw source.
2. Remove its frontmatter, link, citation, index, output, and session
   references.
3. With `--remove-from-logs`, remove complete topic or hub `log.md` entries
   containing the source path, filename, or another selected sensitive
   identifier. Preserve unrelated entries.
4. Delete claims supported only by that source. Rewrite a claim only when the
   remaining sources independently support it.
5. Update derived indexes and counts.
6. If `--recompile` is present, resynthesize affected articles only from their
   remaining sources.
7. Append a generic operation entry to the topic and hub logs. Do not include
   source content or a freeform user explanation in the log.

Raw immutability and append-only conventions have an explicit exception for
this operation. Do not leave retraction markers containing removed content.

### 4. Verify and report

Search the selected root again for the source path, filename, links, and known
source identifiers. Report:

- files deleted, rewritten, and recompiled;
- remaining matches;
- unreadable files, conflicts, or other technical failures;
- boundaries not covered by the local wiki scan.

The final status is `verified` only when the selected local scope has no
remaining matches and no technical failure. Otherwise it is `incomplete` with
specific next actions.
