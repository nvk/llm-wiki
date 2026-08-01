#!/usr/bin/env bash
# Validate cross-document consistency that is easy to drift in markdown plugins.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

python3 - <<'PY'
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

root = Path.cwd()
failures: list[str] = []


def fail(message: str) -> None:
    failures.append(message)


def tracked_files(pattern: str) -> list[Path]:
    try:
        output = subprocess.check_output(["git", "ls-files", pattern], text=True)
        files = [root / line for line in output.splitlines() if line.strip()]
        if files:
            return files
    except Exception:
        pass
    return sorted(root.glob(pattern))


# README active command table should mention every command file. Parse only the
# first table column under ## Commands so historical prose like old /wiki:search
# mentions does not count as an active command.
readme = (root / "README.md").read_text(encoding="utf-8")
commands_section = re.search(r"^## Commands\n(?P<body>.*?)(?:\n## |\Z)", readme, re.M | re.S)
if not commands_section:
    fail("README.md is missing the ## Commands section")
    active_readme_commands: set[str] = set()
else:
    active_readme_commands = set()
    for line in commands_section.group("body").splitlines():
        if not line.startswith("|") or "---" in line:
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if not cells or cells[0] in {"Command", ""}:
            continue
        command_cell = cells[0]
        if re.search(r"`/wiki(?:`|\s)", command_cell):
            active_readme_commands.add("wiki")
        for match in re.finditer(r"`/wiki:([a-z-]+)", command_cell):
            active_readme_commands.add(match.group(1))

command_files = tracked_files("claude-plugin/commands/*.md")
command_stems = {path.stem for path in command_files}
missing = sorted(command_stems - active_readme_commands)
if missing:
    fail("README command table omits command file(s): " + ", ".join(missing))
extra = sorted(active_readme_commands - command_stems)
if extra:
    fail("README command table names command(s) without command files: " + ", ".join(extra))


# Manifest versions should agree across distribution surfaces.
manifest_paths = [
    root / ".claude-plugin/marketplace.json",
    root / "claude-plugin/.claude-plugin/plugin.json",
    root / "plugins/llm-wiki/.codex-plugin/plugin.json",
    root / "plugins/llm-wiki-copilot/plugin.json",
]
versions: dict[str, str] = {}
for path in manifest_paths:
    if not path.exists():
        fail(f"missing manifest: {path.relative_to(root)}")
        continue
    data = json.loads(path.read_text(encoding="utf-8"))
    version = str(data.get("version") or "")
    if not version:
        fail(f"manifest has no top-level version: {path.relative_to(root)}")
    versions[str(path.relative_to(root))] = version
    if path.name == "marketplace.json":
        plugin_versions = {
            str(plugin.get("version") or "")
            for plugin in data.get("plugins", [])
            if isinstance(plugin, dict)
        }
        if len(plugin_versions) != 1 or version not in plugin_versions:
            fail("marketplace.json top-level version and plugin entry version differ")
if len(set(versions.values())) > 1:
    fail("manifest versions differ: " + ", ".join(f"{k}={v}" for k, v in versions.items()))

copilot_marketplace = root / ".github/plugin/marketplace.json"
if not copilot_marketplace.exists():
    fail("missing Copilot marketplace: .github/plugin/marketplace.json")
else:
    data = json.loads(copilot_marketplace.read_text(encoding="utf-8"))
    plugins = data.get("plugins", [])
    if len(plugins) != 1 or plugins[0].get("source") != "./plugins/llm-wiki-copilot":
        fail("Copilot marketplace must point at ./plugins/llm-wiki-copilot")
    elif plugins[0].get("version") != next(iter(versions.values()), ""):
        fail("Copilot marketplace plugin version differs from distribution manifests")


# REFERENCE_NAMES is intentionally duplicated across validation loops. It should
# enumerate every tracked Claude-side reference file.
validate = (root / "tests/test-plugin-validate.sh").read_text(encoding="utf-8")
match = re.search(r'^REFERENCE_NAMES="([^"]+)"', validate, re.M)
if not match:
    fail("test-plugin-validate.sh is missing REFERENCE_NAMES")
    reference_names: set[str] = set()
else:
    reference_names = set(match.group(1).split())
tracked_refs = {
    path.stem for path in tracked_files("claude-plugin/skills/wiki-manager/references/*.md")
}
missing_refs = sorted(tracked_refs - reference_names)
extra_refs = sorted(reference_names - tracked_refs)
if missing_refs:
    fail("REFERENCE_NAMES omits tracked reference(s): " + ", ".join(missing_refs))
if extra_refs:
    fail("REFERENCE_NAMES names missing tracked reference(s): " + ", ".join(extra_refs))

if failures:
    print("=== Docs Consistency ===")
    for item in failures:
        print(f"FAIL: {item}")
    sys.exit(1)

print("OK: docs, command table, manifests, and reference lists are consistent.")
PY
