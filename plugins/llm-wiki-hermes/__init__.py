from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

_plugin_dir = Path(__file__).resolve().parent

_adapter_path = _plugin_dir / "hooks" / "adapter.py"
_spec = importlib.util.spec_from_file_location(
    "llm_wiki_hermes_adapter", str(_adapter_path)
)
_adapter_mod = importlib.util.module_from_spec(_spec)
sys.modules["llm_wiki_hermes_adapter"] = _adapter_mod
_spec.loader.exec_module(_adapter_mod)

_tools_path = _plugin_dir / "tools.py"
_spec2 = importlib.util.spec_from_file_location(
    "llm_wiki_hermes_tools", str(_tools_path)
)
_tools_mod = importlib.util.module_from_spec(_spec2)
sys.modules["llm_wiki_hermes_tools"] = _tools_mod
_spec2.loader.exec_module(_tools_mod)

adapter = _adapter_mod
tools = _tools_mod

_SKILL_DIR = Path(__file__).resolve().parent / "skills" / "wiki-manager"

_install_path = _plugin_dir / "hooks" / "install.py"
_spec3 = importlib.util.spec_from_file_location(
    "llm_wiki_hermes_install", str(_install_path)
)
_install_mod = importlib.util.module_from_spec(_spec3)
sys.modules["llm_wiki_hermes_install"] = _install_mod
_spec3.loader.exec_module(_install_mod)


def register(ctx):
    """Hermes plugin entrypoint. Wires session-capture hooks, the wiki tool, and the bundled skill."""
    ctx.register_hook("on_session_start", adapter.on_session_start)
    ctx.register_hook("pre_llm_call", adapter.pre_llm_call)
    ctx.register_hook("post_tool_call", adapter.post_tool_call)
    ctx.register_hook("on_session_finalize", adapter.on_session_finalize)
    ctx.register_hook("on_session_end", adapter.on_session_end)
    tools.register(ctx)
    try:
        ctx.register_skill(
            "wiki-manager",
            _SKILL_DIR,
            description="LLM-compiled knowledge base manager: ingest, compile, query, collect, audit, research, output.",
        )
    except Exception as exc:  # pragma: no cover - defensive
        print(f"[llm-wiki-hermes] skill registration failed: {exc}", file=sys.stderr)
    try:
        _install_mod.disable_builtin_llm_wiki_skill()
    except Exception as exc:  # pragma: no cover - defensive
        print(f"[llm-wiki-hermes] install step failed: {exc}", file=sys.stderr)
    try:
        _install_mod.seed_wiki_manager_skill()
    except Exception as exc:  # pragma: no cover - defensive
        print(f"[llm-wiki-hermes] seed step failed: {exc}", file=sys.stderr)
