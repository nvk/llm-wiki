#!/bin/bash
# Validate the local deterministic llm-wiki retract helper.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLI="$PROJECT_ROOT/scripts/llm-wiki"
PASS=0
FAIL=0
TOTAL=0

log_pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[32mPASS\033[0m: %s\n" "$1"; }
log_fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[31mFAIL\033[0m: %s - %s\n" "$1" "$2"; }

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
hub="$tmpdir/hub"
external="$tmpdir/external-wiki"
project="$tmpdir/project"
mkdir -p \
  "$hub/topics/active/raw/notes" \
  "$hub/topics/.archive/old/wiki/concepts" \
  "$hub/.sessions" \
  "$external/output" \
  "$project"
printf '# Hub\n' > "$hub/_index.md"
printf '# Log\n' > "$hub/log.md"
printf '# Active\n' > "$hub/topics/active/_index.md"
printf '# Old\n' > "$hub/topics/.archive/old/_index.md"
printf '# External\n' > "$external/_index.md"
cat > "$hub/wikis.json" <<EOF
{
  "default": "active",
  "wikis": {
    "active": {"path": "topics/active", "status": "active"},
    "old": {"path": "topics/.archive/old", "status": "archived"},
    "external": {"path": "$external", "status": "active"}
  },
  "local_wikis": []
}
EOF

secret='Sup3r Token42'
url_form='Sup3r%20Token42'
base64_form="$(printf '%s' "$secret" | base64 | tr -d '\n')"
hex_form="$(printf '%s' "$secret" | xxd -p | tr -d '\n')"
printf 'plain=%s url=%s\n' "$secret" "$url_form" > "$hub/topics/active/raw/notes/source.md"
printf 'session=%s\n' "$base64_form" > "$hub/.sessions/checkpoint.jsonl"
printf 'archive=%s\n' "$hex_form" > "$hub/topics/.archive/old/wiki/concepts/old.md"
printf 'external=%s\n' "$secret" > "$external/output/result.md"
printf 'name match\n' > "$hub/topics/active/raw/notes/$secret.md"

echo "=== Local llm-wiki CLI Retract ==="

set +e
dry_output="$(cd "$project" && printf '%s' "$secret" | "$CLI" retract --hub "$hub" --everywhere --stdin --json 2>&1)"
dry_rc=$?
set -e
if [ "$dry_rc" -eq 0 ] \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "dry-run"; assert d["text_files_matched"] == 4; assert d["path_names_matched"] == 1' <<<"$dry_output" \
  && ! grep -Fq "$secret" <<<"$dry_output" \
  && grep -Fq "$secret" "$hub/topics/active/raw/notes/source.md"; then
  log_pass "dry-run maps hub, archive, session, external, and path-name matches without disclosure"
else
  log_fail "dry-run maps hub, archive, session, external, and path-name matches without disclosure" "$dry_output"
fi

set +e
apply_output="$(cd "$project" && printf '%s' "$secret" | "$CLI" retract --hub "$hub" --everywhere --stdin --apply --json 2>&1)"
apply_rc=$?
set -e
if [ "$apply_rc" -eq 0 ] \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "verified"; assert d["files_rewritten"] == 4; assert d["paths_renamed"] == 1; assert d["remaining_matches"] == 0' <<<"$apply_output" \
  && ! grep -Fq "$secret" <<<"$apply_output" \
  && [ -f "$hub/topics/active/raw/notes/[RETRACTED].md" ] \
  && ! grep -R -F -e "$secret" -e "$url_form" -e "$base64_form" -e "$hex_form" "$hub" "$external" >/dev/null; then
  log_pass "--apply rewrites common forms, renames paths, and verifies the full local scope"
else
  log_fail "--apply rewrites common forms, renames paths, and verifies the full local scope" "$apply_output"
fi

binary_secret='BinaryToken99'
binary="$hub/topics/active/raw/notes/blob.bin"
printf '\0prefix-%s-suffix' "$binary_secret" > "$binary"
set +e
binary_output="$(printf '%s' "$binary_secret" | "$CLI" retract "$hub" --stdin --apply --json 2>&1)"
binary_rc=$?
set -e
if [ "$binary_rc" -eq 2 ] \
  && [ -f "$binary" ] \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "incomplete"; assert d["binary_files_matched"] == 1' <<<"$binary_output" \
  && ! grep -Fq "$binary_secret" <<<"$binary_output"; then
  log_pass "binary matches remain explicit technical failures by default"
else
  log_fail "binary matches remain explicit technical failures by default" "$binary_output"
fi

set +e
delete_output="$(printf '%s' "$binary_secret" | "$CLI" retract "$hub" --stdin --apply --delete-binary-matches --json 2>&1)"
delete_rc=$?
set -e
if [ "$delete_rc" -eq 0 ] \
  && [ ! -e "$binary" ] \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "verified"; assert d["binary_files_deleted"] == 1' <<<"$delete_output"; then
  log_pass "--delete-binary-matches removes and verifies matched binary files"
else
  log_fail "--delete-binary-matches removes and verifies matched binary files" "$delete_output"
fi

log_secret='retract'
printf '\n## [2026-08-22] note | retract\ndefault-history-marker\n' >> "$hub/log.md"
set +e
log_output="$(printf '%s' "$log_secret" | "$CLI" retract "$hub" --stdin --apply --json 2>&1)"
log_rc=$?
set -e
if [ "$log_rc" -eq 0 ] \
  && ! grep -Fq "$log_secret" "$hub/log.md" \
  && grep -Fq 'default-history-marker' "$hub/log.md" \
  && grep -Fq '[RETRACTED]' "$hub/log.md" \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "verified"' <<<"$log_output"; then
  log_pass "default log redaction preserves entry context and does not reintroduce the value"
else
  log_fail "default log redaction preserves entry context and does not reintroduce the value" "$log_output"
fi

privacy_secret='SensitivePrivacyReference77'
cat >> "$hub/log.md" <<EOF

## [2026-08-22] ingest | imported $privacy_secret
private-context-marker

## [2026-08-22] compile | unrelated source retained
keep-context-marker
EOF
set +e
privacy_dry_output="$(printf '%s' "$privacy_secret" | "$CLI" retract "$hub" --stdin --remove-from-logs --json 2>&1)"
privacy_dry_rc=$?
set -e
if [ "$privacy_dry_rc" -eq 0 ] \
  && grep -Fq "$privacy_secret" "$hub/log.md" \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "dry-run"; assert d["log_entries_matched"] == 1; assert d["log_entries_removed"] == 0; assert d["remove_from_logs"] is True' <<<"$privacy_dry_output" \
  && ! grep -Fq "$privacy_secret" <<<"$privacy_dry_output"; then
  log_pass "--remove-from-logs dry-run counts matching entries without disclosure"
else
  log_fail "--remove-from-logs dry-run counts matching entries without disclosure" "$privacy_dry_output"
fi

set +e
privacy_apply_output="$(printf '%s' "$privacy_secret" | "$CLI" retract "$hub" --stdin --remove-from-logs --apply --json 2>&1)"
privacy_apply_rc=$?
set -e
if [ "$privacy_apply_rc" -eq 0 ] \
  && ! grep -Fq "$privacy_secret" "$hub/log.md" \
  && ! grep -Fq 'private-context-marker' "$hub/log.md" \
  && grep -Fq 'keep-context-marker' "$hub/log.md" \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "verified"; assert d["log_entries_matched"] == 1; assert d["log_entries_removed"] == 1; assert d["remaining_matches"] == 0' <<<"$privacy_apply_output" \
  && ! grep -Fq "$privacy_secret" <<<"$privacy_apply_output"; then
  log_pass "--remove-from-logs removes whole matching entries and keeps unrelated history"
else
  log_fail "--remove-from-logs removes whole matching entries and keeps unrelated history" "$privacy_apply_output"
fi

mkdir -p "$hub/.git/objects"
control_secret='ControlMetadata55'
printf '%s' "$control_secret" > "$hub/.git/objects/example"
set +e
control_output="$(printf '%s' "$control_secret" | "$CLI" retract "$hub" --stdin --apply --json 2>&1)"
control_rc=$?
set -e
if [ "$control_rc" -eq 0 ] \
  && grep -Fq "$control_secret" "$hub/.git/objects/example" \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "verified"; assert d["skipped_version_control_paths"] == 1' <<<"$control_output" \
  && ! grep -Fq "$control_secret" <<<"$control_output"; then
  log_pass "version-control metadata is an explicit local-scope boundary"
else
  log_fail "version-control metadata is an explicit local-scope boundary" "$control_output"
fi

printf '\n=== Results: %d/%d passed' "$PASS" "$TOTAL"
if [ "$FAIL" -gt 0 ]; then
  printf ', %d failed ===\n' "$FAIL"
  exit 1
fi
printf ' ===\n'
