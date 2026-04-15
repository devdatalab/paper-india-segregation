from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
from typing import Iterable

import pandas as pd

DEFAULT_ROOT = Path("/dartfs-hpc/rc/home/m/f00858m/iec/seg")
DEFAULT_OUTPUT_DIR = Path("/scratch/siddiqui/seg_cleanup")
XML_HEADER_PREFIX = b"<stata_dta>"
VARNAMES_END_TAG = b"</varnames>"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract mechanical metadata from Stata datasets under $iec/seg."
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=DEFAULT_ROOT,
        help="Directory to scan for .dta files.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help="Directory where CSV outputs will be written.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Optional file limit for testing.",
    )
    return parser.parse_args()


def iter_dta_files(root: Path) -> Iterable[Path]:
    yield from (path for path in root.rglob("*.dta") if path.is_file())


def parse_xml_tag(blob: bytes, tag_name: str) -> bytes:
    start_tag = f"<{tag_name}>".encode("ascii")
    end_tag = f"</{tag_name}>".encode("ascii")
    start = blob.find(start_tag)
    end = blob.find(end_tag)
    if start < 0 or end < 0:
        raise ValueError(f"Missing tag <{tag_name}> in Stata header")
    return blob[start + len(start_tag) : end]


def read_header_prefix(path: Path, end_tag: bytes = VARNAMES_END_TAG) -> bytes:
    chunks: list[bytes] = []
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(8192)
            if not chunk:
                break
            chunks.append(chunk)
            joined = b"".join(chunks)
            if end_tag in joined:
                return joined
            if len(joined) > 1_000_000:
                raise ValueError(f"Header too large to parse safely: {path}")
    raise ValueError(f"Could not find {end_tag!r} in {path}")


def parse_stata_header(path: Path) -> tuple[int, int, list[str]]:
    header = read_header_prefix(path)
    if not header.startswith(XML_HEADER_PREFIX):
        raise ValueError("Unsupported non-XML Stata header format")

    byteorder = parse_xml_tag(header, "byteorder").decode("ascii").strip().lower()
    endian = "little" if byteorder == "lsf" else "big"

    n_vars_raw = parse_xml_tag(header, "K")
    n_obs_raw = parse_xml_tag(header, "N")
    varnames_raw = parse_xml_tag(header, "varnames")

    n_vars = int.from_bytes(n_vars_raw, endian)
    n_obs = int.from_bytes(n_obs_raw, endian)
    if n_vars == 0:
        raise ValueError(f"Parsed zero variables from {path}")

    field_width, remainder = divmod(len(varnames_raw), n_vars)
    if remainder != 0:
        raise ValueError(
            f"Variable-name section length {len(varnames_raw)} is not divisible by {n_vars}"
        )

    variable_names = [
        varnames_raw[offset : offset + field_width]
        .split(b"\x00", 1)[0]
        .decode("utf-8", errors="replace")
        for offset in range(0, len(varnames_raw), field_width)
    ]

    return n_obs, n_vars, variable_names


def read_stata_metadata(path: Path) -> dict[str, object]:
    file_size = path.stat().st_size
    try:
        n_obs, n_vars, variable_names = parse_stata_header(path)
    except Exception:
        frame = pd.read_stata(path, convert_categoricals=False)
        n_obs, n_vars = frame.shape
        variable_names = frame.columns.tolist()

    return {
        "file_size_bytes": file_size,
        "n_obs": int(n_obs),
        "n_vars": int(n_vars),
        "variable_names": variable_names,
    }


def build_inventory(
    root: Path, limit: int | None = None
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    rows: list[dict[str, object]] = []
    duplicate_groups: defaultdict[tuple[int, tuple[str, ...]], list[str]] = defaultdict(list)
    error_rows: list[dict[str, str]] = []

    for index, path in enumerate(iter_dta_files(root), start=1):
        if limit is not None and index > limit:
            break

        filename = str(path)
        try:
            metadata = read_stata_metadata(path)
            variable_names = metadata["variable_names"]
            rows.append(
                {
                    "filename": filename,
                    "n_obs": metadata["n_obs"],
                    "n_vars": metadata["n_vars"],
                    "variable_list": ";".join(variable_names),
                    "file_size_bytes": metadata["file_size_bytes"],
                }
            )
            duplicate_key = (int(metadata["n_obs"]), tuple(variable_names))
            duplicate_groups[duplicate_key].append(filename)
        except Exception as exc:
            rows.append(
                {
                    "filename": filename,
                    "n_obs": "",
                    "n_vars": "",
                    "variable_list": "",
                    "file_size_bytes": path.stat().st_size,
                }
            )
            error_rows.append(
                {
                    "filename": filename,
                    "error_type": type(exc).__name__,
                    "error_message": str(exc),
                }
            )

        if index % 500 == 0:
            print(f"Processed {index} files...")

    inventory = pd.DataFrame(rows).sort_values("filename").reset_index(drop=True)

    duplicate_rows: list[dict[str, object]] = []
    duplicate_group_id = 0
    for (n_obs, variable_names), filenames in duplicate_groups.items():
        if len(filenames) < 2:
            continue
        duplicate_group_id += 1
        for filename in sorted(filenames):
            duplicate_rows.append(
                {
                    "duplicate_group": duplicate_group_id,
                    "filename": filename,
                    "n_obs": n_obs,
                    "n_vars": len(variable_names),
                    "variable_list": ";".join(variable_names),
                }
            )

    if duplicate_rows:
        duplicates = pd.DataFrame(duplicate_rows).sort_values(
            ["duplicate_group", "filename"]
        ).reset_index(drop=True)
    else:
        duplicates = pd.DataFrame(
            columns=["duplicate_group", "filename", "n_obs", "n_vars", "variable_list"]
        )

    if error_rows:
        errors = pd.DataFrame(error_rows).sort_values("filename").reset_index(drop=True)
    else:
        errors = pd.DataFrame(columns=["filename", "error_type", "error_message"])

    file_sizes = inventory.loc[:, ["filename", "file_size_bytes"]].copy()
    return inventory, file_sizes, duplicates, errors


def main() -> None:
    args = parse_args()
    root = args.root.expanduser().resolve()
    output_dir = args.output_dir.expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    if not root.exists():
        raise FileNotFoundError(f"Data root does not exist: {root}")

    inventory, file_sizes, duplicates, errors = build_inventory(
        root=root, limit=args.limit
    )

    inventory_path = output_dir / "segdata_file_inventory.csv"
    sizes_path = output_dir / "segdata_file_sizes.csv"
    duplicates_path = output_dir / "segdata_duplicate_groups.csv"
    errors_path = output_dir / "segdata_read_errors.csv"

    inventory.loc[:, ["filename", "n_obs", "n_vars", "variable_list"]].to_csv(
        inventory_path, index=False
    )
    file_sizes.to_csv(sizes_path, index=False)
    duplicates.to_csv(duplicates_path, index=False)
    errors.to_csv(errors_path, index=False)

    print(f"Wrote inventory: {inventory_path}")
    print(f"Wrote file sizes: {sizes_path}")
    print(f"Wrote duplicate groups: {duplicates_path}")
    print(f"Wrote read errors: {errors_path}")


if __name__ == "__main__":
    main()
