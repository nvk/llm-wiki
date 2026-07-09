from __future__ import annotations

import shutil
import sys
from pathlib import Path

# Hermes' own config subsystem (importable inside register(ctx)). This is the
# supported, list-safe way to mutate skills.disabled — NOT a hand-written YAML
# edit and NOT `hermes config set` (which cannot express a YAML list).
try:
    from hermes_cli.config import load_config, save_config
    from hermes_cli.skills_config import get_disabled_skills, save_disabled_skills

    _HAVE_HERMES_CONFIG = True
except Exception:  # pragma: no cover - defensive
    _HAVE_HERMES_CONFIG = False


def disable_builtin_llm_wiki_skill() -> bool:
    """Add the bundled Hermes `llm-wiki` skill to `skills.disabled`.

    Returns True if a change was written, False if already disabled or the
    Hermes config API is unavailable (e.g. running outside Hermes). Never
    raises into the caller.
    """
    if not _HAVE_HERMES_CONFIG:
        print(
            "[llm-wiki-hermes] Hermes config API unavailable; "
            "cannot auto-disable the built-in llm-wiki skill. "
            "Disable it manually (see README).",
            file=sys.stderr,
        )
        return False
    try:
        config = load_config()
        disabled = get_disabled_skills(config, platform=None)
        if "llm-wiki" in disabled:
            return False
        disabled.add("llm-wiki")
        save_disabled_skills(config, disabled, platform=None)
        print(
            "[llm-wiki-hermes] Disabled Hermes' built-in 'llm-wiki' skill "
            "so our wiki-manager skill replaces it. Restart Hermes to apply.",
            file=sys.stderr,
        )
        return True
    except Exception as exc:  # pragma: no cover - defensive
        print(
            f"[llm-wiki-hermes] failed to disable built-in llm-wiki skill: {exc}",
            file=sys.stderr,
        )
        return False


def _skill_src_dir() -> Path:
    return Path(__file__).resolve().parents[1] / "skills" / "wiki-manager"


def _skill_dst_dir() -> Path:
    return Path.home() / ".hermes" / "skills" / "wiki-manager"


def seed_wiki_manager_skill() -> bool:
    """Copy our bundled wiki-manager skill (SKILL.md + references/) into
    ~/.hermes/skills/wiki-manager/ so it enters Hermes' <available_skills>
    index and auto-loads for wiki requests (plugin-registered skills are
    intentionally NOT indexed — plugins.py:1208). Idempotent: skips if the
    destination SKILL.md already exists. Returns True if files were written.
    """
    src = _skill_src_dir()
    dst = _skill_dst_dir()
    dst_skill = dst / "SKILL.md"
    if not (src / "SKILL.md").exists():
        print(f"[llm-wiki-hermes] bundled skill not found at {src}", file=sys.stderr)
        return False
    if dst_skill.exists():
        return False
    try:
        if dst.exists():
            shutil.rmtree(dst)
        shutil.copytree(src, dst)
        print(
            "[llm-wiki-hermes] Seeded wiki-manager skill into ~/.hermes/skills/ "
            "so it replaces the built-in llm-wiki skill.",
            file=sys.stderr,
        )
        return True
    except Exception as exc:  # pragma: no cover - defensive
        print(
            f"[llm-wiki-hermes] failed to seed wiki-manager skill: {exc}",
            file=sys.stderr,
        )
        return False
