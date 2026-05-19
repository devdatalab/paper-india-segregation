#!/usr/bin/env python3
from __future__ import annotations

import csv
import math
import argparse
import traceback
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

from variable_listing_utils import sanitize_sheet_name, write_csv_mirrors, write_xlsx


ROOT = Path(__file__).resolve().parents[1]
INVENTORY_DIR = ROOT / "inventory"
DEFAULT_MANIFEST_PATH = INVENTORY_DIR / "paper_analysis_datasets.csv"
WORKBOOK_PATH = INVENTORY_DIR / "variable_listing.xlsx"
CSV_DIR = INVENTORY_DIR / "variable_listing_csv"
LOG_PATH = INVENTORY_DIR / "logs" / "build_variable_listing.log"

STABLE_PREFIXES = (
    "/dartfs/rc/lab/I/IEC/seg/harmonized/",
    "/dartfs-hpc/rc/lab/I/IEC/seg/harmonized/",
    "/dartfs/rc/lab/I/IEC/seg/clean/",
    "/dartfs-hpc/rc/lab/I/IEC/seg/clean/",
)

INDEX_COLUMNS = [
    "dataset_name",
    "absolute_dataset_path",
    "file_type",
    "n_obs",
    "n_vars",
    "creator_script",
    "producer_script",
    "dataset_stage",
    "sheet_name",
]

VARIABLE_COLUMNS = [
    "dataset_name",
    "variable_name",
    "variable_rename",
    "variable_label",
    "storage_type",
    "is_categorical",
    "levels",
    "value_labels",
    "n_missing",
    "n_obs",
    "pct_missing",
    "used_analysis",
    "used_analysis_scripts",
    "cleaning_flag",
    "rename_suggestion",
    "conflict_flag",
    "remedial_note",
]


def log(message: str) -> None:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("a", encoding="utf-8") as handle:
        handle.write(message.rstrip() + "\n")


def fail(message: str) -> None:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    mode = "a" if LOG_PATH.exists() and LOG_PATH.stat().st_size > 0 else "w"
    with LOG_PATH.open(mode, encoding="utf-8") as handle:
        handle.write(message.rstrip() + "\n")
    raise SystemExit(message)


def read_manifest(manifest_path: Path) -> list[dict[str, str]]:
    if not manifest_path.exists():
        fail(
            f"Missing manifest: {manifest_path}. "
            "Add the manifest or pass --manifest PATH before building variable_listing.xlsx."
        )

    with manifest_path.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        fieldnames = set(reader.fieldnames or [])

    required = {"basename", "absolute_dataset_path"}
    missing = sorted(required - fieldnames)
    if missing:
        fail(
            f"{manifest_path} is missing required columns: "
            + ", ".join(missing)
        )
    return rows


def selected_manifest_rows(
    rows: list[dict[str, str]],
    manifest_path: Path,
    scope: str,
) -> list[dict[str, str]]:
    if not any(row.get("basename", "").strip() == "seg_correlates.dta" for row in rows):
        fail(
            f"seg_correlates.dta is missing from {manifest_path}. "
            "Add its stable handoff row before proceeding."
        )

    def is_handoff(row: dict[str, str]) -> bool:
        return row.get("analysis_handoff", "").strip().lower() in {"1", "true", "yes", "y"}

    def is_stable_path(row: dict[str, str]) -> bool:
        path = row.get("absolute_dataset_path", "").strip()
        return any(path.startswith(prefix) for prefix in STABLE_PREFIXES)

    if scope == "all":
        selected = rows
    elif scope == "all-dta":
        selected = [
            row
            for row in rows
            if row.get("basename", "").strip().lower().endswith(".dta")
        ]
    else:
        selected = [
            row
            for row in rows
            if is_handoff(row) or is_stable_path(row)
        ]

    if not any(row.get("basename", "").strip() == "seg_correlates.dta" for row in selected):
        fail(
            "seg_correlates.dta is present in the manifest but is not selected by the "
            f"{scope} filter. Set analysis_handoff=1, use --scope all, or ensure "
            "absolute_dataset_path points to a selected stable location."
        )

    return sorted(selected, key=lambda row: row.get("basename", "").strip().lower())


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build inventory/variable_listing.xlsx from paper_analysis_datasets.csv.",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=DEFAULT_MANIFEST_PATH,
        help=(
            "Path to paper_analysis_datasets.csv. "
            "Defaults to inventory/paper_analysis_datasets.csv."
        ),
    )
    parser.add_argument(
        "--scope",
        choices=("handoff", "all-dta", "all"),
        default="handoff",
        help=(
            "Rows to scan: handoff keeps analysis_handoff=1 plus stable IEC clean/harmonized paths; "
            "all-dta scans every .dta manifest row; all scans every manifest row with "
            "format-specific handlers."
        ),
    )
    parser.add_argument(
        "--workbook",
        type=Path,
        default=WORKBOOK_PATH,
        help="Output workbook path. Defaults to inventory/variable_listing.xlsx.",
    )
    parser.add_argument(
        "--csv-dir",
        type=Path,
        default=CSV_DIR,
        help="Output directory for per-sheet CSV mirrors.",
    )
    return parser.parse_args()


def metadata_for_dta(path: Path) -> dict[str, Any]:
    with pd.io.stata.StataReader(path) as reader:
        variable_labels = reader.variable_labels()
        value_labels = reader.value_labels()
        state = reader.__dict__
        varlist = list(state.get("_varlist") or [])
        n_obs = int(state.get("_nobs") or 0)
        dtype = state.get("_dtype")
        dtype_descr = list(dtype.descr) if dtype is not None else []
        type_list = list(state.get("_typlist") or [])
        label_sets = list(state.get("_lbllist") or [])

    dtype_by_var = {
        variable: dtype_descr[index][1]
        for index, variable in enumerate(varlist)
        if index < len(dtype_descr)
    }
    storage_by_var = {
        variable: storage_type_from_stata_type(type_list[index])
        for index, variable in enumerate(varlist)
        if index < len(type_list)
    }
    label_set_by_var = {
        variable: label_sets[index] if index < len(label_sets) else ""
        for index, variable in enumerate(varlist)
    }
    return {
        "varlist": varlist,
        "n_obs": n_obs,
        "variable_labels": variable_labels,
        "value_labels": value_labels,
        "dtype_by_var": dtype_by_var,
        "storage_by_var": storage_by_var,
        "label_set_by_var": label_set_by_var,
    }


def storage_type_from_stata_type(stata_type: object) -> str:
    if isinstance(stata_type, int):
        if stata_type <= 0 or stata_type >= 32768:
            return "strL"
        return f"str{stata_type}"

    type_code = str(stata_type)
    return {
        "b": "byte",
        "h": "int",
        "l": "long",
        "f": "float",
        "d": "double",
        "Q": "strL",
    }.get(type_code, type_code)


def storage_type_from_dtype(dtype_code: object) -> str:
    code = str(dtype_code)
    if code.startswith("|S"):
        width_text = code[2:]
        if not width_text.isdigit() or int(width_text) == 0:
            return "strL"
        return f"str{int(width_text)}"
    if code in {"object", "str"}:
        return "strL"

    kind = code[-2:-1]
    size_text = code[-1:]
    if not size_text.isdigit():
        return code
    size = int(size_text)

    if kind in {"i", "u"}:
        return {1: "byte", 2: "int", 4: "long"}.get(size, "double")
    if kind == "f":
        return {4: "float", 8: "double"}.get(size, "double")
    return code


def format_value(value: object) -> str:
    if value is None:
        return ""
    try:
        if pd.isna(value):
            return ""
    except TypeError:
        pass
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace").rstrip("\x00")
    if isinstance(value, (np.integer, int)):
        return str(int(value))
    if isinstance(value, (np.floating, float)):
        number = float(value)
        if math.isfinite(number) and number.is_integer():
            return str(int(number))
        return f"{number:.12g}"
    return str(value)


def value_sort_key(value: object) -> tuple[int, float, str]:
    text = format_value(value)
    try:
        return (0, float(text), text)
    except ValueError:
        return (1, 0.0, text)


def is_string_storage(storage_type: str) -> bool:
    return storage_type.startswith("str")


def is_missing_value(value: object, storage_type: str) -> bool:
    try:
        if pd.isna(value):
            return True
    except TypeError:
        pass
    if not is_string_storage(storage_type):
        return False
    if isinstance(value, bytes):
        return value.rstrip(b"\x00") == b""
    return str(value) == ""


def nonmissing_unique_values(series: pd.Series, storage_type: str, cap: int = 51) -> list[object]:
    unique_by_text: dict[str, object] = {}
    for value in series.array:
        if is_missing_value(value, storage_type):
            continue
        unique_by_text.setdefault(format_value(value), value)
        if len(unique_by_text) > cap:
            break
    return sorted(unique_by_text.values(), key=value_sort_key)


def missing_count(series: pd.Series, storage_type: str) -> int:
    missing = series.isna()
    if is_string_storage(storage_type):
        blank = series.map(
            lambda value: isinstance(value, bytes) and value.rstrip(b"\x00") == b""
            or (not isinstance(value, bytes) and not pd.isna(value) and str(value) == "")
        )
        missing = missing | blank
    return int(missing.sum())


def format_levels(values: list[object]) -> str:
    if len(values) > 50:
        return ">50 levels"
    return "; ".join(format_value(value) for value in values)


def format_value_labels(label_map: dict[object, object]) -> str:
    if not label_map:
        return ""
    pairs = []
    for code in sorted(label_map, key=value_sort_key):
        label = label_map[code]
        pairs.append(f"{format_value(code)}={format_value(label)}")
    return "; ".join(pairs)


def blank_variable_row(
    dataset_name: str,
    variable_name: str,
    variable_label: str,
    storage_type: str,
    n_obs: int = 0,
    n_missing: int = 0,
) -> dict[str, object]:
    pct_missing = round(n_missing / n_obs, 3) if n_obs else 0
    return {
        "dataset_name": dataset_name,
        "variable_name": variable_name,
        "variable_rename": "",
        "variable_label": variable_label,
        "storage_type": storage_type,
        "is_categorical": 0,
        "levels": "",
        "value_labels": "",
        "n_missing": n_missing,
        "n_obs": n_obs,
        "pct_missing": f"{pct_missing:.3f}",
        "used_analysis": 0,
        "used_analysis_scripts": "",
        "cleaning_flag": "",
        "rename_suggestion": "",
        "conflict_flag": "",
        "remedial_note": "",
    }


def pandas_storage_type(dtype: object) -> str:
    text = str(dtype)
    if text.startswith("int"):
        return "long"
    if text.startswith("float"):
        return "double"
    if text in {"bool", "boolean"}:
        return "byte"
    if text.startswith("datetime"):
        return "datetime"
    if text == "geometry":
        return "geometry"
    return "strL"


def variable_rows_for_frame(
    dataset_name: str,
    df: pd.DataFrame,
    variable_labels: dict[str, str] | None = None,
) -> tuple[list[dict[str, object]], int, int, int]:
    variable_labels = variable_labels or {}
    rows: list[dict[str, object]] = []
    categorical_count = 0
    n_obs = int(df.shape[0])

    for variable in df.columns:
        series = df[variable]
        storage_type = pandas_storage_type(series.dtype)
        integer_typed = storage_type in {"byte", "int", "long"}
        unique_values = nonmissing_unique_values(series, storage_type) if integer_typed else []
        is_categorical = int(integer_typed and len(unique_values) <= 20)
        if is_categorical:
            categorical_count += 1
        n_missing = missing_count(series, storage_type)
        pct_missing = round(n_missing / n_obs, 3) if n_obs else 0
        rows.append(
            {
                "dataset_name": dataset_name,
                "variable_name": variable,
                "variable_rename": "",
                "variable_label": variable_labels.get(variable, ""),
                "storage_type": storage_type,
                "is_categorical": is_categorical,
                "levels": format_levels(unique_values) if is_categorical else "",
                "value_labels": "",
                "n_missing": n_missing,
                "n_obs": n_obs,
                "pct_missing": f"{pct_missing:.3f}",
                "used_analysis": 0,
                "used_analysis_scripts": "",
                "cleaning_flag": "",
                "rename_suggestion": "",
                "conflict_flag": "",
                "remedial_note": "",
            }
        )

    return rows, n_obs, len(df.columns), categorical_count


def variable_rows_for_dta(dataset_name: str, path: Path) -> tuple[list[dict[str, object]], int, int, int]:
    metadata = metadata_for_dta(path)
    df = pd.read_stata(
        path,
        convert_categoricals=False,
        convert_dates=False,
        convert_missing=False,
        preserve_dtypes=True,
    )

    rows: list[dict[str, object]] = []
    categorical_count = 0
    n_obs = int(df.shape[0])

    for variable in metadata["varlist"]:
        storage_type = metadata["storage_by_var"].get(
            variable,
            storage_type_from_dtype(metadata["dtype_by_var"].get(variable, "")),
        )
        series = df[variable]
        label_set = metadata["label_set_by_var"].get(variable, "")
        label_map = metadata["value_labels"].get(label_set, {}) if label_set else {}
        integer_typed = storage_type in {"byte", "int", "long"}
        unique_values = (
            nonmissing_unique_values(series, storage_type)
            if label_map or integer_typed
            else []
        )
        is_categorical = int(bool(label_map) or (integer_typed and len(unique_values) <= 20))
        if is_categorical:
            categorical_count += 1

        n_missing = missing_count(series, storage_type)
        pct_missing = round(n_missing / n_obs, 3) if n_obs else 0

        rows.append(
            {
                "dataset_name": dataset_name,
                "variable_name": variable,
                "variable_rename": "",
                "variable_label": metadata["variable_labels"].get(variable, ""),
                "storage_type": storage_type,
                "is_categorical": is_categorical,
                "levels": format_levels(unique_values) if is_categorical else "",
                "value_labels": format_value_labels(label_map),
                "n_missing": n_missing,
                "n_obs": n_obs,
                "pct_missing": f"{pct_missing:.3f}",
                "used_analysis": 0,
                "used_analysis_scripts": "",
                "cleaning_flag": "",
                "rename_suggestion": "",
                "conflict_flag": "",
                "remedial_note": "",
            }
        )

    return rows, n_obs, len(metadata["varlist"]), categorical_count


def variable_rows_for_csv(dataset_name: str, path: Path) -> tuple[list[dict[str, object]], int, int, int]:
    df = pd.read_csv(path, low_memory=False)
    return variable_rows_for_frame(dataset_name, df)


def variable_rows_for_geofile(dataset_name: str, path: Path) -> tuple[list[dict[str, object]], int, int, int]:
    import geopandas as gpd

    df = gpd.read_file(path)
    return variable_rows_for_frame(dataset_name, df)


def variable_rows_for_sidecar(dataset_name: str, path: Path) -> tuple[list[dict[str, object]], int, int, int]:
    suffix = path.suffix.lower().lstrip(".") or "file"
    row = blank_variable_row(
        dataset_name,
        "__file__",
        "Non-tabular shapefile sidecar; no variable-level schema extracted.",
        suffix,
        n_obs=1,
    )
    return [row], 1, 1, 0


def variable_rows_for_missing_file(
    dataset_name: str,
    path: Path,
) -> tuple[list[dict[str, object]], int, int, int]:
    row = blank_variable_row(
        dataset_name,
        "__missing_file__",
        f"File listed in manifest but not found on this server: {path}",
        "missing_file",
    )
    return [row], 0, 1, 0


def variable_rows_for_dataset(dataset_name: str, path: Path) -> tuple[list[dict[str, object]], int, int, int]:
    if not path.exists():
        log(f"MISSING: {dataset_name} ({path})")
        return variable_rows_for_missing_file(dataset_name, path)

    suffix = path.suffix.lower()
    if suffix == ".dta":
        return variable_rows_for_dta(dataset_name, path)
    if suffix == ".csv":
        return variable_rows_for_csv(dataset_name, path)
    if suffix in {".dbf", ".shp"}:
        return variable_rows_for_geofile(dataset_name, path)
    if suffix in {".shx", ".prj"}:
        return variable_rows_for_sidecar(dataset_name, path)

    log(f"UNSUPPORTED: {dataset_name} ({path}); writing file-level placeholder.")
    row = blank_variable_row(
        dataset_name,
        "__unsupported_file__",
        f"Unsupported file type for schema extraction: {suffix or '<none>'}",
        suffix.lstrip(".") or "file",
        n_obs=1,
    )
    return [row], 1, 1, 0


def main() -> int:
    args = parse_args()
    manifest_path = args.manifest.expanduser().resolve()
    workbook_path = args.workbook.expanduser().resolve()
    csv_dir = args.csv_dir.expanduser().resolve()
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    LOG_PATH.write_text(f"Manifest: {manifest_path}\n", encoding="utf-8")

    manifest_rows = read_manifest(manifest_path)
    selected_rows = selected_manifest_rows(manifest_rows, manifest_path, args.scope)

    used_sheet_names = {"_index", "_conflicts"}
    sheets: list[tuple[str, list[dict[str, object]], list[str]]] = []
    index_rows: list[dict[str, object]] = []
    dataset_sheets: list[tuple[str, list[dict[str, object]], list[str]]] = []
    failures = 0
    missing_placeholders = 0
    file_level_placeholders = 0
    total_vars = 0
    total_categorical = 0

    for row in selected_rows:
        dataset_name = row.get("basename", "").strip()
        dataset_path_text = row.get("absolute_dataset_path", "").strip()
        dataset_path = Path(dataset_path_text) if dataset_path_text else Path("__missing_absolute_dataset_path__")
        sheet_name = sanitize_sheet_name(dataset_name, used_sheet_names)

        try:
            variable_rows, n_obs, n_vars, categorical_count = variable_rows_for_dataset(
                dataset_name,
                dataset_path,
            )
        except Exception as exc:  # noqa: BLE001 - this is an audit log, not a data mutation.
            failures += 1
            log(f"FAILED: {dataset_name} ({dataset_path})")
            log(f"{type(exc).__name__}: {exc}")
            log(traceback.format_exc())
            variable_rows = [
                blank_variable_row(
                    dataset_name,
                    "__load_error__",
                    f"{type(exc).__name__}: {exc}",
                    "load_error",
                )
            ]
            n_obs = 0
            n_vars = 1
            categorical_count = 0

        first_variable = variable_rows[0].get("variable_name", "") if variable_rows else ""
        if first_variable == "__missing_file__":
            missing_placeholders += 1
        if first_variable in {"__file__", "__unsupported_file__", "__missing_file__", "__load_error__"}:
            file_level_placeholders += 1
        total_vars += n_vars
        total_categorical += categorical_count
        index_rows.append(
            {
                "dataset_name": dataset_name,
                "absolute_dataset_path": dataset_path_text,
                "file_type": Path(dataset_name).suffix.lower().lstrip(".") or "file",
                "n_obs": n_obs,
                "n_vars": n_vars,
                "creator_script": row.get("creator_script", ""),
                "producer_script": row.get("producer_script", ""),
                "dataset_stage": row.get("dataset_stage", ""),
                "sheet_name": sheet_name,
            }
        )
        dataset_sheets.append((sheet_name, variable_rows, VARIABLE_COLUMNS))

    sheets.append(("_index", index_rows, INDEX_COLUMNS))
    sheets.extend(dataset_sheets)
    write_xlsx(workbook_path, sheets)
    write_csv_mirrors(csv_dir, sheets)

    print(f"Datasets scanned: {len(index_rows)}")
    print(f"Total variables: {total_vars}")
    print(f"Categorical variables: {total_categorical}")
    print(f"Failed datasets: {failures}")
    print(f"Missing-file placeholders: {missing_placeholders}")
    print(f"File-level placeholders: {file_level_placeholders}")
    if failures:
        print(f"Failure details: {LOG_PATH.relative_to(ROOT)}")
    else:
        log("No dataset load failures.")

    return 1 if failures else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SystemExit:
        raise
    except Exception as exc:  # noqa: BLE001
        fail(f"Unexpected build_variable_listing.py failure: {type(exc).__name__}: {exc}")
