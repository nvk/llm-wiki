# llm-wiki Release Checklist

Standard process for testing and shipping a new version of the llm-wiki plugin.

## Pre-release: Version Bump

1. **Bump `plugin.json`** — `claude-plugin/.claude-plugin/plugin.json`
   - Update `"version"` field (e.g. `"0.0.20"` → `"0.0.21"`)

2. **Bump `marketplace.json`** — `.claude-plugin/marketplace.json`
   - Update top-level `"version"` field
   - Update `plugins[0].version` field
   - (Both must match plugin.json)

## Test

3. **Invoke `/wiki status`** — verify the skill resolves and shows the hub status table
   - If `/wiki` doesn't resolve, check that `~/.claude/commands/wiki.md` shim exists (delegates to `wiki:wiki`)

4. **Test the changed feature** — whatever was added/fixed in this release:
   - Invoke the relevant `/wiki:*` subcommand
   - Confirm expected behavior, no errors

5. **Spot-check routing** (if routing changed):
   - `/wiki <url>` → should route to ingest
   - `/wiki what is X?` → should route to query
   - `/wiki research Y` → should route to research

## Ship

6. **Commit version bumps** — both files in one commit:
   ```bash
   git add .claude-plugin/marketplace.json claude-plugin/.claude-plugin/plugin.json
   git commit -m "Bump to v0.0.XX"
   ```

7. **Push to master**:
   ```bash
   git push origin <branch>:master
   ```
   - If in a worktree: `git push origin worktree-<name>:master`

8. **Create GitHub release**:
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

9. **Update plugin cache** (so local Claude Code picks up new version):
   ```bash
   # The marketplace repo auto-pulls on `claude plugin install`
   # But for dev: symlink or copy to cache
   mkdir -p ~/.claude/plugins/cache/llm-wiki/wiki/0.0.XX
   # Copy commands/ skills/ .claude-plugin/ from the repo's claude-plugin/ dir
   ```
   - Or just run `claude plugin install llm-wiki` if marketplace is updated

10. **Verify install** — start a fresh Claude Code session and run `/wiki status`

## Optional: README Update

- Update changelog section in `README.md` if it's a notable release
- Follow the existing format (see v0.0.18/v0.0.19 entries)
- Commit separately: `"Update README with v0.0.XX changelog"`

## Notes

- Plugin name in marketplace: `wiki@llm-wiki`
- Plugin cache path: `~/.claude/plugins/cache/llm-wiki/wiki/<version>/`
- Marketplace repo: `~/.claude/plugins/marketplaces/llm-wiki/`
- Hub wiki path: `~/Library/Mobile Documents/com~apple~CloudDocs/wiki/`
- The `/wiki` bare command needs `~/.claude/commands/wiki.md` shim (user-level, not in repo)
