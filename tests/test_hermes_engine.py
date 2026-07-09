from __future__ import annotations

import importlib.util
import json
import tempfile
from pathlib import Path

import pytest


def _load_engine():
    path = (
        Path(__file__).resolve().parents[1]
        / "plugins"
        / "llm-wiki"
        / "hooks"
        / "llm_wiki_session.py"
    )
    spec = importlib.util.spec_from_file_location("llm_wiki_session_eng", str(path))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _args(hub, event_name, session_id):
    return __import__("argparse").Namespace(
        harness="hermes",
        event_name=event_name,
        session_id=session_id,
        cwd="/tmp",
        topic=None,
        summary=None,
        max_event_bytes=None,
        if_enabled=True,
        hub=str(hub),
        local=False,
    )


def test_handle_event_returns_string_and_writes_state():
    engine = _load_engine()
    with tempfile.TemporaryDirectory() as tmp:
        hub = Path(tmp) / "hub"
        args = _args(hub, "SessionStart", "sess-123")
        payload = {"session_id": "sess-123", "model": "x", "user_prompt": ""}
        result = engine.handle_event(args, payload)
        assert isinstance(result, str)  # returns context (may be "")
        state_file = hub / ".sessions" / "state" / "hermes" / "sess-123.json"
        assert state_file.exists(), "state file must be written in-process"
        data = json.loads(state_file.read_text())
        assert data["harness"] == "hermes"
        assert data["native_session_id"] == "sess-123"


def test_handle_event_disabled_is_noop():
    engine = _load_engine()
    with tempfile.TemporaryDirectory() as tmp:
        hub = Path(tmp) / "hub"
        (hub / ".sessions").mkdir(parents=True)
        (hub / ".sessions" / "config.json").write_text(json.dumps({"enabled": False}))
        args = _args(hub, "SessionStart", "sess-off")
        # HookSkip is raised when disabled; run_hook would catch it, handle_event surfaces it.
        with pytest.raises(Exception):
            engine.handle_event(args, {"session_id": "sess-off"})
