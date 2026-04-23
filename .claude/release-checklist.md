# llm-wiki Release Checklist

Standard process for testing and shipping a new version of the llm-wiki plugin.

## Pre-release: Version Bump

1. **Bump `plugin.json`** — both files must match:
   - `claude-plugin/.claude-plugin/plugin.json`
   - `plugins/llm-wiki/.codex-plugin/plugin.json`

## Test

2. **Run structural + packaging checks**:
   ```bash
   ./scripts/sync-codex-plugin.sh
   ./scripts/sync-opencode-plugin.sh
   ./tests/test-plugin-validate.sh
   ./tests/test-structure.sh
   ./tests/test-codex-sync.sh
   ./tests/test-opencode-sync.sh
   ./tests/test-codex-runtime.sh
   ```

3. **Invoke `/wiki status` in Claude Code** — verify the skill resolves and shows the hub status table
   - If `/wiki` doesn't resolve, check that `~/.claude/commands/wiki.md` shim exists (delegates to `wiki:wiki`)

4. **Invoke `@wiki test` in Codex** — verify the plugin resolves from a fresh session
   - For repo-local validation, run `./scripts/bootstrap-codex-plugin.sh --scope project --verify`
   - If verify reports `PENDING`, open `/plugins`, enable `LLM Wiki`, restart Codex if needed, and rerun the verify command
   - If project scope fails outright, confirm the project is trusted before assuming the plugin is broken

5. **Verify OpenCode skill loads** — start OpenCode with the instruction file and ask "what wiki commands do you know?"
   - Load via: `"instructions": ["plugins/llm-wiki-opencode/skills/wiki-manager/SKILL.md"]` in `opencode.json`
   - Verify web search works with `OPENCODE_ENABLE_EXA=1`

6. **Test the changed feature** — whatever was added/fixed in this release:
   - Invoke the relevant `/wiki:*` subcommand
   - Confirm expected behavior, no errors

6. **Spot-check routing** (if routing changed):
   - `/wiki <url>` → should route to ingest
   - `/wiki what is X?` → should route to query
   - `/wiki research Y` → should route to research

## Ship

7. **Commit version bumps** — both files in one commit:
   ```bash
   git add .claude-plugin/marketplace.json claude-plugin/.claude-plugin/plugin.json
   git commit -m "Bump to v0.0.XX"
   ```

8. **Push to master**:
   ```bash
   git push origin <branch>:master
   ```
   - If in a worktree: `git push origin worktree-<name>:master`

9. **Create GitHub release**:
   ```bash
   GH_TOKEN="" gh release create v0.0.XX \
     --repo nvk/llm-wiki \
     --title "v0.0.XX — <Short Feature Name>" \
     --notes "$(cat <<'EOF'
   ## What's New

   - **Feature description** — one-liner explaining the change

   ### Details (optional)
   - Additional bullet points if needed
   EOF
   )"
   ```
   - `GH_TOKEN=""` is required to clear a bad env token and use `gh auth` credentials
   - Release title format: `v0.0.XX — <Feature Name>`

10. **Update plugin cache** (so local Claude Code picks up new version):
   ```bash
   # The marketplace repo auto-pulls on `claude plugin install`
   # But for dev: symlink or copy to cache
   mkdir -p ~/.claude/plugins/cache/llm-wiki/wiki/0.0.XX
   # Copy commands/ skills/ .claude-plugin/ from the repo's claude-plugin/ dir
   ```
   - Or just run `claude plugin install llm-wiki` if marketplace is updated

11. **Verify install**:
   - Claude Code: start a fresh session and run `/wiki status`
   - Codex: start a fresh session and run `@wiki test` or `./scripts/verify-codex-plugin.sh --scope project`
   - OpenCode: start a session with the SKILL.md loaded and ask "wiki status"
   - If the Codex verify script reports `PENDING`, finish the first-time enable in `/plugins` and rerun it

## Post-ship: README

- Update the changelog section in `README.md` for notable releases (skip patch-level fixes)
- Keep only the last 5-6 entries — drop the oldest when adding a new one
- Follow the existing single-paragraph format
- Commit separately: `"Update README with vX.Y.Z changelog"`

## Post-ship: Website

- Update `llm-wiki-web/index.html`:
  - Release card fallback version + description (the live API fetch also picks it up, but the fallback should match)
  - Plugin card fallback version
  - Commands table if new flags/commands were added
  - Feature cards if a major capability changed
- Update `llm-wiki-web/llms.txt` if commands or flags changed
- Commit and push to `llm-wiki-web` repo separately

## Notes

- Claude marketplace plugin name: `wiki@llm-wiki`
- Codex plugin invocation name: `@wiki`
- OpenCode: loaded via `"instructions"` in `opencode.json` or copied to `~/.config/opencode/AGENTS.md`
- Claude plugin cache path: `~/.claude/plugins/cache/llm-wiki/wiki/<version>/`
- Claude marketplace repo: `~/.claude/plugins/marketplaces/llm-wiki/`
- Codex project config path: `<project>/.codex/config.toml` (local, gitignored in this repo)
- Codex user config path: `~/.codex/config.toml`
- Hub wiki path: `~/Library/Mobile Documents/com~apple~CloudDocs/wiki/`
- The `/wiki` bare command needs `~/.claude/commands/wiki.md` shim (user-level, not in repo)
