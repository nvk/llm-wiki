"""Shared helpers for optional Morph LLM API integrations.

Not part of the core llm-wiki CLI surface -- imported by scripts/morph-compact
only. (WarpGrep is not a plain REST endpoint -- Morph's own MCP server
[`npx @morphllm/morphmcp@latest`] exposes it correctly as `codebase_search`/
`github_codebase_search` tools; see README.md's Morph integration section.)
Every resolver here degrades to "nothing configured" instead of raising, so
callers can implement their own local fallback behavior. Stdlib only,
matching the rest of scripts/.
"""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

DEFAULT_BASE_URL = "https://api.morphllm.com/v1"
CONFIG_PATH = Path.home() / ".config" / "llm-wiki" / "config.json"


def _load_config(config_path: Path | None = None) -> dict[str, Any]:
    path = config_path or CONFIG_PATH
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def resolve_api_key(config_path: Path | None = None) -> str | None:
    env_key = os.environ.get("MORPH_API_KEY")
    if env_key:
        return env_key
    value = _load_config(config_path).get("morph_api_key")
    return str(value) if value else None


def resolve_base_url(config_path: Path | None = None) -> str:
    env_url = os.environ.get("MORPH_API_BASE_URL")
    if env_url:
        return env_url.rstrip("/")
    value = _load_config(config_path).get("morph_api_base_url")
    if value:
        return str(value).rstrip("/")
    return DEFAULT_BASE_URL


def redact(api_key: str | None) -> str:
    if not api_key:
        return "<none>"
    if len(api_key) <= 8:
        return "*" * len(api_key)
    return f"{api_key[:4]}...{api_key[-4:]}"


def post_json(
    path: str,
    payload: dict[str, Any],
    api_key: str,
    base_url: str,
    timeout: float = 10.0,
) -> tuple[bool, Any]:
    """POST JSON to {base_url}{path}. Never raises -- returns (ok, data_or_error).

    Callers MUST treat ok=False as "fall back to local/no-op behavior," never
    as a reason to abort the calling command.
    """
    suffix = path if path.startswith("/") else f"/{path}"
    url = f"{base_url.rstrip('/')}{suffix}"
    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = response.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace") if exc.fp else str(exc)
        return False, f"HTTP {exc.code}: {detail}"
    except urllib.error.URLError as exc:
        return False, f"network error calling {url}: {exc.reason}"
    except OSError as exc:
        return False, f"error calling {url}: {exc}"

    try:
        data = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        return False, f"invalid JSON response from {url}: {exc}"
    return True, data
