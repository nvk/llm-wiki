# Hermes llm-wiki Plugin

A unified native Hermes plugin: two read-only agent tools and an opt-in desktop pane.

## Install from this checkout

```bash
mkdir -p "$HERMES_HOME/plugins"
cp -R hermes-plugin/llm-wiki "$HERMES_HOME/plugins/llm-wiki"
hermes plugins enable llm-wiki
```

Restart the Hermes gateway after enabling the Python plugin. In Hermes Desktop, enable **llm-wiki** in **Capabilities → Plugins** to show the pane.

- `llm_wiki_status` counts raw documents and compiled articles and reports missing `raw/`, `wiki/`, or `output/` directories.
- `llm_wiki_lint` executes the existing deterministic lint command without a shell. It uses this checkout's `scripts/llm-wiki` when available; for a copied installation, set `LLM_WIKI_CLI` to the executable's absolute path.

The desktop pane calls the plugin's profile-scoped `/api/plugins/llm-wiki/status` backend. It has no write controls.
