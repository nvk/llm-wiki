"""Map Hermes lifecycle hooks into the shared llm-wiki session engine."""

from __future__ import annotations

import argparse
import importlib.machinery
import importlib.util
import logging
import os
from pathlib import Path
from typing import Any

logger = logging.getLogger("llm-wiki-hermes")

_engine = None
_engine_attempted = False


def _session_script_candidates():
    override = os.environ.get("LLM_WIKI_SESSION_SCRIPT")
    if override:
        yield Path(override).expanduser()
    # Expected install: this plugin is symlinked from a persistent llm-wiki
    # checkout, so resolving __file__ returns <repo>/plugins/.../adapter.py.
    repo_root = Path(__file__).resolve().parents[2]
    yield repo_root / "plugins" / "llm-wiki" / "hooks" / "llm_wiki_session.py"
    yield repo_root / "scripts" / "llm-wiki-session"


def _get_engine():
    """Load the shared engine once; return None when the checkout is incomplete."""
    global _engine, _engine_attempted
    if _engine_attempted:
        return _engine
    _engine_attempted = True

    for path in _session_script_candidates():
        if not path.is_file():
            continue
        try:
            loader = importlib.machinery.SourceFileLoader(
                "llm_wiki_hermes_session_engine", str(path)
            )
            spec = importlib.util.spec_from_loader(loader.name, loader)
            if spec is None or spec.loader is None:
                continue
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            if not hasattr(module, "handle_event"):
                logger.warning("llm-wiki session engine lacks handle_event: %s", path)
                continue
            _engine = module
            return _engine
        except Exception as exc:  # pragma: no cover - defensive runtime guard
            logger.warning("failed to load llm-wiki session engine %s: %s", path, exc)

    logger.warning(
        "llm-wiki session engine not found; symlink the plugin from a full "
        "checkout or set LLM_WIKI_SESSION_SCRIPT"
    )
    return None


def _event_args(engine, event_name: str, session_id: str | None, cwd: str):
    return argparse.Namespace(
        harness="hermes",
        event_name=event_name,
        session_id=session_id,
        cwd=cwd,
        topic=None,
        summary=None,
        trigger=None,
        max_event_bytes=engine.MAX_EVENT_PREVIEW_CHARS,
        if_enabled=True,
        hub=None,
        local=False,
    )


def _first(value, *alternatives):
    if value not in (None, ""):
        return value
    return next((item for item in alternatives if item not in (None, "")), None)


def _capture(
    event_name: str,
    *,
    session_id: str | None,
    cwd: str | None,
    payload: dict[str, Any],
) -> str:
    engine = _get_engine()
    if engine is None:
        return ""
    resolved_cwd = cwd or os.getcwd()
    try:
        return engine.handle_event(
            _event_args(engine, event_name, session_id, resolved_cwd), payload
        )
    except engine.HookSkip:
        return ""
    except Exception as exc:  # pragma: no cover - never break the host harness
        logger.warning("llm-wiki %s hook failed: %s", event_name, exc)
        return ""


def on_session_start(
    session_id=None,
    task_id=None,
    carry_over_context=None,
    model=None,
    cwd=None,
    **kwargs,
):
    native_id = _first(session_id, task_id, kwargs.get("conversation_id"))
    prompt = _first(
        carry_over_context,
        kwargs.get("user_message"),
        kwargs.get("message"),
    )
    _capture(
        "SessionStart",
        session_id=native_id,
        cwd=cwd,
        payload={
            "session_id": native_id,
            "model": model,
            "user_prompt": prompt,
        },
    )
    # Hermes discards context returned by on_session_start. Rehydration is
    # returned from pre_llm_call instead.
    return None


def pre_llm_call(
    session_id=None,
    task_id=None,
    turn_id=None,
    user_message="",
    model=None,
    cwd=None,
    **kwargs,
):
    native_id = _first(session_id, task_id, kwargs.get("conversation_id"))
    prompt = _first(
        user_message,
        kwargs.get("message"),
        kwargs.get("prompt"),
        kwargs.get("content"),
    ) or ""
    context = _capture(
        "UserPromptSubmit",
        session_id=native_id,
        cwd=cwd,
        payload={
            "session_id": native_id,
            "turn_id": turn_id,
            "model": model,
            "user_prompt": prompt,
        },
    )
    return context or None


def post_tool_call(
    tool_name=None,
    args=None,
    result=None,
    session_id=None,
    task_id=None,
    tool_call_id=None,
    turn_id=None,
    cwd=None,
    model=None,
    **kwargs,
):
    native_id = _first(session_id, task_id, kwargs.get("conversation_id"))
    _capture(
        "PostToolUse",
        session_id=native_id,
        cwd=cwd,
        payload={
            "session_id": native_id,
            "turn_id": turn_id,
            "model": model,
            "tool_name": tool_name,
            "tool_use_id": tool_call_id,
            "args": args,
            "tool_output": result,
        },
    )
    return None


def on_session_finalize(
    session_id=None, task_id=None, reason=None, cwd=None, model=None, **kwargs
):
    native_id = _first(session_id, task_id, kwargs.get("conversation_id"))
    _capture(
        "PreCompact",
        session_id=native_id,
        cwd=cwd,
        payload={"session_id": native_id, "reason": reason, "model": model},
    )
    return None


def on_session_end(
    session_id=None,
    task_id=None,
    reason=None,
    completed=None,
    interrupted=None,
    cwd=None,
    model=None,
    **kwargs,
):
    native_id = _first(session_id, task_id, kwargs.get("conversation_id"))
    _capture(
        "SessionEnd",
        session_id=native_id,
        cwd=cwd,
        payload={
            "session_id": native_id,
            "reason": reason,
            "completed": completed,
            "interrupted": interrupted,
            "model": model,
        },
    )
    return None
