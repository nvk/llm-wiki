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


def test_handle_wiki_routes_lint_to_cli_script(tmp_path, monkeypatch):
    cli = tmp_path / "cli.py"
    cli.write_text("#!/usr/bin/env python3\nimport sys; print('CLI-OK')\n")
    monkeypatch.setattr(tools_mod, "CLI_SCRIPT", cli)
    monkeypatch.setattr(tools_mod, "SESSION_SCRIPT", tmp_path / "sess.py")
    out = json.loads(tools_mod.handle_wiki({"command": "lint", "args": "--check"}))
    assert out["success"] is True
    assert "CLI-OK" in out["output"]


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


def test_handle_wiki_routes_known_session_command_to_session_script(
    tmp_path, monkeypatch
):
    """Every session subcommand must hit scripts/llm-wiki-session, not the CLI."""
    session_script = tmp_path / "llm-wiki-session"
    cli_script = tmp_path / "llm-wiki"
    for p in (session_script, cli_script):
        p.write_text("#!/usr/bin/env python3\nimport sys; print(sys.argv[0])\n")
        p.chmod(0o755)
    monkeypatch.setattr(tools_mod, "SESSION_SCRIPT", session_script)
    monkeypatch.setattr(tools_mod, "CLI_SCRIPT", cli_script)
    for cmd in [
        "enable",
        "disable",
        "capture",
        "list",
        "show",
        "rehydrate",
        "promote",
        "feedback",
        "status",
        "session",
    ]:
        out = json.loads(tools_mod.handle_wiki({"command": cmd}))
        assert out["success"] is True, f"command {cmd!r} should route to session script"
        assert "llm-wiki-session" in out["output"], f"{cmd!r} routed to wrong script"


def test_handle_wiki_routes_cli_commands_to_cli_script(tmp_path, monkeypatch):
    session_script = tmp_path / "llm-wiki-session"
    cli_script = tmp_path / "llm-wiki"
    for p in (session_script, cli_script):
        p.write_text("#!/usr/bin/env python3\nimport sys; print(sys.argv[0])\n")
        p.chmod(0o755)
    monkeypatch.setattr(tools_mod, "SESSION_SCRIPT", session_script)
    monkeypatch.setattr(tools_mod, "CLI_SCRIPT", cli_script)
    for cmd in ["lint", "archive", "schema"]:
        out = json.loads(tools_mod.handle_wiki({"command": cmd}))
        assert out["success"] is True, f"command {cmd!r} should route to CLI script"
        assert "llm-wiki" in out["output"] and "session" not in out["output"], (
            f"{cmd!r} routed to wrong script"
        )
