"""Hermes handlers for llm-wiki's read-only deterministic operations."""

from __future__ import annotations

import json
import os
from pathlib import Path

from .llm_wiki_tools import inspect_wiki, validate_wiki


def _lint_command() -> list[str] | None:
    configured = os.environ.get("LLM_WIKI_CLI")
    if configured:
        return [configured, "lint", "--json"]
    source_checkout_cli = Path(__file__).resolve().parents[2] / "scripts" / "llm-wiki"
    return [str(source_checkout_cli), "lint", "--json"] if source_checkout_cli.is_file() else None


def llm_wiki_status(args: dict, **kwargs: object) -> str:
    """Return a JSON summary for one topic wiki."""
    try:
        return json.dumps(inspect_wiki(str(args.get("path", ""))), sort_keys=True)
    except Exception as exc:
        return json.dumps({"error": str(exc)})


def llm_wiki_lint(args: dict, **kwargs: object) -> str:
    """Run the existing deterministic lint command without a shell."""
    try:
        command = _lint_command()
        if command is None:
            return json.dumps({"error": "Set LLM_WIKI_CLI to the llm-wiki executable before linting."})
        return json.dumps(validate_wiki(str(args.get("path", "")), command), sort_keys=True)
    except Exception as exc:
        return json.dumps({"error": str(exc)})
