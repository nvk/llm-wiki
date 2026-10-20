"""LLM-facing schemas for the Hermes llm-wiki plugin."""

LLM_WIKI_STATUS = {
    "name": "llm_wiki_status",
    "description": "Inspect one llm-wiki topic directory. Use for read-only document counts and required-directory checks.",
    "parameters": {"type": "object", "properties": {"path": {"type": "string", "description": "Absolute or home-relative topic wiki path."}}, "required": ["path"]},
}

LLM_WIKI_LINT = {
    "name": "llm_wiki_lint",
    "description": "Run llm-wiki's deterministic lint command on one existing topic directory. Use to verify wiki structure; it does not modify files.",
    "parameters": {"type": "object", "properties": {"path": {"type": "string", "description": "Absolute or home-relative topic wiki path."}}, "required": ["path"]},
}
