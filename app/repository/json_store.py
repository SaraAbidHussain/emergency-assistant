"""
json_store.py

Tiny generic JSON-file persistence helper. Fixes the "everything resets on
restart" problem for a hackathon without pulling in a real database:
each store (sessions, contacts) is just a JSON file under DATA_DIR that's
loaded once at import time and re-written after every mutation.

Not meant for high concurrency (each save rewrites the whole file) — that's
fine here since request volume is low and every write already goes through
a single Python process. Swap for SQLite/Postgres later without touching
callers, since they only ever use load_json()/save_json().
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

# Resolve relative to the project root (folder containing "app/"), not the
# current working directory, so it works regardless of where uvicorn is run from.
DATA_DIR = Path(__file__).resolve().parent.parent.parent / "data"
DATA_DIR.mkdir(parents=True, exist_ok=True)


def _path_for(name: str) -> Path:
    return DATA_DIR / f"{name}.json"


def load_json(name: str, default: Any) -> Any:
    """Load <DATA_DIR>/<name>.json. Returns `default` if the file doesn't
    exist yet or is corrupted (never raises — a bad file shouldn't crash
    startup)."""
    path = _path_for(name)
    if not path.exists():
        return default
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return default


def save_json(name: str, data: Any) -> None:
    """Write <DATA_DIR>/<name>.json atomically (write to a temp file then
    replace) so a crash mid-write never leaves a half-written/corrupt file."""
    path = _path_for(name)
    tmp_path = path.with_suffix(".json.tmp")
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2, default=str)
    os.replace(tmp_path, path)
