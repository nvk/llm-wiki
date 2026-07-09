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
