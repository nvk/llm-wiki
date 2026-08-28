#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCOPE="user"
PROJECT_ROOT="${PWD}"
USER_HOME="${HOME}"
MARKETPLACE_NAME="llm-wiki"
PLUGIN_KEY="wiki@${MARKETPLACE_NAME}"

usage() {
  cat <<'EOF'
Usage: ./scripts/verify-codex-plugin.sh [options]

Verify that Codex resolves the @wiki plugin and installs the explicit-only
$wiki-query skill from this repo.

Options:
  --scope user           Verify the supported user install (default: user)
  --project-root <dir>   Working directory for the prompt probe (default: current dir)
  --user-home <dir>      HOME used for Codex config lookup (default: current HOME)
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
    echo "Verify the user-scoped install with --scope user." >&2
    exit 1
    ;;
  *)
    echo "Invalid scope: $SCOPE (expected user)" >&2
    exit 1
    ;;
esac

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
USER_HOME="$(cd "$USER_HOME" && pwd)"
SOURCE_PLUGIN_ROOT="$ROOT/plugins/llm-wiki"
SOURCE_SKILL_PATH="$SOURCE_PLUGIN_ROOT/skills/wiki/SKILL.md"
SOURCE_QUERY_SKILL_PATH="$SOURCE_PLUGIN_ROOT/skills/wiki-query/SKILL.md"
EXPECTED_VERSION="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["version"])' "$SOURCE_PLUGIN_ROOT/.codex-plugin/plugin.json")"
TMP_OUTPUT="$(mktemp)"
TMP_LIST="$(mktemp)"
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

TARGET_CONFIG="$USER_CONFIG"
cleanup() {
  rm -f "$TMP_OUTPUT" "$TMP_LIST"
}
trap cleanup EXIT

if [[ ! -f "$USER_CONFIG" ]]; then
  echo "Missing user Codex config:" >&2
  echo "  $USER_CONFIG" >&2
  echo "Run ./scripts/bootstrap-codex-plugin.sh first." >&2
  exit 1
fi

if [[ ! -f "$TARGET_CONFIG" ]]; then
  echo "Missing Codex config for scope '$SCOPE':" >&2
  echo "  $TARGET_CONFIG" >&2
  echo "Run ./scripts/bootstrap-codex-plugin.sh --scope $SCOPE first." >&2
  exit 1
fi

if ! grep -Fq "[plugins.\"$PLUGIN_KEY\"]" "$TARGET_CONFIG"; then
  echo "Missing plugin enable block in:" >&2
  echo "  $TARGET_CONFIG" >&2
  echo "Run ./scripts/bootstrap-codex-plugin.sh --scope $SCOPE first." >&2
  exit 1
fi

HOME="$USER_HOME" CODEX_HOME="$(codex_home_for "$USER_HOME")" codex -C "$PROJECT_ROOT" plugin list --marketplace "$MARKETPLACE_NAME" --json >"$TMP_LIST"
HOME="$USER_HOME" CODEX_HOME="$(codex_home_for "$USER_HOME")" codex -C "$PROJECT_ROOT" debug prompt-input '@wiki test' >"$TMP_OUTPUT"

INSTALLED_VERSION="$(python3 - "$TMP_LIST" "$PLUGIN_KEY" "$EXPECTED_VERSION" "$SOURCE_PLUGIN_ROOT" "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

data = json.load(open(sys.argv[1]))
plugin_key, expected_version, source_root, marketplace_root = sys.argv[2:]
plugin = next((item for item in data.get("installed", []) if item.get("pluginId") == plugin_key), None)
if plugin is None:
    raise SystemExit(f"FAIL: {plugin_key} is not installed")

errors = []
if not plugin.get("installed"):
    errors.append("plugin is not installed")
if not plugin.get("enabled"):
    errors.append("plugin is not enabled in the selected scope")
if plugin.get("version") != expected_version:
    errors.append(f"installed version {plugin.get('version')!r} != expected {expected_version!r}")

def strip_extended_prefix(text):
    """Codex records Windows paths in extended-length form (\\\\?\\C:\\...).

    Comparing that spelling verbatim against the path we asked for reports a
    correct install as a mismatch, so compare identities instead.
    """
    for prefix in ("\\\\?\\UNC\\", "\\\\?\\"):
        if text.startswith(prefix):
            return text[len(prefix):]
    return text


def same_path(actual, expected):
    if not actual:
        return False
    actual = Path(strip_extended_prefix(str(actual))).expanduser().resolve()
    return actual == Path(str(expected)).expanduser().resolve()

source = plugin.get("source") or {}
if source.get("source") != "local" or not same_path(source.get("path"), source_root):
    errors.append(f"plugin source does not point at {source_root}")
marketplace = plugin.get("marketplaceSource") or {}
if marketplace.get("sourceType") != "local" or not same_path(marketplace.get("source"), marketplace_root):
    errors.append(f"marketplace source does not point at {marketplace_root}")

if errors:
    raise SystemExit("FAIL: " + "; ".join(errors))
print(plugin["version"])
PY
)"

EXPECTED_CACHE_SKILL="$USER_HOME/.codex/plugins/cache/$MARKETPLACE_NAME/wiki/$INSTALLED_VERSION/skills/wiki/SKILL.md"
EXPECTED_CACHE_QUERY_SKILL="$USER_HOME/.codex/plugins/cache/$MARKETPLACE_NAME/wiki/$INSTALLED_VERSION/skills/wiki-query/SKILL.md"
if [[ ! -f "$EXPECTED_CACHE_SKILL" ]]; then
  echo "FAIL: installed Codex cache is missing the wiki skill:" >&2
  echo "  $EXPECTED_CACHE_SKILL" >&2
  exit 1
fi
if [[ ! -f "$EXPECTED_CACHE_QUERY_SKILL" ]]; then
  echo "FAIL: installed Codex cache is missing the wiki-query skill:" >&2
  echo "  $EXPECTED_CACHE_QUERY_SKILL" >&2
  exit 1
fi

ACTUAL_SKILL_PATH="$(python3 - "$TMP_OUTPUT" <<'PY'
import json
import re
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text())

def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for item in value:
            yield from strings(item)
    elif isinstance(value, dict):
        for item in value.values():
            yield from strings(item)

for text in strings(data):
    for line in text.splitlines():
        if "- wiki:wiki:" not in line:
            continue
        match = re.search(r"\(file: ([^)]+/skills/wiki/SKILL\.md)\)", line)
        if match:
            print(match.group(1))
            raise SystemExit(0)
print("")
PY
)"

if [[ -z "$ACTUAL_SKILL_PATH" ]]; then
  echo "FAIL: Codex did not expose wiki:wiki in the headless prompt." >&2
  echo "Run ./scripts/bootstrap-codex-plugin.sh --scope $SCOPE again." >&2
  exit 1
fi

if ! python3 - "$ACTUAL_SKILL_PATH" "$EXPECTED_CACHE_SKILL" "$SOURCE_SKILL_PATH" <<'PY'
import sys
from pathlib import Path

actual = Path(sys.argv[1]).expanduser().resolve()
expected = {Path(path).expanduser().resolve() for path in sys.argv[2:]}
raise SystemExit(0 if actual in expected else 1)
PY
then
  echo "FAIL: Codex resolved wiki:wiki from an unexpected plugin:" >&2
  echo "Resolved skill path:" >&2
  echo "  $ACTUAL_SKILL_PATH" >&2
  echo "Expected installed cache path:" >&2
  echo "  $EXPECTED_CACHE_SKILL" >&2
  exit 1
fi

if ! python3 - "$EXPECTED_CACHE_QUERY_SKILL" "$SOURCE_QUERY_SKILL_PATH" <<'PY'
import sys
from pathlib import Path

cached, source = (Path(path).read_text(encoding="utf-8") for path in sys.argv[1:])
raise SystemExit(0 if cached == source else 1)
PY
then
  echo "FAIL: cached wiki-query skill differs from the generated source:" >&2
  echo "  $EXPECTED_CACHE_QUERY_SKILL" >&2
  exit 1
fi

if grep -Fq '/skills/wiki-query/SKILL.md' "$TMP_OUTPUT"; then
  echo "FAIL: explicit-only wiki-query leaked into the implicit skill list." >&2
  exit 1
fi

echo "OK: Codex resolves @wiki and installs explicit-only \$wiki-query from $PLUGIN_KEY version $INSTALLED_VERSION."
echo "Skill paths:"
echo "  $ACTUAL_SKILL_PATH"
echo "  $EXPECTED_CACHE_QUERY_SKILL"
