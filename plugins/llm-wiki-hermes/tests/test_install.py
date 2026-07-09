from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "hooks"))

import install as install_mod


def test_disable_is_idempotent_when_api_unavailable():
    # Outside Hermes, the API import fails; the call must no-op gracefully.
    # We can't import hermes_cli here, so just assert the flag + no crash.
    assert isinstance(install_mod._HAVE_HERMES_CONFIG, bool)
    # Should not raise even if Hermes is absent.
    result = install_mod.disable_builtin_llm_wiki_skill()
    assert result in (True, False)


def test_seed_copies_skill_to_fake_home(tmp_path, monkeypatch):
    monkeypatch.setattr(install_mod.Path, "home", lambda: tmp_path)
    # Ensure the source skill dir exists in the plugin tree.
    src_dir = Path(__file__).resolve().parents[1] / "skills" / "wiki-manager"
    assert (src_dir / "SKILL.md").exists(), "bundled wiki-manager SKILL.md must exist"
    # First call writes.
    assert install_mod.seed_wiki_manager_skill() is True
    dst = tmp_path / ".hermes" / "skills" / "wiki-manager"
    assert (dst / "SKILL.md").exists()
    assert (dst / "SKILL.md").read_text() == (src_dir / "SKILL.md").read_text()
    # references/ are also copied.
    refs = list((dst / "references").glob("*.md"))
    assert len(refs) > 0, "references/ should be copied alongside SKILL.md"
    # Second call is a no-op (idempotent).
    assert install_mod.seed_wiki_manager_skill() is False


def test_steer_detects_wiki_intent():
    from hooks import adapter as adapter_mod  # imported lazily to avoid heavy deps

    out = adapter_mod._steer_to_our_skill("can you ingest this into my wiki?")
    assert "wiki-manager" in out
    assert adapter_mod._steer_to_our_skill("what is the weather?") == ""
