#!/usr/bin/env bash
# Smoke-test local GitHub Copilot plugin installation without making model calls.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v copilot >/dev/null 2>&1; then
  echo "SKIP: copilot binary not found"
  exit 0
fi

echo "=== Copilot local plugin smoke ==="
echo "Copilot CLI detected. Install the generated package with the local marketplace"
echo "during the authenticated manual smoke; no stable noninteractive local-plugin"
echo "install contract is currently exposed by the CLI for this Preview surface."