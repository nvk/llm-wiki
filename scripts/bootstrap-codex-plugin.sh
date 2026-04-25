#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCOPE="project"
PROJECT_ROOT="${PWD}"
USER_HOME="${HOME}"
PRINT_ONLY=0
VERIFY=0
MARKETPLACE_NAME="llm-wiki"
PLUGIN_KEY="wiki@${MARKETPLACE_NAME}"

usage() {
  cat <<'EOF'
Usage: ./scripts/bootstrap-codex-plugin.sh [options]

Register this repo as a local Codex marketplace source and write a managed
plugin-enable block for @wiki.

Options:
  --scope project|user   Where to write config (default: project)
  --project-root <dir>   Project root for project scope (default: current dir)
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
  project|user) ;;
  *)
    echo "Invalid scope: $SCOPE (expected project or user)" >&2
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
  HOME="$USER_HOME" codex plugin marketplace add "$ROOT"
else
  if [[ "$MARKETPLACE_SOURCE" != "$ROOT" ]]; then
    echo "Codex marketplace '${MARKETPLACE_NAME}' already points at:" >&2
    echo "  $MARKETPLACE_SOURCE" >&2
    echo "This helper will not overwrite another checkout automatically." >&2
    echo "Use that checkout, or remove/re-add the marketplace in this Codex home first." >&2
    exit 1
  fi
fi

if [[ "$SCOPE" == "project" ]]; then
  TARGET="$PROJECT_ROOT/.codex/config.toml"
else
  TARGET="$USER_HOME/.codex/config.toml"
fi

mkdir -p "$(dirname "$TARGET")"

python3 - "$TARGET" "$MANAGED_BLOCK" <<'PY'
import re
import sys
from pathlib import Path

target = Path(sys.argv[1])
block = sys.argv[2]
begin = "# BEGIN llm-wiki Codex bootstrap"
end = "# END llm-wiki Codex bootstrap"
managed = f"{begin}\n{block}\n{end}\n"

if target.exists():
    text = target.read_text()
else:
    text = ""

pattern = re.compile(
    rf"(?ms)^{re.escape(begin)}\n.*?^{re.escape(end)}\n?"
)

if pattern.search(text):
    updated = pattern.sub(managed, text, count=1)
else:
    if text and not text.endswith("\n"):
        text += "\n"
    if text:
        text += "\n"
    updated = text + managed

target.write_text(updated)
PY

echo "Wrote Codex plugin config:"
echo "  $TARGET"
echo "Source repo:"
echo "  $ROOT"
echo "Codex home:"
echo "  $USER_HOME"

if [[ "$VERIFY" -eq 1 ]]; then
  if [[ "$SCOPE" == "project" ]]; then
    "$ROOT/scripts/verify-codex-plugin.sh" --scope project --project-root "$PROJECT_ROOT" --user-home "$USER_HOME"
  else
    "$ROOT/scripts/verify-codex-plugin.sh" --scope user --user-home "$USER_HOME"
  fi
fi
