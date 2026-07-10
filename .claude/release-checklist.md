# llm-wiki Release Checklist

Standard process for testing and shipping a new version of the llm-wiki plugin.

## Pre-release: Version Bump

0. **Verify GitHub auth uses HTTPS, not SSH**:
   ```bash
   gh auth status
   gh auth login --web --git-protocol https   # only if not already logged in
   gh auth setup-git
   ```
   - Agents should use GitHub CLI web login and HTTPS git transport, not SSH.
   - SSH host-key prompts and `known_hosts` writes are fragile under nono.
   - If the local repo or Claude marketplace checkout uses SSH, switch it:
     ```bash
     git remote set-url origin https://github.com/nvk/llm-wiki.git
     git -C ~/.claude/plugins/marketplaces/llm-wiki remote set-url origin https://github.com/nvk/llm-wiki.git
     ```

1. **Bump `plugin.json`** — both files must match:
   - `.claude-plugin/marketplace.json`
   - `claude-plugin/.claude-plugin/plugin.json`
   - `plugins/llm-wiki/.codex-plugin/plugin.json`
   - `plugins/llm-wiki-hermes/plugin.yaml`

## Test

2. **Run structural + packaging checks**:
   ```bash
   ./scripts/sync-codex-plugin.sh
   ./scripts/sync-opencode-plugin.sh
   ./tests/test-plugin-validate.sh
   ./tests/test-docs-consistency.sh
   ./tests/test-structure.sh
   ./tests/test-local-cli-lint.sh
   ./tests/test-session-capture.sh
   ./tests/test-session-concurrency.sh
   ./tests/test-hermes-runtime.sh
   ./tests/test-codex-sync.sh
   ./tests/test-opencode-sync.sh
   ./tests/test-codex-runtime.sh
   ```

3. **Invoke `/wiki status` in Claude Code** — verify the skill resolves and shows the hub status table
   - If `/wiki` doesn't resolve, check that `~/.claude/commands/wiki.md` shim exists (delegates to `wiki:wiki`)

4. **Invoke `@wiki test` in Codex** — verify the plugin resolves from a fresh session
   - For repo-local validation, run `./scripts/bootstrap-codex-plugin.sh --scope user --verify`
   - The bootstrap must materialize the plugin with `codex plugin add`; a clean-home test must not require `/plugins`
   - Open `/hooks` separately to review and trust automated session-capture hooks when testing hook behavior
   - Codex 0.144 does not load plugin enablement from project config; do not document `--scope project` as a supported install

5. **Verify OpenCode skill loads** — start OpenCode with the instruction file and ask "what wiki commands do you know?"
   - Load via: `"instructions": ["plugins/llm-wiki-opencode/skills/wiki-manager/SKILL.md"]` in `opencode.json`
   - Verify web search works with `OPENCODE_ENABLE_EXA=1`

6. **Verify Hermes profiles and optional session adapter**:
   - Confirm root `AGENTS.md` and `profiles/query-lite/SKILL.md` retain valid skill frontmatter
   - Run `./tests/test-hermes-runtime.sh`
   - If Hermes is installed, invoke `/wiki-query` and confirm the optional plugin does not replace skills or register tools

7. **Test the changed feature** — whatever was added/fixed in this release:
   - Invoke the relevant `/wiki:*` subcommand
   - Confirm expected behavior, no errors

8. **Spot-check routing** (if routing changed):
   - `/wiki <url>` → should route to ingest
   - `/wiki what is X?` → should route to query
   - `/wiki research Y` → should route to research

## Ship

9. **Commit version bumps** — all manifests in one commit:
   ```bash
   git add .claude-plugin/marketplace.json claude-plugin/.claude-plugin/plugin.json \
     plugins/llm-wiki/.codex-plugin/plugin.json plugins/llm-wiki-hermes/plugin.yaml
   git commit -m "Bump to v0.0.XX"
   ```

10. **Push to master**:
   ```bash
   git -c credential.helper='!gh auth git-credential' push https://github.com/nvk/llm-wiki.git <branch>:master
   ```
   - If in a worktree: replace `<branch>` with `worktree-<name>`
   - Do not use SSH remotes from agent sessions; use `gh auth` + HTTPS.

11. **Create GitHub release**:
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

12. **Update plugin cache** (so local Claude Code picks up new version):
   ```bash
   git -C ~/.claude/plugins/marketplaces/llm-wiki remote set-url origin https://github.com/nvk/llm-wiki.git
   claude plugin update wiki@llm-wiki
   ```
   - If the update path is stale during development, copy to cache:
   ```bash
   # The marketplace repo auto-pulls on `claude plugin install`
   # But for dev: symlink or copy to cache
   mkdir -p ~/.claude/plugins/cache/llm-wiki/wiki/0.0.XX
   # Copy commands/ skills/ .claude-plugin/ from the repo's claude-plugin/ dir
   ```

13. **Verify install**:
   - Claude Code: start a fresh session and run `/wiki status`
   - Codex: start a fresh session and run `@wiki test` or `./scripts/verify-codex-plugin.sh --scope user`
   - OpenCode: start a session with the SKILL.md loaded and ask "wiki status"
   - Hermes: update `wiki-query` and `wiki-manager`, then test the session adapter if enabled

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
- Codex plugin enablement config path: `~/.codex/config.toml`
- Hub wiki path: `~/Library/Mobile Documents/com~apple~CloudDocs/wiki/`
- The `/wiki` bare command needs `~/.claude/commands/wiki.md` shim (user-level, not in repo)
