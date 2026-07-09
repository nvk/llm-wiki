from __future__ import annotations

import importlib.util
import sys
import types
from pathlib import Path
from unittest import mock

import pytest

_adapter_path = Path(__file__).resolve().parents[1] / "hooks" / "adapter.py"
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
    assert payload["tool_output"].endswith("truncated from 5000 chars]")
    assert len(payload["tool_output"]) < 5000  # still truncated


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
    bad = _fake_engine(Path("/tmp"), rehydrate_return="")
    bad.handle_event = mock.Mock(side_effect=RuntimeError("boom"))
    with mock.patch.object(adapter_mod, "_get_engine", return_value=bad):
        assert (
            adapter_mod.pre_llm_call(session_id="z", user_message="q", cwd="/x") is None
        )


def _make_wiki(hub_root, slug, articles):
    topic = hub_root / "topics" / slug
    topic.mkdir(parents=True, exist_ok=True)
    lines = ["# Index\n"]
    for title, rel, summary in articles:
        lines.append(f"- [{title}]({rel}) — {summary}\n")
    (topic / "_index.md").write_text("".join(lines))
    hub_idx = hub_root / "_index.md"
    existing = hub_idx.read_text() if hub_idx.exists() else "# Hub\n"
    hub_idx.write_text(existing + f"- [Topics](topics/{slug}/) — a topic\n")


def test_memory_retrieval_matches_title(fake_engine, tmp_path):
    eng = _fake_engine(tmp_path / "hub")
    _make_wiki(
        tmp_path / "hub",
        "nutrition",
        [
            (
                "Gut-Brain Axis",
                "concepts/gut-brain.md",
                "Links gut microbiome to cognition",
            ),
            ("Cold Exposure", "concepts/cold.md", "Activates brown fat"),
        ],
    )
    with mock.patch.object(adapter_mod, "_get_engine", return_value=eng):
        ctx = adapter_mod.retrieve_wiki_context(
            cwd=str(tmp_path), query="tell me about the gut brain axis", limit=3
        )
    assert "Gut-Brain Axis" in ctx
    assert "Cold Exposure" not in ctx


def test_memory_retrieval_no_match_is_empty(fake_engine, tmp_path):
    eng = _fake_engine(tmp_path / "hub")
    _make_wiki(tmp_path / "hub", "nutrition", [("Gut-Brain Axis", "c/g.md", "x")])
    with mock.patch.object(adapter_mod, "_get_engine", return_value=eng):
        ctx = adapter_mod.retrieve_wiki_context(
            cwd=str(tmp_path), query="cryptocurrency trading strategies", limit=3
        )
    assert ctx == ""


def test_memory_respects_disable_env(fake_engine, tmp_path, monkeypatch):
    monkeypatch.setenv("LLM_WIKI_HERMES_MEMORY", "0")
    eng = _fake_engine(tmp_path / "hub")
    _make_wiki(tmp_path / "hub", "nutrition", [("Gut-Brain Axis", "c/g.md", "x")])
    with mock.patch.object(adapter_mod, "_get_engine", return_value=eng):
        assert (
            adapter_mod.retrieve_wiki_context(
                cwd=str(tmp_path), query="gut brain", limit=3
            )
            == ""
        )


def test_pre_llm_call_combines_rehydrate_and_memory(fake_engine, tmp_path):
    eng = _fake_engine(tmp_path / "hub", rehydrate_return="REHYDRATE_CTX")
    _make_wiki(
        tmp_path / "hub",
        "nutrition",
        [("Gut-Brain Axis", "c/g.md", "links gut to cognition")],
    )
    with mock.patch.object(adapter_mod, "_get_engine", return_value=eng):
        out = adapter_mod.pre_llm_call(
            session_id="s9", user_message="gut brain axis please", cwd=str(tmp_path)
        )
    assert "REHYDRATE_CTX" in out
    assert "Gut-Brain Axis" in out


def _make_topic_index(hub_root, slug, articles):
    """Helper: populate a topic subdir with an _index.md."""
    topic = hub_root / "topics" / slug
    topic.mkdir(parents=True, exist_ok=True)
    lines = []
    for title, rel, summary in articles:
        line = f"- [{title}]({rel})"
        if summary:
            line += f" — {summary}"
        lines.append(line)
    (topic / "_index.md").write_text("\n".join(lines))


def test_score_articles_matches_title(tmp_path):
    hub = tmp_path / "hub"
    hub.mkdir(parents=True, exist_ok=True)
    (hub / "_index.md").write_text("# Hub\n- [Nutrition](topics/nutrition/)")
    _make_topic_index(
        hub, "nutrition", [("Gut-Brain Axis", "c/gut.md", "links gut to cognition")]
    )
    result = adapter_mod._score_articles(hub, "gut brain axis", 3)
    assert len(result) == 1
    assert result[0] == ("Gut-Brain Axis", "c/gut.md", "links gut to cognition")


def test_score_articles_no_trailing_slash(tmp_path):
    """Regression: hub index link without trailing / must still match."""
    hub = tmp_path / "hub"
    hub.mkdir(parents=True, exist_ok=True)
    (hub / "_index.md").write_text("# Hub\n- [Nutrition](topics/nutrition)")
    _make_topic_index(hub, "nutrition", [("Gut-Brain Axis", "c/gut.md", "x")])
    result = adapter_mod._score_articles(hub, "gut", 3)
    assert len(result) == 1


def test_score_articles_empty_hub_index(tmp_path):
    hub = tmp_path / "hub"
    hub.mkdir(parents=True, exist_ok=True)
    (hub / "_index.md").write_text("# Hub\n")
    assert adapter_mod._score_articles(hub, "anything", 3) == []


def test_score_articles_archived_only(tmp_path):
    """Archived topics (starting with .) must be excluded."""
    hub = tmp_path / "hub"
    hub.mkdir(parents=True, exist_ok=True)
    (hub / "_index.md").write_text("# Hub\n- [Old](topics/.archive/nutrition/)")
    assert adapter_mod._score_articles(hub, "nutrition", 3) == []


def test_score_articles_stopword_only_query(tmp_path):
    hub = tmp_path / "hub"
    hub.mkdir(parents=True, exist_ok=True)
    (hub / "_index.md").write_text("# Hub\n- [Nutrition](topics/nutrition/)")
    _make_topic_index(hub, "nutrition", [("Gut-Brain Axis", "c/gut.md", "x")])
    assert adapter_mod._score_articles(hub, "the and of", 3) == []


def test_score_articles_deduplicates_by_rel(tmp_path):
    hub = tmp_path / "hub"
    hub.mkdir(parents=True, exist_ok=True)
    (hub / "_index.md").write_text("# Hub\n- [Nutrition](topics/nutrition/)")
    _make_topic_index(
        hub,
        "nutrition",
        [
            ("Gut Brain", "c/gut.md", "x"),
            ("Brain Gut", "c/gut.md", "y"),  # same rel
        ],
    )
    result = adapter_mod._score_articles(hub, "brain gut", 3)
    assert len(result) == 1  # deduplicated


def test_steer_matches_wiki_keywords():
    assert adapter_mod._steer_to_our_skill("show me the wiki") != ""
    assert adapter_mod._steer_to_our_skill("ingest this URL") != ""
    assert adapter_mod._steer_to_our_skill("compile the knowledge base") != ""
    assert adapter_mod._steer_to_our_skill("llm wiki status") != ""
    assert adapter_mod._steer_to_our_skill("LLM-Wiki status") != ""
    assert adapter_mod._steer_to_our_skill("rehydrate my session") != ""
    assert "wiki-manager" in adapter_mod._steer_to_our_skill("wiki")


def test_steer_ignores_non_wiki_messages():
    assert adapter_mod._steer_to_our_skill("hello world") == ""
    assert adapter_mod._steer_to_our_skill("what is 2+2") == ""
    assert adapter_mod._steer_to_our_skill("") == ""
    assert adapter_mod._steer_to_our_skill(None) == ""


def test_pre_llm_call_appends_steer_for_wiki_intent(fake_engine):
    out = adapter_mod.pre_llm_call(
        session_id="s10", user_message="show me the wiki", model="m", cwd="/x"
    )
    assert "wiki-manager" in out


def test_pre_llm_call_no_steer_for_normal_message(fake_engine):
    fake_engine._calls.clear()
    out = adapter_mod.pre_llm_call(
        session_id="s11", user_message="what is python", model="m", cwd="/x"
    )
    assert "wiki-manager" not in (out or "")
