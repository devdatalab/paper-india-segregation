"""
Canonical Python path aliases for the segregation project.

Contract:
- PYTHONPATH must include SCODE so scripts can import `set_paths`.
- Runtime env vars from the Stata caller take precedence.
- `.env` is a fallback for local interactive use and should define SCODE and SDATA.
- All derived paths are rooted in SCODE, SDATA, TMP, or OUT.
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


SCODE = _required_path("SCODE")
SDATA = _required_path("SDATA")

# Data roots
RAW = SDATA / "raw"
SEG = RAW
SHRUG = RAW / "shrug"
MOBILITY = RAW / "mobility"
PC11 = RAW / "pc11"
PC01 = RAW / "pc01"

# Runtime/output roots
TMP = _optional_path("TMP") or (SDATA / "tmp")
OUT = _optional_path("OUT") or (SDATA / "out")

# Code/tool roots
TOOLS = SCODE / "tools"

# Ensure runtime dirs exist before python scripts write to them.
TMP.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
