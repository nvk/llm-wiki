#!/usr/bin/env bash
# Hermetic runtime test for the optional Hermes session adapter.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/home" "$TMP/hub"
HOME="$TMP/home" python3 - "$REPO_ROOT" "$TMP/hub" <<'PY'
import importlib.util
import json
import sys
from pathlib import Path

repo = Path(sys.argv[1])
hub = Path(sys.argv[2])
plugin = repo / "plugins" / "llm-wiki-hermes"


def load(name, path, package=False):
    kwargs = {"submodule_search_locations": [str(path.parent)]} if package else {}
    spec = importlib.util.spec_from_file_location(name, str(path), **kwargs)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


engine = load(
    "llm_wiki_hermes_test_engine",
    repo / "plugins" / "llm-wiki" / "hooks" / "llm_wiki_session.py",
)
engine.resolve_hub = lambda args: hub

package = load("llm_wiki_hermes", plugin / "__init__.py", package=True)
adapter = package.adapter
adapter._engine = engine
adapter._engine_attempted = True

sessions = hub / ".sessions"
sessions.mkdir()
(sessions / "config.json").write_text(
    json.dumps(
        {
            "enabled": True,
            "mode": "balanced",
            "rehydrate": {"session_start": False, "user_prompt": True},
        }
    )
)


class Context:
    def __init__(self):
        self.hooks = {}
        self.tools = []
        self.skills = []

    def register_hook(self, name, callback):
        self.hooks[name] = callback

    def register_tool(self, *args, **kwargs):
        self.tools.append((args, kwargs))

    def register_skill(self, *args, **kwargs):
        self.skills.append((args, kwargs))


ctx = Context()
package.register(ctx)
assert set(ctx.hooks) == {
    "on_session_start",
    "pre_llm_call",
    "post_tool_call",
    "on_session_finalize",
    "on_session_end",
}
assert not ctx.tools, "session adapter must not register tools"
assert not ctx.skills, "session adapter must not replace or seed skills"

# Finish one session so the next session can rehydrate it.
adapter.on_session_start(session_id="old", model="test", cwd="/fixture")
adapter.on_session_end(session_id="old", completed=True, cwd="/fixture")

adapter.on_session_start(task_id="new", model="test", cwd="/fixture")
context = adapter.pre_llm_call(
    task_id="new", turn_id="t1", user_message="resume", cwd="/fixture"
)
assert context and "llm-wiki session context" in context
assert "hermes:old" in context
adapter.post_tool_call(
    task_id="new",
    tool_name="terminal",
    args={"command": "printf test"},
    result="test",
    cwd="/fixture",
)
adapter.on_session_finalize(task_id="new", reason="compact", cwd="/fixture")
adapter.on_session_end(task_id="new", completed=True, cwd="/fixture")

state = sessions / "state" / "hermes" / "new.json"
assert state.exists(), state
data = json.loads(state.read_text())
assert data["harness"] == "hermes"
assert data["native_session_id"] == "new"

# Registration must not mutate Hermes skill/config state.
assert not (Path.home() / ".hermes" / "skills").exists()
assert not (Path.home() / ".hermes" / "config.yaml").exists()

print("PASS: Hermes session adapter captures, rehydrates, and stays skill-neutral")
PY
