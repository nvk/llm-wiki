from __future__ import annotations

import argparse
import importlib
import importlib.util
import os
import re
import sys
from pathlib import Path


def _engine_candidates():
    """Yield candidate paths for the shared session engine, in priority order.

    Works whether the plugin is symlinked from the repo (README method),
    copied into ~/.hermes/plugins/, or installed as a package. An explicit
    ``LLM_WIKI_ENGINE`` env override wins.
    """
    env = os.environ.get("LLM_WIKI_ENGINE")
    if env:
        yield Path(env)
    here = Path(__file__).resolve()
    # Symlink-from-repo or copied-into-plugins layout: <repo>/plugins/llm-wiki-hermes/...
    yield here.parents[2] / "llm-wiki" / "hooks" / "llm_wiki_session.py"
    # Vendored deep inside ~/.hermes/plugins/llm-wiki-hermes/...
    yield here.parents[1] / "llm-wiki" / "hooks" / "llm_wiki_session.py"
    # Pip-installed package: llm_wiki_session importable directly.
    yield None  # sentinel: try importlib top-level


_engine = None


def _get_engine():
    """Lazily import the shared upstream engine. Returns None on failure (R11).

    Tries, in order: env override, repo-relative path, vendored path, then a
    top-level ``import llm_wiki_session``. If all fail, logs a visible WARNING
    (not silent) so a misconfigured install is diagnosable.
    """
    global _engine
    if _engine is not None:
        return _engine
    loaded = None
    last_exc = None
    for cand in _engine_candidates():
        try:
            if cand is None:
                mod = importlib.import_module("llm_wiki_session")
                loaded = f"import:llm_wiki_session"
            else:
                if not cand.exists():
                    continue
                spec = importlib.util.spec_from_file_location(
                    "llm_wiki_session", str(cand)
                )
                mod = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(mod)
                loaded = str(cand)
            _engine = mod
            break
        except Exception as exc:  # pragma: no cover - defensive
            last_exc = exc
            continue
    if loaded is None:
        # Visible failure, not silent — operator can diagnose.
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

_WIKI_INTENT = re.compile(
    r"\b(wiki|knowledge base|knowledge-base|llm[- ]?wiki|notes|ingest|compile|rehydrat)",
    re.IGNORECASE,
)


def _steer_to_our_skill(user_message: str) -> str:
    """If the turn looks like a wiki request, nudge toward our wiki-manager skill
    (the built-in 'llm-wiki' skill is disabled, but be explicit for robustness)."""
    if not user_message or not _WIKI_INTENT.search(user_message):
        return ""
    return (
        "\n[llm-wiki-hermes] Use the 'wiki-manager' skill "
        "(llm-wiki-hermes:wiki-manager) for wiki/knowledge-base operations."
    )


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


def _parse_article_entry(line):
    """Extract (title, path, summary) from an _index.md line.

    Handles multiple formats resiliently:
      - [[Wikilink]](./wiki/concepts/foo.md) — summary
      - [Markdown](./wiki/concepts/foo.md) — summary
      - | [slug](topics/slug/_index.md) | Title | Description |
    Returns None when the line doesn't contain an article entry.
    """
    # Wikilink or markdown link: [[Title]](path) or [Title](path)
    m = re.search(r"\[\[?([^\]]+)\]\]?\(([^)]+)\)", line)
    if m:
        title = m.group(1).strip()
        rel = m.group(2).strip()
        summary = line[m.end() :].lstrip(" —-:").strip()
        return title, rel, summary
    # Table row: | [slug](topics/slug/...) | Title | Description |
    m = re.search(r"\|.*?\[[^\]]*\]\([^)]+\)\s*\|\s*([^|]*)\|\s*([^|]*)", line)
    if m:
        title = m.group(1).strip()
        summary = m.group(2).strip()
        pm = re.search(r"\(([^)]+)\)", line)
        rel = pm.group(1).strip() if pm else ""
        return title, rel, summary
    return None


def _score_articles(hub, query, limit):
    q_tokens = TOKEN_RE.findall(query.lower())
    q_set = {t for t in q_tokens if t not in STOPWORDS}
    if not q_set:
        return []
    hub_index = _read_text(hub / "_index.md")
    slugs = re.findall(r"topics/([^/\s)]+)", hub_index)
    slugs = [s for s in dict.fromkeys(slugs) if not s.startswith(".")]
    if not slugs:
        # Fallback: enumerate topics/ directory
        topics_dir = hub / "topics"
        if topics_dir.is_dir():
            slugs = [
                d.name
                for d in topics_dir.iterdir()
                if d.is_dir() and not d.name.startswith(".")
            ]
    scored = []
    for slug in slugs:
        topic = hub / "topics" / slug
        if not topic.is_dir():
            continue
        for line in _read_text(topic / "_index.md").splitlines():
            entry = _parse_article_entry(line)
            if entry is None:
                continue
            title, rel, summary = entry
            if not rel:
                continue
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
        if rel not in seen:
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
    steer = _steer_to_our_skill(user_message or "")
    combined = "\n\n".join(p for p in (rehydrate, memory, steer) if p).strip()
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
        tool_output = (
            tool_output[:1200] + f"\n[... truncated from {len(tool_output)} chars]"
        )
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
