"""
Canonical Python path aliases for the segregation project.

Contract:
- PYTHONPATH must include SCODE so scripts can import `set_paths`.
- For Stata-driven runs, runtime env vars exported by the caller are the source of truth.
- `.env` is fallback-only for standalone local Python use.
- All derived paths are rooted in SCODE, SDATA, TMP, OUT, or RAW.
"""

from __future__ import annotations

import os
from pathlib import Path

ENV_FILE = Path(__file__).with_name(".env")


def _load_env_file(env_file: Path) -> None:
    for raw_line in env_file.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


if ENV_FILE.exists():
    _load_env_file(ENV_FILE)


def _required_path(var_name: str) -> Path:
    value = os.getenv(var_name)
    if not value:
        raise EnvironmentError(
            f"Missing required environment variable: {var_name}. "
            "Set it in REPO/.env."
        )
    return Path(value).expanduser()


def _optional_path(var_name: str) -> Path | None:
    value = os.getenv(var_name)
    if not value:
        return None
    return Path(value).expanduser()


def _derived_or_error(var_name: str, fallback: Path | None, dependency_name: str) -> Path:
    direct = _optional_path(var_name)
    if direct is not None:
        return direct
    if fallback is not None:
        return fallback
    raise EnvironmentError(
        f"Missing required environment variable: {var_name}. "
        f"Set {var_name} directly, or define {dependency_name} so it can be derived."
    )


SCODE = _optional_path("SCODE") or Path(__file__).resolve().parent
SDATA = _optional_path("SDATA")

# Data roots
RAW = _derived_or_error("RAW", SDATA / "raw" if SDATA is not None else None, "SDATA")
SEG = RAW
SHRUG = RAW / "shrug"
MOBILITY = RAW / "mobility"
PC11 = RAW / "pc11"
PC01 = RAW / "pc01"

# Runtime/output roots
TMP = _derived_or_error("TMP", SDATA / "tmp" if SDATA is not None else None, "SDATA")
OUT = _derived_or_error("OUT", SDATA / "out" if SDATA is not None else None, "SDATA")

# Code/tool roots
TOOLS = SCODE / "tools"

# Ensure runtime dirs exist before python scripts write to them.
TMP.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
