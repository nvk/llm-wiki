#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCOPE="user"
PROJECT_ROOT="${PWD}"
USER_HOME="${HOME}"
PRINT_ONLY=0
VERIFY=0
MARKETPLACE_NAME="llm-wiki"
PLUGIN_KEY="wiki@${MARKETPLACE_NAME}"

usage() {
  cat <<'EOF'
Usage: ./scripts/bootstrap-codex-plugin.sh [options]

Register this repo as a local Codex marketplace source, install @wiki and the
bundled $wiki-query preset into the Codex plugin cache, and enable the plugin
in the user config.

Options:
  --scope user           Plugin enablement scope (default: user). Codex 0.144
                         does not load plugin enablement from project config.
  --project-root <dir>   Working directory for the optional verification probe
  --user-home <dir>      HOME used for Codex marketplace registration and
                         user-scope config writes (default: current HOME)
  --print                Print the managed TOML block without writing it
  --verify               Run scripts/verify-codex-plugin.sh after writing
  -h, --help             Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)
      [[ $# -ge 2 ]] || { echo "Missing value for --scope" >&2; exit 1; }
      SCOPE="$2"
      shift 2
      ;;
    --project-root)
      [[ $# -ge 2 ]] || { echo "Missing value for --project-root" >&2; exit 1; }
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --user-home)
      [[ $# -ge 2 ]] || { echo "Missing value for --user-home" >&2; exit 1; }
      USER_HOME="$2"
      shift 2
      ;;
    --print)
      PRINT_ONLY=1
      shift
      ;;
    --verify)
      VERIFY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "$SCOPE" in
  user) ;;
  project)
    echo "Project-scoped plugin enablement is not supported by Codex 0.144." >&2
    echo "Use --scope user; plugin hooks can still be enabled or disabled separately." >&2
    exit 1
    ;;
  *)
    echo "Invalid scope: $SCOPE (expected user)" >&2
    exit 1
    ;;
esac

if [[ "$PRINT_ONLY" -eq 1 && "$VERIFY" -eq 1 ]]; then
  echo "--print and --verify cannot be combined" >&2
  exit 1
fi

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
USER_HOME="$(cd "$USER_HOME" && pwd)"
USER_CONFIG="$USER_HOME/.codex/config.toml"

# Codex resolves its own home from CODEX_HOME, falling back to the OS home - and
# on Windows that fallback is USERPROFILE, not HOME. Setting HOME alone therefore
# leaves every invocation below writing into the real user profile, so
# --user-home does not isolate anything and the runtime test installs a
# marketplace and a plugin into the developer's own Codex config. Export
# CODEX_HOME too, in the form the native binary can read.
codex_home_for() {
  local home="$1/.codex"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$home"
  else
    printf '%s' "$home"
  fi
}


MANAGED_BLOCK="$(python3 - "$PLUGIN_KEY" <<'PY'
import sys

plugin_key = sys.argv[1]

print(f'[plugins."{plugin_key}"]')
print('enabled = true')
PY
)"

if [[ "$PRINT_ONLY" -eq 1 ]]; then
  printf '%s\n' "$MANAGED_BLOCK"
  exit 0
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "codex binary not found in PATH" >&2
  exit 1
fi

if ! HOME="$USER_HOME" CODEX_HOME="$(codex_home_for "$USER_HOME")" codex plugin add --help >/dev/null 2>&1; then
  echo "This Codex version does not support non-interactive plugin installation." >&2
  echo "Upgrade Codex, then rerun this helper." >&2
  exit 1
fi

mkdir -p "$USER_HOME/.codex"

MARKETPLACE_SOURCE="$(
  python3 - "$USER_CONFIG" "$MARKETPLACE_NAME" <<'PY'
import re
import sys
from pathlib import Path

config = Path(sys.argv[1])
marketplace = re.escape(sys.argv[2])

if not config.exists():
    print("")
    raise SystemExit(0)

text = config.read_text()
match = re.search(
    rf'(?ms)^\[marketplaces\.{marketplace}\]\n.*?^source = "(.*?)"$',
    text,
)
print(match.group(1) if match else "")
PY
)"

if [[ -z "$MARKETPLACE_SOURCE" ]]; then
  HOME="$USER_HOME" CODEX_HOME="$(codex_home_for "$USER_HOME")" codex plugin marketplace add "$ROOT"
else
  if [[ "$MARKETPLACE_SOURCE" != "$ROOT" ]]; then
    echo "Codex marketplace '${MARKETPLACE_NAME}' already points at:" >&2
    echo "  $MARKETPLACE_SOURCE" >&2
    echo "This helper will not overwrite another checkout automatically." >&2
    echo "Use that checkout, or remove/re-add the marketplace in this Codex home first." >&2
    exit 1
  fi
fi

# `codex plugin add` is the supported materialization path. It copies the
# plugin into ~/.codex/plugins/cache and writes the supported user-scope enable
# block. Marketplace registration alone does not install the plugin.
INSTALL_OUTPUT="$(HOME="$USER_HOME" CODEX_HOME="$(codex_home_for "$USER_HOME")" codex plugin add "$PLUGIN_KEY" --json)"
INSTALLED_PATH="$(python3 -c 'import json, sys; print(json.load(sys.stdin)["installedPath"])' <<<"$INSTALL_OUTPUT")"
TARGET="$USER_CONFIG"

echo "Installed Codex plugin:"
echo "  $PLUGIN_KEY"
echo "Installed cache:"
echo "  $INSTALLED_PATH"
echo "Enabled scope:"
echo "  $SCOPE"
echo "Codex plugin config:"
echo "  $TARGET"
echo "Source repo:"
echo "  $ROOT"
echo "Codex home:"
echo "  $USER_HOME"

if [[ "$VERIFY" -eq 1 ]]; then
  "$ROOT/scripts/verify-codex-plugin.sh" --scope user --project-root "$PROJECT_ROOT" --user-home "$USER_HOME"
fi
