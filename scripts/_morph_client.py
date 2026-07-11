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
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

DEFAULT_BASE_URL = "https://api.morphllm.com/v1"
CONFIG_PATH = Path.home() / ".config" / "llm-wiki" / "config.json"

# HTTP status codes worth retrying: request timeout, rate limit, and the 5xx
# transient-server family. 4xx client errors (e.g. 400 "model required") will
# not change on a retry, so we fail fast to passthrough instead of stalling.
RETRYABLE_STATUS = frozenset({408, 429, 500, 502, 503, 504})


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
    retries: int = 1,
    retry_backoff: float = 0.5,
) -> tuple[bool, Any]:
    """POST JSON to {base_url}{path}. Never raises -- returns (ok, data_or_error).

    Each attempt is bounded by ``timeout`` seconds. Transient failures (socket
    timeout, connection error, and the retryable HTTP statuses in
    RETRYABLE_STATUS) are retried up to ``retries`` times with exponential
    backoff (``retry_backoff`` * 2**attempt seconds). Non-retryable 4xx client
    errors fail immediately -- retrying them only delays the caller's fallback.

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
    attempts = max(1, retries + 1)
    last_error = "unknown error"
    for attempt in range(attempts):
        retryable = False
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                raw = response.read()
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace") if exc.fp else str(exc)
            last_error = f"HTTP {exc.code}: {detail}"
            retryable = exc.code in RETRYABLE_STATUS
        except urllib.error.URLError as exc:
            # Covers connection refused/reset, DNS failures, and socket
            # timeouts (urlopen raises URLError(reason=TimeoutError) on timeout).
            last_error = f"network error calling {url}: {exc.reason}"
            retryable = True
        except OSError as exc:
            last_error = f"error calling {url}: {exc}"
            retryable = True
        else:
            try:
                data = json.loads(raw.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError) as exc:
                return False, f"invalid JSON response from {url}: {exc}"
            return True, data

        if retryable and attempt < attempts - 1:
            time.sleep(retry_backoff * (2 ** attempt))
            continue
        return False, last_error

    return False, last_error
