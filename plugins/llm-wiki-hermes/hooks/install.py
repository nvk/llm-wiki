from __future__ import annotations

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
