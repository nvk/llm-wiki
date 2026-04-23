# llm-wiki for OpenCode

Load this skill as an instruction file in OpenCode.

## Quick Install

Add to your project's `opencode.json`:

```json
{
  "instructions": ["path/to/llm-wiki/plugins/llm-wiki-opencode/skills/wiki-manager/SKILL.md"]
}
```

Or copy to your global config:

```bash
cp plugins/llm-wiki-opencode/skills/wiki-manager/SKILL.md ~/.config/opencode/AGENTS.md
```

## Permissions

OpenCode sandboxes file access to the project directory by default. The wiki hub lives at `~/wiki/` (or a custom path), which is outside any project. Add this to your `opencode.json`:

```json
{
  "permission": {
    "external_directory": {
      "~/wiki/**": "allow",
      "~/.config/llm-wiki/**": "allow"
    }
  }
}
```

If your hub is on iCloud Drive:
```json
{
  "permission": {
    "external_directory": {
      "~/Library/Mobile Documents/com~apple~CloudDocs/wiki/**": "allow",
      "~/.config/llm-wiki/**": "allow"
    }
  }
}
```

Alternatively, use `--local` mode (`.wiki/` in the project) to avoid external path issues entirely.

## Web Search

Research operations require web search. Enable it:

```bash
export OPENCODE_ENABLE_EXA=1
```

## Usage

Talk to OpenCode naturally:

- "Initialize a wiki about quantum computing"
- "Research Kubernetes deployment patterns"
- "Ingest https://example.com/article into my wiki"
- "Compile the wiki"
- "What does my wiki know about X?"
- "Lint the wiki and fix issues"

## Alternative: AGENTS.md

The repo root also contains `AGENTS.md`, which OpenCode reads automatically. It provides the portable wiki protocol. This SKILL.md provides a richer experience with activation triggers, fuzzy routing, and ambient behavior.

## Alternative: opencode-agent-skills

The [opencode-agent-skills](https://github.com/joshuadavidthomas/opencode-agent-skills) plugin loads Claude Code skills directly in OpenCode. Add `"opencode-agent-skills"` to the `"plugin"` array in `opencode.json` and the Claude plugin at `claude-plugin/` works without modification.

## This directory is generated

Do not edit files here by hand. Run `scripts/sync-opencode-plugin.sh` to regenerate from the Claude source. The `references/` directory is a symlink into `claude-plugin/skills/wiki-manager/references/`.
