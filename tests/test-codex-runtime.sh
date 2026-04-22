#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

if ! command -v codex >/dev/null 2>&1; then
  echo "SKIP: codex binary not found"
  exit 0
fi

mkdir -p "$ROOT/.tmp"
TMP_HOME="$(mktemp -d "$ROOT/.tmp/codex-test-home.XXXXXX")"
trap 'rm -rf "$TMP_HOME"' EXIT

"$ROOT/scripts/bootstrap-codex-plugin.sh" --scope user --user-home "$TMP_HOME"

set +e
"$ROOT/scripts/verify-codex-plugin.sh" --scope user --user-home "$TMP_HOME"
status=$?
set -e

if [[ "$status" -eq 0 ]]; then
  exit 0
fi

if [[ "$status" -eq 2 ]]; then
  echo "SKIP: Codex still requires interactive /plugins enable/materialization for first local install"
  exit 0
fi

exit "$status"
