# Hermes Plugin for nvk/llm-wiki — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a first-class Hermes (NousResearch/hermes-agent) plugin to `nvk/llm-wiki` that mirrors the Claude Code / Codex adapters (session capture + rehydration hooks, a deterministic `wiki` tool, the full wiki-manager skill) and adds a net-new proactive wiki-as-memory injection on each user prompt.

**Architecture:** A single shared engine (`plugins/llm-wiki/hooks/llm_wiki_session.py`) is refactored to expose a payload-based `handle_event(args, payload)` entrypoint. A new plugin directory `plugins/llm-wiki-hermes/` imports that engine in-process and registers 5 Hermes hooks (calling `handle_event`), a `wiki` router tool (wrapping the existing `scripts/llm-wiki` + `scripts/llm-wiki-session` binaries), and a copy of the wiki-manager skill. `pre_llm_call` additionally matches the user message against wiki indexes and injects top-N relevant article pointers as memory.

**Tech Stack:** Python 3.9+ (stdlib only: `argparse`, `json`, `subprocess`, `importlib.util`, `pathlib`, `os`, `re`, `sys`, `shlex`). Bash for the runtime test + CI workflow edits.

## Global Constraints

- **Python 3.9+** — every new `.py` starts with `from __future__ import annotations`; no 3.10+ syntax (`X | Y` at runtime, `match`).
- **Stdlib only** — no new third-party dependencies. Reuse the shared engine module; do not reimplement wiki logic.
- **Do NOT hand-edit** `plugins/llm-wiki/` or `plugins/llm-wiki-opencode/` — they are generated; drift tests (`test-codex-sync.sh`, `test-opencode-sync.sh`) will fail.
- **Version** — `plugins/llm-wiki-hermes/plugin.yaml` `version:` MUST equal `0.15.0` (repo-wide version).
- **Behavior parity** — `run_hook` (Claude/Codex subprocess path) MUST remain byte-for-byte equivalent in stdout; the refactor is internal only (proven by `test-session-capture.sh` staying green).
- **Never block the agent** — every hook is wrapped so any exception degrades to a stderr log + `None`/empty, never a raised error into the harness.
- **Branch** — all work on branch `feat/hermes-plugin` (already created, pushed to fork `dfein38347g/llm-wiki`).

---

## File Structure

**Created**
- `plugins/llm-wiki-hermes/plugin.yaml` — Hermes manifest (name, version, hooks list).
- `plugins/llm-wiki-hermes/__init__.py` — `register(ctx)` wiring hooks + tool.
- `plugins/llm-wiki-hermes/hooks/__init__.py` — package marker.
- `plugins/llm-wiki-hermes/hooks/adapter.py` — engine import, payload mapping, 5 hook fns, wiki-as-memory retrieval.
- `plugins/llm-wiki-hermes/tools.py` — `wiki` router tool wrapping the deterministic CLI scripts.
- `plugins/llm-wiki-hermes/skills/wiki-manager/SKILL.md` — verbatim copy of `claude-plugin/skills/wiki-manager/SKILL.md`.
- `plugins/llm-wiki-hermes/skills/wiki-manager/references/*.md` — verbatim copies.
- `plugins/llm-wiki-hermes/tests/__init__.py` — package marker.
- `plugins/llm-wiki-hermes/tests/test_adapter.py` — unit tests for adapter + memory.
- `tests/test_hermes_engine.py` — in-process engine test (proves `handle_event` works without subprocess).
- `tests/test-hermes-runtime.sh` — bash runtime test driving the adapter.

**Modified**
- `plugins/llm-wiki/hooks/llm_wiki_session.py` — extract `handle_event`; `run_hook` becomes a thin wrapper.
- `tests/test-plugin-validate.sh` — add a "Hermes Mirror Validation" block.
- `tests/ci/plugin-tests.yml` — add `plugins/llm-wiki-hermes/**` + `tests/test-hermes-runtime.sh` to `paths:`; add a runtime step.
- `README.md` — Supported clients row, Install section, session-capture line.

---

### Task 1: Refactor engine to expose `handle_event`

**Files:**
- Modify: `plugins/llm-wiki/hooks/llm_wiki_session.py` (`def run_hook`, lines ~1042-1090)
- Test: `tests/test_hermes_engine.py`

**Interfaces:**
- Produces: `def handle_event(args, payload) -> str` (returns rehydrate context, may be `""`); `run_hook(args) -> int` unchanged in behavior.

- [ ] **Step 1: Write the failing engine test**

Create `tests/test_hermes_engine.py`:

```python
from __future__ import annotations

import importlib.util
import json
import tempfile
from pathlib import Path

import pytest


def _load_engine():
    path = Path(__file__).resolve().parents[1] / "plugins" / "llm-wiki" / "hooks" / "llm_wiki_session.py"
    spec = importlib.util.spec_from_file_location("llm_wiki_session_eng", str(path))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _args(hub, event_name, session_id):
    return __import__("argparse").Namespace(
        harness="hermes", event_name=event_name, session_id=session_id,
        cwd="/tmp", topic=None, summary=None, max_event_bytes=None,
        if_enabled=True, hub=str(hub), local=False,
    )


def test_handle_event_returns_string_and_writes_state():
    engine = _load_engine()
    with tempfile.TemporaryDirectory() as tmp:
        hub = Path(tmp) / "hub"
        args = _args(hub, "SessionStart", "sess-123")
        payload = {"session_id": "sess-123", "model": "x", "user_prompt": ""}
        result = engine.handle_event(args, payload)
        assert isinstance(result, str)          # returns context (may be "")
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /tmp/opencode/llm-wiki-upstream && python3 -m pytest tests/test_hermes_engine.py -v`
Expected: FAIL — `AttributeError: module 'llm_wiki_session_eng' has no attribute 'handle_event'`.

- [ ] **Step 3: Implement `handle_event` and slim `run_hook`**

In `plugins/llm-wiki/hooks/llm_wiki_session.py`, REPLACE the entire `def run_hook(args: argparse.Namespace) -> int:` function (currently lines 1042-1090) with:

```python
def handle_event(args: argparse.Namespace, payload: dict[str, Any]) -> str:
    """Record a harness hook event and return any injectable context string.

    Returns the rehydrate context (may be "") instead of printing it, so
    in-process callers (e.g. Hermes) can inject it without parsing stdout.
    """
    root = sessions_dir(resolve_hub(args))
    config = load_config(root)
    if args.if_enabled and not config.get("enabled"):
        raise HookSkip()
    ensure_layout(root)
    event = normalize_event(args, payload, root)
    append_jsonl(event_queue_path(root, event), event)
    state, is_new = update_state(root, event, config)
    maybe_record_feedback_candidate(root, state, event, payload, config)
    if is_new:
        append_jsonl(
            root / "registry.jsonl",
            {
                "schema_version": SCHEMA_VERSION,
                "ts": event["ts"],
                "event": "session_seen",
                "llm_wiki_session_id": event["llm_wiki_session_id"],
                "harness": event["harness"],
                "native_session_id": event["native_session_id"],
                "cwd": event.get("cwd"),
                "transcript_path": event.get("transcript_path"),
            },
        )
    write, trigger = should_write_digest(state, event, config, force=False)
    if write:
        write_digest(root, state, trigger)
    else:
        rebuild_indexes(root)

    event_name = str(event.get("hook_event_name") or "")
    rehydrate_cfg = config.get("rehydrate") if isinstance(config.get("rehydrate"), dict) else {}
    context = ""
    if event_name == "SessionStart" and rehydrate_cfg.get("session_start"):
        context = build_rehydrate_context(root, cwd=event.get("cwd"), limit=3)
    elif event_name == "UserPromptSubmit" and rehydrate_cfg.get("user_prompt"):
        context = build_rehydrate_context(root, cwd=event.get("cwd"), limit=3)
    return context


def run_hook(args: argparse.Namespace) -> int:
    raw = sys.stdin.read()
    payload: dict[str, Any]
    if raw.strip():
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise SystemExit(f"invalid hook JSON input: {exc}") from exc
        if not isinstance(parsed, dict):
            raise SystemExit("hook JSON input must be an object")
        payload = parsed
    else:
        payload = {}
    context = handle_event(args, payload)
    if context:
        event_name = str(payload.get("hook_event_name") or getattr(args, "event_name", "") or "")
        hook_output(event_name, context)
    return 0
```

- [ ] **Step 4: Run the engine test to verify it passes**

Run: `cd /tmp/opencode/llm-wiki-upstream && python3 -m pytest tests/test_hermes_engine.py -v`
Expected: PASS (2 passed).

- [ ] **Step 5: Prove no behavior change — run the upstream session capture suite**

Run: `cd /tmp/opencode/llm-wiki-upstream && ./tests/test-session-capture.sh && ./tests/test-session-concurrency.sh`
Expected: both exit 0 (no FAIL lines).

- [ ] **Step 6: Commit**

```bash
cd /tmp/opencode/llm-wiki-upstream
git add plugins/llm-wiki/hooks/llm_wiki_session.py tests/test_hermes_engine.py
git commit -m "refactor: expose handle_event(args, payload) for in-process callers"
```

---

### Task 2: Plugin skeleton — manifest, register, package markers

**Files:**
- Create: `plugins/llm-wiki-hermes/plugin.yaml`
- Create: `plugins/llm-wiki-hermes/__init__.py`
- Create: `plugins/llm-wiki-hermes/hooks/__init__.py`
- Create: `plugins/llm-wiki-hermes/tests/__init__.py`

**Interfaces:**
- Produces: `register(ctx)` entrypoint Hermes calls; `ctx.register_hook(name, fn)` and `tools.register(ctx)`.

- [ ] **Step 1: Create `plugin.yaml`**

```yaml
name: llm-wiki-hermes
manifest_version: 1
version: 0.15.0
description: >
  LLM-compiled knowledge bases for the Hermes agent. Session capture + rehydration
  hooks, a wiki tool for deterministic checks, and proactive wiki-as-memory
  injection, with the full wiki-manager skill for research/query/collect/compile/audit.
author: nvk
license: MIT
hooks:
  - pre_llm_call
  - on_session_start
  - post_tool_call
  - on_session_finalize
  - on_session_end
```

- [ ] **Step 2: Create `plugins/llm-wiki-hermes/__init__.py`**

```python
from __future__ import annotations

from . import adapter, tools


def register(ctx):
    """Hermes plugin entrypoint. Wires session-capture hooks and the wiki tool."""
    ctx.register_hook("on_session_start", adapter.on_session_start)
    ctx.register_hook("pre_llm_call", adapter.pre_llm_call)
    ctx.register_hook("post_tool_call", adapter.post_tool_call)
    ctx.register_hook("on_session_finalize", adapter.on_session_finalize)
    ctx.register_hook("on_session_end", adapter.on_session_end)
    tools.register(ctx)
```

- [ ] **Step 3: Create `plugins/llm-wiki-hermes/hooks/__init__.py`**

```python
"""Hooks package for the llm-wiki Hermes plugin."""
```

- [ ] **Step 4: Create `plugins/llm-wiki-hermes/tests/__init__.py`**

```python
```

- [ ] **Step 5: Sanity check the package imports**

Run: `cd /tmp/opencode/llm-wiki-upstream/plugins/llm-wiki-hermes && python3 -c "import ast,pathlib; [ast.parse(p.read_text()) for p in pathlib.Path('.').rglob('*.py')]; print('ok')"`
Expected: `ok`

- [ ] **Step 6: Commit**

```bash
cd /tmp/opencode/llm-wiki-upstream
git add plugins/llm-wiki-hermes/plugin.yaml plugins/llm-wiki-hermes/__init__.py plugins/llm-wiki-hermes/hooks/__init__.py plugins/llm-wiki-hermes/tests/__init__.py
git commit -m "feat(hermes): add plugin skeleton (manifest, register, package markers)"
```

---

### Task 3: Adapter — engine import, payload mapping, 5 hooks (capture only)

**Files:**
- Create: `plugins/llm-wiki-hermes/hooks/adapter.py`
- Create: `plugins/llm-wiki-hermes/tests/test_adapter.py`

**Interfaces:**
- Consumes: `engine.handle_event(args, payload)`, `engine.resolve_hub(args)`, `engine.sessions_dir(hub)`, `engine.load_config(root)` (from Task 1).
- Produces: `on_session_start`, `pre_llm_call`, `post_tool_call`, `on_session_finalize`, `on_session_end` (Hermes hook fns); `_get_engine()`, `_args()`, `_payload()`, `_capture()`. NOTE: `pre_llm_call` returns rehydrate context ONLY here; Task 4 adds memory.

- [ ] **Step 1: Write the failing adapter test**

Create `plugins/llm-wiki-hermes/tests/test_adapter.py`:

```python
from __future__ import annotations

import sys
import types
from pathlib import Path
from unittest import mock

import pytest

import adapter as adapter_mod


def _fake_engine(hub_root, rehydrate_return=""):
    eng = types.SimpleNamespace()
    eng.resolve_hub = lambda args: hub_root
    eng.sessions_dir = lambda hub: hub / ".sessions"
    eng.load_config = lambda root: {"enabled": True, "rehydrate": {"session_start": True, "user_prompt": True}}
    calls = []

    def handle_event(args, payload):
        calls.append((args, payload))
        # record a fake state file so tests can assert write happened
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
    out = adapter_mod.pre_llm_call(session_id="s2", turn_id="t1", user_message="hello", model="m", cwd="/x")
    assert out == "REHYDRATE_CTX"
    args, payload = fake_engine._calls[0]
    assert args.event_name == "UserPromptSubmit"
    assert payload["user_prompt"] == "hello"
    assert payload["turn_id"] == "t1"


def test_post_tool_call_truncates_tool_output(fake_engine):
    big = "x" * 5000
    out = adapter_mod.post_tool_call(tool_name="terminal", args={"cmd": "ls"}, result=big, session_id="s3", tool_call_id="tc1", cwd="/x")
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
    adapter_mod.on_session_end(session_id="s5", completed=True, interrupted=False, reason="done", model="m", cwd="/x")
    args, payload = fake_engine._calls[0]
    assert args.event_name == "SessionEnd"
    assert payload["completed"] is True


def test_hook_exception_is_swallowed(fake_engine):
    bad = _fake_engine(fake_engine.__dict__ and Path("/tmp"), rehydrate_return="")
    bad.handle_event = mock.Mock(side_effect=RuntimeError("boom"))
    with mock.patch.object(adapter_mod, "_get_engine", return_value=bad):
        # should not raise; returns None
        assert adapter_mod.pre_llm_call(session_id="z", user_message="q", cwd="/x") is None
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /tmp/opencode/llm-wiki-upstream/plugins/llm-wiki-hermes && python3 -m pytest tests/test_adapter.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'adapter'` (or import error until file exists).

- [ ] **Step 3: Implement `adapter.py` (capture only, no memory yet)**

Create `plugins/llm-wiki-hermes/hooks/adapter.py`:

```python
from __future__ import annotations

import argparse
import importlib.util
import os
import sys
from pathlib import Path

ENGINE_PATH = Path(__file__).resolve().parents[2] / "llm-wiki" / "hooks" / "llm_wiki_session.py"

_engine = None


def _get_engine():
    """Lazily import the shared upstream engine. Returns None on failure (R11)."""
    global _engine
    if _engine is None:
        try:
            spec = importlib.util.spec_from_file_location("llm_wiki_session", str(ENGINE_PATH))
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


def on_session_start(session_id=None, carry_over_context=None, platform=None, model=None, cwd=None, **kwargs):
    cwd = cwd or os.getcwd()
    payload = _payload(session_id=session_id, model=model, user_prompt=carry_over_context)
    return _capture("SessionStart", payload, cwd, session_id=session_id) or None


def pre_llm_call(session_id=None, turn_id=None, user_message="", model=None, is_first_turn=False, cwd=None, **kwargs):
    cwd = cwd or os.getcwd()
    payload = _payload(session_id=session_id, turn_id=turn_id, model=model, user_prompt=user_message)
    return _capture("UserPromptSubmit", payload, cwd, session_id=session_id) or None


def post_tool_call(tool_name=None, args=None, result=None, session_id=None, tool_call_id=None, turn_id=None, duration_ms=None, status=None, error_message=None, cwd=None, model=None, **kwargs):
    tool_args = args
    cwd = cwd or os.getcwd()
    tool_output = result if isinstance(result, str) else (str(result) if result is not None else "")
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


def on_session_end(session_id=None, completed=None, interrupted=None, reason=None, model=None, cwd=None, **kwargs):
    cwd = cwd or os.getcwd()
    payload = _payload(session_id=session_id, completed=completed, interrupted=interrupted, reason=reason, model=model)
    _capture("SessionEnd", payload, cwd, session_id=session_id)
    return None
```

- [ ] **Step 4: Run the adapter test to verify it passes**

Run: `cd /tmp/opencode/llm-wiki-upstream/plugins/llm-wiki-hermes && python3 -m pytest tests/test_adapter.py -v`
Expected: PASS (all 7 tests).

- [ ] **Step 5: Commit**

```bash
cd /tmp/opencode/llm-wiki-upstream
git add plugins/llm-wiki-hermes/hooks/adapter.py plugins/llm-wiki-hermes/tests/test_adapter.py
git commit -m "feat(hermes): adapter payload mapping + 5 session-capture hooks"
```

---

### Task 4: Wiki-as-memory retrieval + injection into `pre_llm_call`

**Files:**
- Modify: `plugins/llm-wiki-hermes/hooks/adapter.py` (add `retrieve_wiki_context` + `_score_articles`; update `pre_llm_call`)
- Modify: `plugins/llm-wiki-hermes/tests/test_adapter.py` (add memory tests)

**Interfaces:**
- Consumes: `engine.resolve_hub`, `engine.sessions_dir`, `engine.load_config` (Task 1).
- Produces: `retrieve_wiki_context(cwd, query, limit) -> str`; `pre_llm_call` now returns `rehydrate + "\n\n" + memory`.

- [ ] **Step 1: Add memory tests to `tests/test_adapter.py`**

Append to the file:

```python
import re


def _make_wiki(hub_root, slug, articles):
    topic = hub_root / "topics" / slug
    topic.mkdir(parents=True, exist_ok=True)
    lines = ["# Index\n"]
    for title, rel, summary in articles:
        lines.append(f"- [{title}]({rel}) — {summary}\n")
    (topic / "_index.md").write_text("".join(lines))
    # hub index listing the topic
    hub_idx = hub_root / "_index.md"
    existing = hub_idx.read_text() if hub_idx.exists() else "# Hub\n"
    hub_idx.write_text(existing + f"- [Topics](topics/{slug}/) — a topic\n")


def test_memory_retrieval_matches_title(fake_engine, tmp_path):
    eng = _fake_engine(tmp_path / "hub")
    _make_wiki(tmp_path / "hub", "nutrition", [
        ("Gut-Brain Axis", "concepts/gut-brain.md", "Links gut microbiome to cognition"),
        ("Cold Exposure", "concepts/cold.md", "Activates brown fat"),
    ])
    with mock.patch.object(adapter_mod, "_get_engine", return_value=eng):
        ctx = adapter_mod.retrieve_wiki_context(cwd=str(tmp_path), query="tell me about the gut brain axis", limit=3)
    assert "Gut-Brain Axis" in ctx
    assert "Cold Exposure" not in ctx


def test_memory_retrieval_no_match_is_empty(fake_engine, tmp_path):
    eng = _fake_engine(tmp_path / "hub")
    _make_wiki(tmp_path / "hub", "nutrition", [("Gut-Brain Axis", "c/g.md", "x")])
    with mock.patch.object(adapter_mod, "_get_engine", return_value=eng):
        ctx = adapter_mod.retrieve_wiki_context(cwd=str(tmp_path), query="cryptocurrency trading strategies", limit=3)
    assert ctx == ""


def test_memory_respects_disable_env(fake_engine, tmp_path, monkeypatch):
    monkeypatch.setenv("LLM_WIKI_HERMES_MEMORY", "0")
    eng = _fake_engine(tmp_path / "hub")
    _make_wiki(tmp_path / "hub", "nutrition", [("Gut-Brain Axis", "c/g.md", "x")])
    with mock.patch.object(adapter_mod, "_get_engine", return_value=eng):
        assert adapter_mod.retrieve_wiki_context(cwd=str(tmp_path), query="gut brain", limit=3) == ""


def test_pre_llm_call_combines_rehydrate_and_memory(fake_engine, tmp_path):
    eng = _fake_engine(tmp_path / "hub", rehydrate_return="REHYDRATE_CTX")
    _make_wiki(tmp_path / "hub", "nutrition", [("Gut-Brain Axis", "c/g.md", "links gut to cognition")])
    with mock.patch.object(adapter_mod, "_get_engine", return_value=eng):
        out = adapter_mod.pre_llm_call(session_id="s9", user_message="gut brain axis please", cwd=str(tmp_path))
    assert "REHYDRATE_CTX" in out
    assert "Gut-Brain Axis" in out
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `cd /tmp/opencode/llm-wiki-upstream/plugins/llm-wiki-hermes && python3 -m pytest tests/test_adapter.py -v -k memory`
Expected: FAIL — `AttributeError: module 'adapter' has no attribute 'retrieve_wiki_context'`.

- [ ] **Step 3: Implement `retrieve_wiki_context` + `_score_articles` and update `pre_llm_call`**

In `plugins/llm-wiki-hermes/hooks/adapter.py`, ADD the following near the top (after `_payload`) and REPLACE the `pre_llm_call` function.

Add constants + helpers (insert after `_payload`):

```python
MEMORY_LIMIT = 3
MEMORY_CFG_KEY = "memory"
MEMORY_ENV_DISABLE = "LLM_WIKI_HERMES_MEMORY"

TOKEN_RE = re.compile(r"[a-z0-9]+")
STOPWORDS = {
    "the", "a", "an", "and", "or", "of", "to", "in", "on", "for", "with",
    "is", "are", "was", "were", "be", "by", "as", "at", "that", "this",
    "it", "from", "we", "you", "i", "our", "your", "do", "does", "did",
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
            summary = line[m.end():].lstrip(" —-:").strip()
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
        mem_cfg = config.get(MEMORY_CFG_KEY) if isinstance(config.get(MEMORY_CFG_KEY), dict) else {}
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
```

Also add `import re` to the module's import line (change `import os` → `import os` and add `import re` on its own line).

REPLACE `pre_llm_call` with:

```python
def pre_llm_call(session_id=None, turn_id=None, user_message="", model=None, is_first_turn=False, cwd=None, **kwargs):
    cwd = cwd or os.getcwd()
    payload = _payload(session_id=session_id, turn_id=turn_id, model=model, user_prompt=user_message)
    rehydrate = _capture("UserPromptSubmit", payload, cwd, session_id=session_id)
    memory = retrieve_wiki_context(cwd=cwd, query=user_message or "")
    combined = "\n\n".join(p for p in (rehydrate, memory) if p).strip()
    return combined or None
```

- [ ] **Step 4: Run the full adapter test to verify it passes**

Run: `cd /tmp/opencode/llm-wiki-upstream/plugins/llm-wiki-hermes && python3 -m pytest tests/test_adapter.py -v`
Expected: PASS (all 11 tests).

- [ ] **Step 5: Commit**

```bash
cd /tmp/opencode/llm-wiki-upstream
git add plugins/llm-wiki-hermes/hooks/adapter.py plugins/llm-wiki-hermes/tests/test_adapter.py
git commit -m "feat(hermes): proactive wiki-as-memory injection on user prompt"
```

---

### Task 5: `wiki` router tool (deterministic CLI)

**Files:**
- Create: `plugins/llm-wiki-hermes/tools.py`
- Create: `plugins/llm-wiki-hermes/tests/test_tools.py`

**Interfaces:**
- Consumes: `scripts/llm-wiki` and `scripts/llm-wiki-session` (repo binaries).
- Produces: `register(ctx)` registers tool `wiki`; `handle_wiki(params, **kwargs) -> str` (JSON).

- [ ] **Step 1: Write the failing tool test**

Create `plugins/llm-wiki-hermes/tests/test_tools.py`:

```python
from __future__ import annotations

import json
from pathlib import Path

import tools as tools_mod


def test_handle_wiki_routes_to_session_script(tmp_path, monkeypatch):
    fake = tmp_path / "fake-script.py"
    fake.write_text("#!/usr/bin/env python3\nimport sys; print('SESSION-OK')\n")
    monkeypatch.setattr(tools_mod, "SESSION_SCRIPT", fake)
    monkeypatch.setattr(tools_mod, "CLI_SCRIPT", tmp_path / "cli.py")
    out = json.loads(tools_mod.handle_wiki({"command": "session", "args": "status"}))
    assert out["success"] is True
    assert "SESSION-OK" in out["output"]


def test_handle_wiki_missing_command():
    out = json.loads(tools_mod.handle_wiki({"command": ""}))
    assert out["success"] is False


def test_register_calls_ctx(tmp_path, monkeypatch):
    cli = tmp_path / "cli.py"
    cli.write_text("#!/usr/bin/env python3\nprint('ok')\n")
    monkeypatch.setattr(tools_mod, "CLI_SCRIPT", cli)
    monkeypatch.setattr(tools_mod, "SESSION_SCRIPT", tmp_path / "sess.py")
    captured = {}

    class Ctx:
        def register_tool(self, **kw):
            captured.update(kw)

    tools_mod.register(Ctx())
    assert captured["name"] == "wiki"
    assert callable(captured["handler"])
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /tmp/opencode/llm-wiki-upstream/plugins/llm-wiki-hermes && python3 -m pytest tests/test_tools.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'tools'`.

- [ ] **Step 3: Implement `tools.py`**

Create `plugins/llm-wiki-hermes/tools.py`:

```python
from __future__ import annotations

import json
import shlex
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SESSION_SCRIPT = REPO_ROOT / "scripts" / "llm-wiki-session"
CLI_SCRIPT = REPO_ROOT / "scripts" / "llm-wiki"


def _run(script, command, rest):
    try:
        proc = subprocess.run(
            [sys.executable, str(script), command, *shlex.split(rest or "")],
            capture_output=True,
            text=True,
            timeout=120,
        )
    except subprocess.TimeoutExpired as exc:  # pragma: no cover - defensive
        return json.dumps({"success": False, "error": f"timeout: {exc}"})
    return json.dumps({
        "success": proc.returncode == 0,
        "output": proc.stdout,
        "error": proc.stderr,
    })


def handle_wiki(params, **kwargs):
    command = (params.get("command") or "").strip()
    rest = params.get("args", "") or ""
    if not command:
        return json.dumps({"success": False, "error": "missing 'command'"})
    script = SESSION_SCRIPT if command in ("session", "feedback") else CLI_SCRIPT
    if not script.exists():
        return json.dumps({"success": False, "error": f"script not found: {script}"})
    return _run(script, command, rest)


def register(ctx):
    ctx.register_tool(
        name="wiki",
        toolset="wiki",
        schema={
            "type": "object",
            "properties": {
                "command": {
                    "type": "string",
                    "description": "llm-wiki subcommand: lint|schema|archive|session|feedback",
                },
                "args": {
                    "type": "string",
                    "description": "Remaining CLI args, e.g. '--fix /path/to/wiki' or 'disable'",
                },
            },
            "required": ["command"],
        },
        handler=handle_wiki,
        description=(
            "Run deterministic llm-wiki checks (lint/schema/archive) and session/feedback helpers. "
            "For agentic work (research/query/collect/ingest/compile/audit/output/plan/thesis) "
            "follow the wiki-manager skill."
        ),
    )
```

- [ ] **Step 4: Run the tool test to verify it passes**

Run: `cd /tmp/opencode/llm-wiki-upstream/plugins/llm-wiki-hermes && python3 -m pytest tests/test_tools.py -v`
Expected: PASS (all 3 tests).

- [ ] **Step 5: Commit**

```bash
cd /tmp/opencode/llm-wiki-upstream
git add plugins/llm-wiki-hermes/tools.py plugins/llm-wiki-hermes/tests/test_tools.py
git commit -m "feat(hermes): wiki router tool for deterministic CLI"
```

---

### Task 6: Bundle the wiki-manager skill

**Files:**
- Create: `plugins/llm-wiki-hermes/skills/wiki-manager/SKILL.md`
- Create: `plugins/llm-wiki-hermes/skills/wiki-manager/references/*.md` (copied)

**Interfaces:**
- Consumes: `claude-plugin/skills/wiki-manager/SKILL.md` + `references/`.
- Produces: Hermes-discoverable skill so the agent can run agentic commands.

- [ ] **Step 1: Copy the skill verbatim**

```bash
cd /tmp/opencode/llm-wiki-upstream
mkdir -p plugins/llm-wiki-hermes/skills/wiki-manager
cp claude-plugin/skills/wiki-manager/SKILL.md plugins/llm-wiki-hermes/skills/wiki-manager/SKILL.md
cp -R claude-plugin/skills/wiki-manager/references plugins/llm-wiki-hermes/skills/wiki-manager/references
```

- [ ] **Step 2: Verify frontmatter + no missing references**

Run:
```bash
cd /tmp/opencode/llm-wiki-upstream
head -1 plugins/llm-wiki-hermes/skills/wiki-manager/SKILL.md   # expect: ---
ls plugins/llm-wiki-hermes/skills/wiki-manager/references | head
```
Expected: first line is `---`; references dir lists the same `.md` files as `claude-plugin/skills/wiki-manager/references/`.

- [ ] **Step 3: Commit**

```bash
cd /tmp/opencode/llm-wiki-upstream
git add plugins/llm-wiki-hermes/skills
git commit -m "feat(hermes): bundle wiki-manager skill for agentic commands"
```

---

### Task 7: Run the full Python test suite

**Files:** (none new — verification only)

- [ ] **Step 1: Run all Hermes unit tests**

Run: `cd /tmp/opencode/llm-wiki-upstream/plugins/llm-wiki-hermes && python3 -m pytest tests/ -v`
Expected: PASS (all adapter + tools tests).

- [ ] **Step 2: Run the engine test**

Run: `cd /tmp/opencode/llm-wiki-upstream && python3 -m pytest tests/test_hermes_engine.py -v`
Expected: PASS.

- [ ] **Step 3: Run repo structural suite to confirm no regressions**

Run:
```bash
cd /tmp/opencode/llm-wiki-upstream
./tests/test-plugin-validate.sh
./tests/test-docs-consistency.sh
./tests/test-structure.sh
./tests/test-local-cli-lint.sh
./tests/test-session-capture.sh
./tests/test-session-concurrency.sh
./tests/test-codex-sync.sh
./tests/test-opencode-sync.sh
```
Expected: every script prints `Results: N passed, 0 failed, M total` and exits 0. (These do not yet know about Hermes, so they must stay green — confirms the new dir did not disturb generated mirrors or docs.)

- [ ] **Step 4: Commit if any fix was needed**

Only if a test failed and you fixed it. Otherwise no commit.

---

### Task 8: Hermes runtime test script

**Files:**
- Create: `tests/test-hermes-runtime.sh`

**Interfaces:**
- Consumes: the installed plugin package (imports `plugins/llm-wiki-hermes` as `adapter`/`tools`).

- [ ] **Step 1: Write `tests/test-hermes-runtime.sh`**

```bash
#!/usr/bin/env bash
# Runtime test for the Hermes plugin: drive the adapter hooks directly (no full
# Hermes binary required in CI) and assert capture files + injected context.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN="$REPO_ROOT/plugins/llm-wiki-hermes"
TMP="$(mktemp -d)"
HUB="$TMP/hub"
PASS=0; FAIL=0

ok()  { PASS=$((PASS+1)); printf "  \033[32mPASS\033[0m: %s\n" "$1"; }
bad() { FAIL=$((FAIL+1)); printf "  \033[31mFAIL\033[0m: %s\n" "$1"; }

mkdir -p "$HUB/topics/nutrition"
printf '# nutrition\n- [Gut-Brain Axis](concepts/gut.md) — gut microbiome to cognition\n' > "$HUB/topics/nutrition/_index.md"
printf '# Hub\n- [Topics](topics/nutrition/) — nutrition wiki\n' > "$HUB/_index.md"

export LLM_WIKI_HUB="$HUB"   # not read by adapter directly; we monkeypatch via PYTHONPATH driver below

DRIVER="$TMP/driver.py"
cat > "$DRIVER" <<PY
import importlib.util, os, sys, json, tempfile
from pathlib import Path
sys.path.insert(0, "$PLUGIN")
import adapter, tools

# Route the engine to our temp hub so tests are hermetic.
engine_path = Path("$REPO_ROOT/plugins/llm-wiki/hooks/llm_wiki_session.py")
spec = importlib.util.spec_from_file_location("eng", str(engine_path))
eng = importlib.util.module_from_spec(spec); spec.loader.exec_module(eng)
HUB = Path("$HUB")
eng.resolve_hub = lambda args: HUB
adapter._engine = eng

# 1) session start captures + returns rehydrate (empty here, returns None)
r = adapter.on_session_start(session_id="h1", model="m", cwd="/x")
assert r is None or isinstance(r, str), "on_session_start return type"

# 2) pre_llm_call injects wiki memory for matching query
out = adapter.pre_llm_call(session_id="h2", user_message="gut brain axis", cwd="/x")
assert out and "Gut-Brain Axis" in out, f"memory not injected: {out!r}"

# 3) post_tool_call records without raising
assert adapter.post_tool_call(tool_name="terminal", result="x"*50, session_id="h3", cwd="/x") is None

# 4) state file written under harness=hermes
state = HUB / ".sessions" / "state" / "hermes" / "h2.json"
assert state.exists(), "state file missing"

# 5) wiki tool runs deterministic lint against the hub index (smoke)
res = json.loads(tools.handle_wiki({"command": "schema", "args": f"status {HUB / 'topics' / 'nutrition'}"}))
assert isinstance(res, dict), "tool must return JSON"

print("RUNTIME_OK")
PY

if python3 "$DRIVER" | grep -q "RUNTIME_OK"; then
  ok "hermes adapter driver completed"
else
  bad "hermes adapter driver failed (see output above)"
fi

echo "==========================================="
printf "Results: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m, %d total\n" "$PASS" "$FAIL" "$((PASS+FAIL))"
rm -rf "$TMP"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

- [ ] **Step 2: Run the runtime test**

Run: `cd /tmp/opencode/llm-wiki-upstream && chmod +x tests/test-hermes-runtime.sh && ./tests/test-hermes-runtime.sh`
Expected: `RUNTIME_OK` printed; `Results: 1 passed, 0 failed`.

- [ ] **Step 3: Commit**

```bash
cd /tmp/opencode/llm-wiki-upstream
git add tests/test-hermes-runtime.sh
git commit -m "test(hermes): add runtime test driving adapter hooks + wiki tool"
```

---

### Task 9: Wire Hermes into CI + manifest validation

**Files:**
- Modify: `tests/ci/plugin-tests.yml`
- Modify: `tests/test-plugin-validate.sh`

**Interfaces:**
- Consumes: `tests/test-hermes-runtime.sh` (Task 8), `plugins/llm-wiki-hermes/plugin.yaml` + skill (Tasks 2,6).

- [ ] **Step 1: Update `paths:` filters in `tests/ci/plugin-tests.yml`**

In BOTH the `push` and `pull_request` `paths:` blocks, add:
```yaml
      - 'plugins/llm-wiki-hermes/**'
      - 'tests/test-hermes-runtime.sh'
```
(They currently list `claude-plugin/**`, `scripts/**`, `tests/**`, `AGENTS.md`.)

- [ ] **Step 2: Add a Hermes runtime step to the `structural` job**

Insert after the "Run session capture tests" step:
```yaml
      - name: Run Hermes plugin runtime tests
        run: chmod +x tests/test-hermes-runtime.sh && ./tests/test-hermes-runtime.sh
```

- [ ] **Step 3: Add a "Hermes Mirror Validation" block to `tests/test-plugin-validate.sh`**

Append before the final `echo "===..."` / results summary (i.e., after the OpenCode block, before the results printf). Insert:

```bash

# Hermes plugin validation — the artifacts Hermes loads from ~/.hermes/plugins/.
echo ""
echo "=== Hermes Plugin Validation ==="
HERMES_PLUGIN="$PROJECT_ROOT/plugins/llm-wiki-hermes"

if [ -f "$HERMES_PLUGIN/plugin.yaml" ]; then
  log_pass "Hermes plugin.yaml exists"
  if python3 -c "import yaml,sys; d=yaml.safe_load(open('$HERMES_PLUGIN/plugin.yaml')); assert d.get('name') and d.get('version') and isinstance(d.get('hooks'),list) and d['hooks'], 'missing name/version/hooks'" 2>/dev/null; then
    log_pass "Hermes plugin.yaml has name + version + hooks"
  else
    # PyYAML may be absent; fall back to a minimal parse.
    if python3 - <<'PY'
import re,sys
t=open('$HERMES_PLUGIN/plugin.yaml').read()
ok = 'name:' in t and 'version:' in t and 'hooks:' in t
sys.exit(0 if ok else 1)
PY
    then
      log_pass "Hermes plugin.yaml has name + version + hooks (minimal parse)"
    else
      log_fail "Hermes plugin.yaml invalid" "missing name/version/hooks"
    fi
  fi
else
  log_fail "Hermes plugin.yaml not found" "missing file"
fi

if [ -f "$HERMES_PLUGIN/skills/wiki-manager/SKILL.md" ]; then
  log_pass "Hermes SKILL.md exists"
  if head -1 "$HERMES_PLUGIN/skills/wiki-manager/SKILL.md" | grep -q "^---$"; then
    log_pass "Hermes SKILL.md has frontmatter"
  else
    log_fail "Hermes SKILL.md has no frontmatter" "missing ---"
  fi
else
  log_fail "Hermes SKILL.md not found" "missing file"
fi

for f in hooks/__init__.py hooks/adapter.py tools.py __init__.py; do
  fp="$HERMES_PLUGIN/$f"
  if [ -f "$fp" ]; then
    if python3 -m py_compile "$fp" 2>/dev/null; then
      log_pass "Hermes $f compiles"
    else
      log_fail "Hermes $f does not compile" "syntax error"
    fi
  else
    log_fail "Hermes $f missing" "missing file"
  fi
done
```

- [ ] **Step 4: Run both updated tests**

Run:
```bash
cd /tmp/opencode/llm-wiki-upstream
chmod +x tests/test-plugin-validate.sh && ./tests/test-plugin-validate.sh
```
Expected: a new "Hermes Plugin Validation" section with all PASS; `0 failed`.

- [ ] **Step 5: Commit**

```bash
cd /tmp/opencode/llm-wiki-upstream
git add tests/ci/plugin-tests.yml tests/test-plugin-validate.sh
git commit -m "ci(hermes): validate Hermes plugin + run its runtime test in CI"
```

---

### Task 10: README + docs updates

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: the feature (Tasks 1-6).

- [ ] **Step 1: Add a Supported clients row**

In the "Supported clients" table, add a row after the "Any agent" row:
```markdown
| Hermes | `~/.hermes/plugins/llm-wiki-hermes` | ~3K tokens | NousResearch agent |
```

- [ ] **Step 2: Add a Hermes install section**

After the "Any LLM Agent" install block (before "## Claude-First, Multi-Runtime"), add:
```markdown
**Hermes** (plugin):

Drop the plugin directory into your Hermes plugins folder and restart Hermes:

```bash
git clone https://github.com/nvk/llm-wiki.git /tmp/llm-wiki
mkdir -p ~/.hermes/plugins
ln -s /tmp/llm-wiki/plugins/llm-wiki-hermes ~/.hermes/plugins/llm-wiki-hermes
```

Hermes auto-discovers the plugin: the five session-capture hooks and the `wiki`
tool activate immediately, and the wiki-manager skill enables agentic commands
(`research`, `query`, `collect`, `ingest`, `compile`, `audit`, `output`, …).
Hermes also proactively injects relevant wiki notes as memory on each user
prompt (toggle with `LLM_WIKI_HERMES_MEMORY=0` or `memory.inject: false` in
`HUB/.sessions/config.json`).
```

- [ ] **Step 3: Update the session-capture line**

In "## How It Works → The Flow", change the step that reads:
`10. **Session capture** — automatically preserve redacted Codex/Claude/OpenCode/Gemini checkpoints under .sessions/ and rehydrate future turns`
to:
`10. **Session capture** — automatically preserve redacted Claude/Codex/OpenCode/Gemini/Hermes checkpoints under .sessions/ and rehydrate future turns (Hermes additionally injects matching wiki notes as memory on each prompt)`

- [ ] **Step 4: Verify docs consistency**

Run: `cd /tmp/opencode/llm-wiki-upstream && ./tests/test-docs-consistency.sh`
Expected: `0 failed`. (No new `claude-plugin/commands/*.md` was added, and the Supported-clients row is outside the `## Commands` table, so the test stays green. If it fails on version drift, ensure `plugin.yaml` version is `0.15.0`.)

- [ ] **Step 5: Commit**

```bash
cd /tmp/opencode/llm-wiki-upstream
git add README.md
git commit -m "docs: document Hermes install, supported-client row, memory injection"
```

---

### Task 11: Final verification, push, and PR prep

**Files:** (none new — final gate)

- [ ] **Step 1: Run the complete structural suite**

Run all of:
```bash
cd /tmp/opencode/llm-wiki-upstream
./tests/test-plugin-validate.sh
./tests/test-docs-consistency.sh
./tests/test-structure.sh
./tests/test-local-cli-lint.sh
./tests/test-session-capture.sh
./tests/test-session-concurrency.sh
./tests/test-codex-sync.sh
./tests/test-opencode-sync.sh
./tests/test-hermes-runtime.sh
python3 -m pytest tests/test_hermes_engine.py plugins/llm-wiki-hermes/tests/ -q
```
Expected: every script `0 failed`; pytest all pass.

- [ ] **Step 2: Push the branch to the fork**

```bash
cd /tmp/opencode/llm-wiki-upstream
git -c credential.helper='!gh auth git-credential' push https://github.com/dfein38347g/llm-wiki.git feat/hermes-plugin
```
Expected: branch updated on `dfein38347g/llm-wiki`.

- [ ] **Step 3: Open the PR (or print the URL)**

Open: `https://github.com/dfein38347g/llm-wiki/pull/new/feat/hermes-plugin`
PR title: `feat: add Hermes plugin — session hooks, wiki tool, and wiki-as-memory injection`
PR body must state: (a) three-layer parity with Claude/Codex; (b) net-new memory injection; (c) the upstream `handle_event` refactor with zero behavior change (proven by green `test-session-capture.sh`); (d) new tests + CI `paths:` update; (e) behavioral Promptfoo evals are Claude-only and do not cover Hermes.

- [ ] **Step 4: Final commit (only if PR body/housekeeping needed)**

If any last fix was required by Step 1, commit and push again.
