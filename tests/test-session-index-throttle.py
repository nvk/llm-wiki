#!/usr/bin/env python3
"""Check that hook index rebuilds are throttled by index freshness."""

from __future__ import annotations

import importlib.machinery
import importlib.util
import os
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SESSION = ROOT / "scripts" / "llm-wiki-session"

FAILURES: list[str] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"PASS: {name}")
    else:
        FAILURES.append(f"{name}: {detail}")
        print(f"FAIL: {name} - {detail}")


def load_session_module():
    loader = importlib.machinery.SourceFileLoader("llm_wiki_session_under_test", str(SESSION))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def make_root() -> Path:
    override = os.environ.get("LLM_WIKI_TEST_ROOT")
    if override:
        return Path(override)
    parent = os.environ.get("LLM_WIKI_TEST_DIR")
    return Path(tempfile.mkdtemp(prefix="llm-wiki-throttle-", dir=parent))


def main() -> int:
    module = load_session_module()
    root = make_root()
    index_path = root / "indexes" / "sessions.json"

    check("missing index is not recent", module.indexes_recent(root, {}) is False)

    index_path.parent.mkdir(parents=True, exist_ok=True)
    index_path.write_text("{}\n", encoding="utf-8")
    check("fresh index is recent", module.indexes_recent(root, {}) is True)
    check("explicit interval is honoured", module.indexes_recent(root, {"index_rebuild_min_interval": 300}) is True)

    old = time.time() - 600
    os.utime(index_path, (old, old))
    check("stale index is not recent", module.indexes_recent(root, {}) is False)
    check("zero interval disables the throttle", module.indexes_recent(root, {"index_rebuild_min_interval": 0}) is False)

    index_path.unlink()
    if not os.environ.get("LLM_WIKI_TEST_ROOT"):
        index_path.parent.rmdir()
        root.rmdir()

    if FAILURES:
        print("\n".join(FAILURES), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
