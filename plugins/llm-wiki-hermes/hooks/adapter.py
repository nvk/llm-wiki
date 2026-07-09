from __future__ import annotations

import argparse
import importlib.util
import os
import re
import sys
from pathlib import Path

ENGINE_PATH = Path(__file__).resolve().parents[2] / "scripts" / "llm-wiki-session"
ENGINE_PATH_FALLBACK = (
    Path(__file__).resolve().parents[2] / "llm-wiki" / "hooks" / "llm_wiki_session.py"
)

_engine = None


def _get_engine():
    """Lazily import the shared upstream engine. Returns None on failure (R11).

    Prefers the source engine at the repo root ``scripts/llm-wiki-session`` and
    falls back to the generated Codex mirror under ``llm-wiki/hooks/``.
    """
    global _engine
    if _engine is None:
        candidates = [ENGINE_PATH, ENGINE_PATH_FALLBACK]
        loaded = None
        last_exc = None
        for path in candidates:
            if not path.exists():
                continue
            try:
                spec = importlib.util.spec_from_file_location(
                    "llm_wiki_session", str(path)
                )
                mod = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(mod)
                loaded = path
                _engine = mod
                break
            except Exception as exc:  # pragma: no cover - defensive
                last_exc = exc
                continue
        if loaded is None:
            print(
                f"[llm-wiki-hermes] engine import failed: {last_exc}",
                file=sys.stderr,
            )
            _engine = None
        else:
            print(
                f"[llm-wiki-hermes] engine loaded from {loaded}",
                file=sys.stderr,
            )
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


MEMORY_LIMIT = 3
MEMORY_CFG_KEY = "memory"
MEMORY_ENV_DISABLE = "LLM_WIKI_HERMES_MEMORY"

TOKEN_RE = re.compile(r"[a-z0-9]+")
STOPWORDS = {
    "the",
    "a",
    "an",
    "and",
    "or",
    "of",
    "to",
    "in",
    "on",
    "for",
    "with",
    "is",
    "are",
    "was",
    "were",
    "be",
    "by",
    "as",
    "at",
    "that",
    "this",
    "it",
    "from",
    "we",
    "you",
    "i",
    "our",
    "your",
    "do",
    "does",
    "did",
}


def _read_text(path):
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return ""


def _score_articles(hub, query, limit):
    q_tokens = TOKEN_RE.findall(query.lower())
    q_set = {t for t in q_tokens if t not in STOPWORDS}
    if not q_set:
        return []
    hub_index = _read_text(hub / "_index.md")
    slugs = re.findall(r"topics/([A-Za-z0-9._-]+)/", hub_index)
    slugs = [s for s in dict.fromkeys(slugs) if not s.startswith(".")]
    scored = []
    for slug in slugs:
        topic = hub / "topics" / slug
        if not topic.is_dir():
            continue
        for line in _read_text(topic / "_index.md").splitlines():
            m = re.search(r"\[([^\]]+)\]\(([^)]+)\)", line)
            if not m:
                continue
            title = m.group(1).strip()
            rel = m.group(2).strip()
            summary = line[m.end() :].lstrip(" —-:").strip()
            hay = (title + " " + summary).lower()
            score = sum(1 for tok in q_set if tok in hay)
            title_hits = len(q_set & set(TOKEN_RE.findall(title.lower())))
            score += title_hits * 2
            if score > 0:
                scored.append((score, title, rel, summary))
    scored.sort(key=lambda x: x[0], reverse=True)
    seen = set()
    out = []
    for _score, title, rel, summary in scored:
        if rel in seen:
            continue
        seen.add(rel)
        out.append((title, rel, summary))
        if len(out) >= limit:
            break
    return out


def retrieve_wiki_context(cwd=None, query="", limit=MEMORY_LIMIT):
    engine = _get_engine()
    if engine is None or not query:
        return ""
    if os.environ.get(MEMORY_ENV_DISABLE, "").strip() in ("0", "false", "no"):
        return ""
    try:
        hub = engine.resolve_hub(argparse.Namespace(hub=None, local=False))
        root = engine.sessions_dir(hub)
        config = engine.load_config(root)
        mem_cfg = (
            config.get(MEMORY_CFG_KEY)
            if isinstance(config.get(MEMORY_CFG_KEY), dict)
            else {}
        )
        if mem_cfg.get("inject", True) is False:
            return ""
        limit = int(mem_cfg.get("limit", limit) or limit)
        candidates = _score_articles(hub, query, limit)
        if not candidates:
            return ""
        lines = ["llm-wiki memory — relevant notes from your knowledge base:"]
        for title, rel, summary in candidates:
            line = f"- [{title}]({rel})"
            if summary:
                line += f" — {summary}"
            lines.append(line)
        return "\n".join(lines)
    except Exception as exc:  # pragma: no cover - defensive (R11)
        print(f"[llm-wiki-hermes] memory retrieval error: {exc}", file=sys.stderr)
        return ""


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
    carry_over_context = (
        carry_over_context
        or kwargs.get("message")
        or kwargs.get("prompt")
        or kwargs.get("content")
    )
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
    user_message = (
        user_message
        or kwargs.get("message")
        or kwargs.get("prompt")
        or kwargs.get("content")
        or ""
    )
    cwd = cwd or os.getcwd()
    payload = _payload(
        session_id=session_id, turn_id=turn_id, model=model, user_prompt=user_message
    )
    rehydrate = _capture("UserPromptSubmit", payload, cwd, session_id=session_id)
    memory = retrieve_wiki_context(cwd=cwd, query=user_message or "")
    combined = "\n\n".join(p for p in (rehydrate, memory) if p).strip()
    return combined or None


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
