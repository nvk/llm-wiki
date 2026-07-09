from __future__ import annotations

import importlib.util
import types
from pathlib import Path
from unittest import mock

import pytest

_adapter_path = (
    Path(__file__).resolve().parents[1]
    / "plugins"
    / "llm-wiki-hermes"
    / "hooks"
    / "adapter.py"
)
_spec = importlib.util.spec_from_file_location("adapter", str(_adapter_path))
adapter_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(adapter_mod)


def _fake_engine(hub_root, rehydrate_return=""):
    eng = types.SimpleNamespace()
    eng.resolve_hub = lambda args: hub_root
    eng.sessions_dir = lambda hub: hub / ".sessions"
    eng.load_config = lambda root: {
        "enabled": True,
        "rehydrate": {"session_start": True, "user_prompt": True},
    }
    calls = []

    def handle_event(args, payload):
        calls.append((args, payload))
        state_dir = hub_root / ".sessions" / "state" / "hermes"
        state_dir.mkdir(parents=True, exist_ok=True)
        (state_dir / f"{args.session_id or 'x'}.json").write_text("{}")
        return rehydrate_return

    eng.handle_event = handle_event
    eng._calls = calls
    return eng


@pytest.fixture
def fake_engine(tmp_path):
    eng = _fake_engine(tmp_path / "hub", rehydrate_return="REHYDRATE_CTX")
    with mock.patch.object(adapter_mod, "_get_engine", return_value=eng):
        yield eng


def test_on_session_start_maps_and_returns_rehydrate(fake_engine):
    out = adapter_mod.on_session_start(session_id="s1", model="m", cwd="/x")
    assert out == "REHYDRATE_CTX"
    args, payload = fake_engine._calls[0]
    assert args.event_name == "SessionStart"
    assert args.harness == "hermes"
    assert payload["session_id"] == "s1"


def test_pre_llm_call_maps_user_prompt(fake_engine):
    out = adapter_mod.pre_llm_call(
        session_id="s2", turn_id="t1", user_message="hello", model="m", cwd="/x"
    )
    assert out == "REHYDRATE_CTX"
    args, payload = fake_engine._calls[0]
    assert args.event_name == "UserPromptSubmit"
    assert payload["user_prompt"] == "hello"
    assert payload["turn_id"] == "t1"


def test_post_tool_call_truncates_tool_output(fake_engine):
    big = "x" * 5000
    out = adapter_mod.post_tool_call(
        tool_name="terminal",
        args={"cmd": "ls"},
        result=big,
        session_id="s3",
        tool_call_id="tc1",
        cwd="/x",
    )
    assert out is None
    args, payload = fake_engine._calls[0]
    assert args.event_name == "PostToolUse"
    assert payload["tool_name"] == "terminal"
    assert payload["tool_use_id"] == "tc1"
    assert len(payload["tool_output"]) == 1200


def test_on_session_finalize_maps_precompact(fake_engine):
    adapter_mod.on_session_finalize(session_id="s4", reason="compress", cwd="/x")
    args, payload = fake_engine._calls[0]
    assert args.event_name == "PreCompact"
    assert payload["reason"] == "compress"


def test_on_session_end_maps_sessionend(fake_engine):
    adapter_mod.on_session_end(
        session_id="s5",
        completed=True,
        interrupted=False,
        reason="done",
        model="m",
        cwd="/x",
    )
    args, payload = fake_engine._calls[0]
    assert args.event_name == "SessionEnd"
    assert payload["completed"] is True


def test_hook_exception_is_swallowed(fake_engine):
    bad = _fake_engine(fake_engine.__dict__ and Path("/tmp"), rehydrate_return="")
    bad.handle_event = mock.Mock(side_effect=RuntimeError("boom"))
    with mock.patch.object(adapter_mod, "_get_engine", return_value=bad):
        assert (
            adapter_mod.pre_llm_call(session_id="z", user_message="q", cwd="/x") is None
        )
