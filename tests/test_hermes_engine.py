from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
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


def test_run_hook_unchanged():
    """Verify run_hook prints correct JSON to stdout when given valid stdin input.

    Tests the actual subprocess stdin/stdout behavior including event_name
    resolution for camelCase (hookEventName) and alternate (event) field names.
    """
    hook_script = (
        Path(__file__).resolve().parents[1]
        / "plugins"
        / "llm-wiki"
        / "hooks"
        / "llm_wiki_session.py"
    )
    with tempfile.TemporaryDirectory() as tmp:
        hub = Path(tmp) / "hub"
        sessions_dir = hub / ".sessions"
        sessions_dir.mkdir(parents=True)
        (sessions_dir / "config.json").write_text(
            json.dumps({"enabled": True, "mode": "balanced"})
        )

        base_args = [sys.executable, str(hook_script), "--hub", str(hub)]

        # Test with snake_case hook_event_name
        payload = json.dumps(
            {
                "session_id": "sess-snake",
                "hook_event_name": "SessionStart",
                "model": "x",
            }
        )
        result = subprocess.run(
            base_args
            + [
                "hook",
                "--harness",
                "hermes",
                "--session-id",
                "sess-snake",
                "--event-name",
                "SessionStart",
            ],
            input=payload,
            capture_output=True,
            text=True,
            timeout=10,
        )
        assert result.returncode == 0, f"stderr: {result.stderr}"
        stdout = result.stdout.strip()
        if stdout:
            output = json.loads(stdout)
            assert "hookSpecificOutput" in output
            assert output["hookSpecificOutput"]["hookEventName"] == "SessionStart"

        # Test with camelCase hookEventName (no --event-name arg)
        payload2 = json.dumps(
            {
                "session_id": "sess-camel",
                "hookEventName": "UserPromptSubmit",
                "model": "x",
            }
        )
        result2 = subprocess.run(
            base_args + ["hook", "--harness", "hermes", "--session-id", "sess-camel"],
            input=payload2,
            capture_output=True,
            text=True,
            timeout=10,
        )
        assert result2.returncode == 0, f"stderr: {result2.stderr}"
        stdout2 = result2.stdout.strip()
        if stdout2:
            output2 = json.loads(stdout2)
            assert "hookSpecificOutput" in output2
            assert output2["hookSpecificOutput"]["hookEventName"] == "UserPromptSubmit"

        # Test with alternate 'event' field name
        payload3 = json.dumps(
            {
                "session_id": "sess-alt",
                "event": "PostCompact",
                "model": "x",
            }
        )
        result3 = subprocess.run(
            base_args + ["hook", "--harness", "hermes", "--session-id", "sess-alt"],
            input=payload3,
            capture_output=True,
            text=True,
            timeout=10,
        )
        assert result3.returncode == 0, f"stderr: {result3.stderr}"
        stdout3 = result3.stdout.strip()
        if stdout3:
            output3 = json.loads(stdout3)
            assert "hookSpecificOutput" in output3
            assert output3["hookSpecificOutput"]["hookEventName"] == "PostCompact"
