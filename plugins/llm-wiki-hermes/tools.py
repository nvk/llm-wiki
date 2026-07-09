from __future__ import annotations

import json
import shlex
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SESSION_SCRIPT = REPO_ROOT / "scripts" / "llm-wiki-session"
CLI_SCRIPT = REPO_ROOT / "scripts" / "llm-wiki"

# Subcommands that live in the session engine (scripts/llm-wiki-session).
# Everything else (lint, archive, schema) lives in the CLI tool (scripts/llm-wiki).
SESSION_COMMANDS = {
    "enable",
    "disable",
    "hook",
    "capture",
    "list",
    "show",
    "rehydrate",
    "promote",
    "feedback",
    "status",
    "session",
}


def _run(script, command, rest):
    try:
        # `rest` is a space-separated arg string; split shell-safe (no shell=True).
        # This is deterministic for our known subcommands (lint/archive/schema/session
        # ops) which take simple flags like `--fix PATH` or `disable`.
        proc = subprocess.run(
            [sys.executable, str(script), command, *shlex.split(rest or "")],
            capture_output=True,
            text=True,
            timeout=120,
        )
    except subprocess.TimeoutExpired as exc:  # pragma: no cover - defensive
        return json.dumps({"success": False, "error": f"timeout: {exc}"})
    return json.dumps(
        {
            "success": proc.returncode == 0,
            "output": proc.stdout,
            "error": proc.stderr if proc.returncode != 0 else "",
        }
    )


def handle_wiki(params, **kwargs):
    command = (params.get("command") or "").strip()
    rest = params.get("args", "") or ""
    if not command:
        return json.dumps({"success": False, "error": "missing 'command'"})
    script = SESSION_SCRIPT if command in SESSION_COMMANDS else CLI_SCRIPT
    if not script.exists():
        return json.dumps({"success": False, "error": f"script not found: {script}"})
    return _run(script, command, rest)


def register(ctx):
    ctx.register_tool(
        name="wiki",
        toolset="wiki",
        schema={
            "type": "object",
            "properties": {
                "command": {
                    "type": "string",
                    "description": "llm-wiki subcommand: lint|schema|archive|session|feedback",
                },
                "args": {
                    "type": "string",
                    "description": "Remaining CLI args, e.g. '--fix /path/to/wiki' or 'disable'",
                },
            },
            "required": ["command"],
        },
        handler=handle_wiki,
        description=(
            "Run deterministic llm-wiki checks (lint/schema/archive) and session/feedback helpers. "
            "For agentic work (research/query/collect/ingest/compile/audit/output/plan/thesis) "
            "follow the wiki-manager skill."
        ),
    )
