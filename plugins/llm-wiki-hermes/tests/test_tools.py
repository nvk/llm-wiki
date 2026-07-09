from __future__ import annotations

import importlib.util
import json
from pathlib import Path

_tools_path = Path(__file__).resolve().parents[1] / "tools.py"
_spec = importlib.util.spec_from_file_location("tools", str(_tools_path))
tools_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(tools_mod)


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
