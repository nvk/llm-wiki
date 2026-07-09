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


def register(ctx):
    """Hermes plugin entrypoint. Wires session-capture hooks and the wiki tool."""
    ctx.register_hook("on_session_start", adapter.on_session_start)
    ctx.register_hook("pre_llm_call", adapter.pre_llm_call)
    ctx.register_hook("post_tool_call", adapter.post_tool_call)
    ctx.register_hook("on_session_finalize", adapter.on_session_finalize)
    ctx.register_hook("on_session_end", adapter.on_session_end)
    tools.register(ctx)
