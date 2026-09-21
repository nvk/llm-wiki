"""Deterministic operations exposed by the Hermes llm-wiki plugin."""

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Any, Sequence

_REQUIRED_DIRECTORIES = ("raw", "wiki", "output")


def inspect_wiki(path: str) -> dict[str, Any]:
    """Return a bounded, read-only summary of one topic wiki."""
    root = Path(path).expanduser().resolve(strict=False)
    if not root.is_dir():
        return {
            "path": str(root),
            "exists": False,
            "raw_documents": 0,
            "wiki_articles": 0,
            "missing_required_directories": list(_REQUIRED_DIRECTORIES),
        }

    def count_markdown(directory: Path) -> int:
        return sum(1 for item in directory.rglob("*.md") if item.name != "_index.md") if directory.is_dir() else 0

    return {
        "path": str(root),
        "exists": True,
        "raw_documents": count_markdown(root / "raw"),
        "wiki_articles": count_markdown(root / "wiki"),
        "missing_required_directories": [name for name in _REQUIRED_DIRECTORIES if not (root / name).is_dir()],
    }


def validate_wiki(path: str, command: Sequence[str]) -> dict[str, Any]:
    """Run an explicit argv command against an existing wiki without a shell."""
    root = Path(path).expanduser().resolve(strict=False)
    if not root.is_dir():
        return {"path": str(root), "returncode": 2, "stdout": "", "stderr": "Wiki path is not a directory."}
    try:
        completed = subprocess.run(
            list(command), cwd=root, capture_output=True, text=True, check=False, timeout=120
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"path": str(root), "returncode": 2, "stdout": "", "stderr": str(exc)}
    return {"path": str(root), "returncode": completed.returncode, "stdout": completed.stdout, "stderr": completed.stderr}
