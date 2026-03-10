"""
Canonical Python path aliases for the segregation project.

Contract:
- PYTHONPATH must include SCODE so scripts can import `set_paths`.
- A `.env` file must exist at REPO/.env and define SCODE and SDATA.
- All derived paths are rooted in SCODE or SDATA.
"""

from __future__ import annotations

import os
from pathlib import Path

ENV_FILE = Path(__file__).with_name(".env")
if not ENV_FILE.exists():
    raise FileNotFoundError(
        f"Missing required env file: {ENV_FILE}. "
        "Create REPO/.env with SCODE and SDATA."
    )


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


_load_env_file(ENV_FILE)


def _required_path(var_name: str) -> Path:
    value = os.getenv(var_name)
    if not value:
        raise EnvironmentError(
            f"Missing required environment variable: {var_name}. "
            "Set it in REPO/.env."
        )
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
TMP = SDATA / "tmp"
OUT = SDATA / "out"

# Code/tool roots
TOOLS = SCODE / "tools"

# Ensure runtime dirs exist before python scripts write to them.
TMP.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
