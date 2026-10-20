"""Native Hermes plugin registration for llm-wiki."""

from . import schemas, tools


def register(ctx):
    """Register llm-wiki's deterministic, read-only tools."""
    ctx.register_tool(name="llm_wiki_status", toolset="llm-wiki", schema=schemas.LLM_WIKI_STATUS, handler=tools.llm_wiki_status)
    ctx.register_tool(name="llm_wiki_lint", toolset="llm-wiki", schema=schemas.LLM_WIKI_LINT, handler=tools.llm_wiki_lint)
