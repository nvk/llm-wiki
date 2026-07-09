from __future__ import annotations

import argparse
import importlib.util
import os
import sys
from pathlib import Path

ENGINE_PATH = (
    Path(__file__).resolve().parents[2] / "llm-wiki" / "hooks" / "llm_wiki_session.py"
)

_engine = None


def _get_engine():
    """Lazily import the shared upstream engine. Returns None on failure (R11)."""
    global _engine
    if _engine is None:
        try:
            spec = importlib.util.spec_from_file_location(
                "llm_wiki_session", str(ENGINE_PATH)
            )
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            _engine = mod
        except Exception as exc:  # pragma: no cover - defensive
            print(f"[llm-wiki-hermes] engine import failed: {exc}", file=sys.stderr)
            _engine = None
    return _engine


def _args(event_name, session_id, cwd, hub=None):
    return argparse.Namespace(
        harness="hermes",
        event_name=event_name,
        session_id=session_id,
        cwd=cwd,
        topic=None,
        summary=None,
        max_event_bytes=None,
        if_enabled=True,
        hub=hub,
        local=False,
    )


def _payload(**fields):
    return {k: v for k, v in fields.items() if v is not None}


def _capture(event_name, payload, cwd, session_id=None, hub=None):
    engine = _get_engine()
    if engine is None:
        return ""
    try:
        args = _args(event_name, session_id, cwd, hub=hub)
        return engine.handle_event(args, payload) or ""
    except Exception as exc:  # pragma: no cover - defensive (R11)
        print(f"[llm-wiki-hermes] hook error ({event_name}): {exc}", file=sys.stderr)
        return ""


def on_session_start(
    session_id=None,
    carry_over_context=None,
    platform=None,
    model=None,
    cwd=None,
    **kwargs,
):
    cwd = cwd or os.getcwd()
    payload = _payload(
        session_id=session_id, model=model, user_prompt=carry_over_context
    )
    return _capture("SessionStart", payload, cwd, session_id=session_id) or None


def pre_llm_call(
    session_id=None,
    turn_id=None,
    user_message="",
    model=None,
    is_first_turn=False,
    cwd=None,
    **kwargs,
):
    cwd = cwd or os.getcwd()
    payload = _payload(
        session_id=session_id, turn_id=turn_id, model=model, user_prompt=user_message
    )
    return _capture("UserPromptSubmit", payload, cwd, session_id=session_id) or None


def post_tool_call(
    tool_name=None,
    args=None,
    result=None,
    session_id=None,
    tool_call_id=None,
    turn_id=None,
    duration_ms=None,
    status=None,
    error_message=None,
    cwd=None,
    model=None,
    **kwargs,
):
    tool_args = args
    cwd = cwd or os.getcwd()
    tool_output = (
        result
        if isinstance(result, str)
        else (str(result) if result is not None else "")
    )
    if len(tool_output) > 1200:
        tool_output = tool_output[:1200]
    payload = _payload(
        session_id=session_id,
        turn_id=turn_id,
        model=model,
        tool_name=tool_name,
        tool_output=tool_output,
        tool_use_id=tool_call_id,
        duration_ms=duration_ms,
        status=status,
        error_message=error_message,
        args=tool_args,
    )
    _capture("PostToolUse", payload, cwd, session_id=session_id)
    return None


def on_session_finalize(session_id=None, reason=None, cwd=None, model=None, **kwargs):
    cwd = cwd or os.getcwd()
    payload = _payload(session_id=session_id, reason=reason, model=model)
    _capture("PreCompact", payload, cwd, session_id=session_id)
    return None


def on_session_end(
    session_id=None,
    completed=None,
    interrupted=None,
    reason=None,
    model=None,
    cwd=None,
    **kwargs,
):
    cwd = cwd or os.getcwd()
    payload = _payload(
        session_id=session_id,
        completed=completed,
        interrupted=interrupted,
        reason=reason,
        model=model,
    )
    _capture("SessionEnd", payload, cwd, session_id=session_id)
    return None
