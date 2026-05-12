from __future__ import annotations

import importlib.util
import shutil
import sys
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as ET

import pandas as pd


WORKBOOK_PATH = Path("/dartfs-hpc/scratch/siddiqui/seg_cleanup/seg_dataset_inventory.xlsx")
BACKUP_DIR = Path("/dartfs-hpc/scratch/siddiqui/seg_cleanup/history")
MODULE_PATH = Path("/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/e/build_master_dataset_inventory.py")

FINAL_FACING_SHEETS = {
    "final_standalone_datasets",
    "canonical_complete_datasets",
    "derived_complete_datasets",
    "source_complete_datasets",
    "legacy_complete_datasets",
    "manual_review_queue",
}

FINAL_FACING_KEEP = [
    "basename",
    "filename",
    "top_level_section",
    "subfolder",
    "relative_dir",
    "likely_legacy",
    "legacy_reason",
    "n_obs",
    "n_vars",
    "variable_list",
    "dataset_role",
    "pipeline_stage",
    "represents",
    "final_inventory_class",
    "primary_standalone_flag",
    "family_id",
    "unit_of_observation",
    "conceptual_object",
    "canonical_parent_file",
    "lineage_inputs",
    "lineage_outputs",
    "writer_script",
    "writer_line",
    "reader_scripts",
    "used_in_analysis",
    "evidence_summary",
    "confidence",
    "manual_review_reason",
]

ALL_FILES_KEEP = [
    "basename",
    "filename",
    "top_level_section",
    "subfolder",
    "relative_dir",
    "file_size_bytes",
    "likely_legacy",
    "legacy_reason",
    "n_obs",
    "n_vars",
    "variable_list",
    "dataset_role",
    "pipeline_stage",
    "represents",
    "creator_script",
    "creator_line",
    "creator_basis",
    "documentation_confidence",
    "writer_script",
    "writer_line",
    "linked_complete_dataset_file",
    "linked_complete_dataset_status",
    "complete_dataset_class",
    "lineage_basis",
    "inventory_decision",
    "inventory_decision_note",
    "final_inventory_class",
    "primary_standalone_flag",
    "family_id",
    "unit_of_observation",
    "conceptual_object",
    "canonical_parent_file",
    "lineage_inputs",
    "lineage_outputs",
    "reader_scripts",
    "used_in_analysis",
    "evidence_summary",
    "confidence",
    "manual_review_reason",
]

SUPPORT_KEEP = [
    "basename",
    "dataset_file",
    "support_review_scope",
    "relative_dir",
    "final_inventory_class",
    "primary_standalone_flag",
    "family_id",
    "unit_of_observation",
    "conceptual_object",
    "canonical_parent_file",
    "lineage_inputs",
    "lineage_outputs",
    "writer_script",
    "writer_line",
    "reader_scripts",
    "used_in_analysis",
    "evidence_summary",
    "confidence",
    "manual_review_reason",
]

COLUMN_GUIDE_FIELDS = {
    "basename": ("Leaf filename.", "identity"),
    "filename": ("Absolute file path for the dataset row.", "identity"),
    "dataset_file": ("Absolute file path for the support/key dataset row.", "identity"),
    "top_level_section": ("Top-level directory immediately under `seg`.", "identity"),
    "subfolder": ("Nested folder path below the top-level section.", "identity"),
    "relative_dir": ("Directory path relative to the `seg` root.", "identity"),
    "file_size_bytes": ("File size in bytes.", "structure"),
    "likely_legacy": ("TRUE when the path indicates an old or archive location.", "classification"),
    "legacy_reason": ("Path-based reason the row is treated as legacy-like.", "classification"),
    "n_obs": ("Observed row count from metadata extraction.", "structure"),
    "n_vars": ("Observed variable count from metadata extraction.", "structure"),
    "variable_list": ("Semicolon-delimited variable or column names.", "structure"),
    "dataset_role": ("Heuristic role inferred from filename, path, and code lineage.", "classification"),
    "pipeline_stage": ("High-level pipeline stage represented by the file.", "classification"),
    "represents": ("Human-readable description of the dataset contents.", "classification"),
    "creator_script": ("Best available script that creates the row in the original inventory logic.", "evidence"),
    "creator_line": ("Line number for `creator_script` when available.", "evidence"),
    "creator_basis": ("How the creator mapping was inferred.", "evidence"),
    "documentation_confidence": ("Confidence assigned to the creator mapping.", "evidence"),
    "writer_script": ("Script detected in code lineage as directly writing the dataset.", "lineage"),
    "writer_line": ("Line number for `writer_script` when available.", "lineage"),
    "linked_complete_dataset_file": ("Linked complete dataset when this row feeds or fragments a larger dataset.", "lineage"),
    "linked_complete_dataset_status": ("Status of the linked complete-dataset relation.", "lineage"),
    "complete_dataset_class": ("Legacy complete-dataset bucket from the earlier inventory.", "classification"),
    "lineage_basis": ("Rule basis used to assign parentage or class in the earlier inventory.", "lineage"),
    "inventory_decision": ("Earlier inventory decision before final reviewed cleanup.", "classification"),
    "inventory_decision_note": ("Short explanation for the earlier inventory decision.", "classification"),
    "final_inventory_class": ("Final reviewed taxonomy class.", "classification"),
    "primary_standalone_flag": ("TRUE only for rows retained in the final standalone universe.", "classification"),
    "family_id": ("Family identifier grouping duplicates, variants, and parents.", "classification"),
    "unit_of_observation": ("Best inferred observational unit for the dataset.", "classification"),
    "conceptual_object": ("Substantive object captured by the dataset.", "classification"),
    "canonical_parent_file": ("Immediate parent or canonical representative used for lineage tracing.", "lineage"),
    "lineage_inputs": ("Semicolon-delimited direct upstream inputs found in code lineage.", "lineage"),
    "lineage_outputs": ("Semicolon-delimited direct downstream outputs found in code lineage.", "lineage"),
    "reader_scripts": ("Semicolon-delimited scripts that read the dataset.", "lineage"),
    "used_in_analysis": ("TRUE when the dataset is used in analysis/table/figure code.", "classification"),
    "evidence_summary": ("Short evidence-based summary explaining the classification.", "evidence"),
    "confidence": ("Confidence in the final reviewed classification.", "evidence"),
    "manual_review_reason": ("Reason the row remains ambiguous or was flagged for review.", "evidence"),
    "support_review_scope": ("Whether the support/key row comes from the workbook or only from lineage scanning.", "support_review"),
}


def load_inventory_module():
    spec = importlib.util.spec_from_file_location("build_master_dataset_inventory", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to import helpers from {MODULE_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def excel_col_to_index(ref: str) -> int:
    letters = "".join(ch for ch in ref if ch.isalpha())
    idx = 0
    for ch in letters:
        idx = idx * 26 + (ord(ch) - 64)
    return idx


def read_workbook(workbook_path: Path) -> list[tuple[str, pd.DataFrame]]:
    module = load_inventory_module()
    ns = module.NS_MAIN
    sheets: list[tuple[str, pd.DataFrame]] = []
    with ZipFile(workbook_path) as zf:
        workbook_sheets, shared_strings = module.parse_xlsx_workbook(zf)
        for sheet_name, target in workbook_sheets:
            root = ET.fromstring(zf.read(target))
            rows = root.findall(f"{{{ns}}}sheetData/{{{ns}}}row")
            parsed_rows: list[list[str]] = []
            max_col = 0
            for row in rows:
                values: dict[int, str] = {}
                for cell in row.findall(f"{{{ns}}}c"):
                    idx = excel_col_to_index(cell.attrib.get("r", "A1"))
                    max_col = max(max_col, idx)
                    values[idx] = module.decode_xlsx_cell(cell, shared_strings).strip()
                parsed_rows.append([values.get(i, "") for i in range(1, max_col + 1)])
            if not parsed_rows:
                sheets.append((sheet_name, pd.DataFrame()))
                continue
            header = parsed_rows[0]
            data = parsed_rows[1:]
            if data:
                normalized = [row + [""] * (len(header) - len(row)) for row in data]
                df = pd.DataFrame(normalized, columns=header)
            else:
                df = pd.DataFrame(columns=header)
            sheets.append((sheet_name, df))
    return sheets


def keep_existing_columns(df: pd.DataFrame, keep_order: list[str]) -> pd.DataFrame:
    keep = [col for col in keep_order if col in df.columns]
    return df.loc[:, keep].copy()


def build_column_guide(cleaned_sheets: list[tuple[str, pd.DataFrame]]) -> pd.DataFrame:
    seen: set[str] = set()
    ordered_columns: list[str] = []
    for sheet_name, df in cleaned_sheets:
        if sheet_name == "column_guide":
            continue
        for col in df.columns:
            if col and col not in seen:
                seen.add(col)
                ordered_columns.append(col)
    records = [
        {
            "column": col,
            "meaning": COLUMN_GUIDE_FIELDS.get(col, (f"Retained workbook column `{col}`.", "classification"))[0],
            "category": COLUMN_GUIDE_FIELDS.get(col, ("", "classification"))[1],
        }
        for col in ordered_columns
    ]
    return pd.DataFrame(records, columns=["column", "meaning", "category"])


def clean_sheet(sheet_name: str, df: pd.DataFrame) -> tuple[str, pd.DataFrame]:
    renamed_name = "support_weights_keys" if sheet_name == "supportorkey" else sheet_name

    if sheet_name == "column_guide":
        return renamed_name, df
    if sheet_name == "all_files_with_master":
        return renamed_name, keep_existing_columns(df, ALL_FILES_KEEP)
    if sheet_name == "supportorkey":
        nonblank = df.loc[:, [col for col in df.columns if str(col).strip()]]
        return renamed_name, keep_existing_columns(nonblank, SUPPORT_KEEP)
    if sheet_name in FINAL_FACING_SHEETS:
        return renamed_name, keep_existing_columns(df, FINAL_FACING_KEEP)
    return renamed_name, df


def main() -> None:
    if not WORKBOOK_PATH.exists():
        raise FileNotFoundError(f"Workbook not found: {WORKBOOK_PATH}")

    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    backup_path = BACKUP_DIR / "seg_dataset_inventory.pre_column_cleanup.xlsx"
    shutil.copy2(WORKBOOK_PATH, backup_path)

    original_sheets = read_workbook(WORKBOOK_PATH)
    original_row_counts = {name: len(df) for name, df in original_sheets if name != "column_guide"}

    cleaned_sheets = [clean_sheet(name, df) for name, df in original_sheets if name != "column_guide"]
    cleaned_sheets.append(("column_guide", build_column_guide(cleaned_sheets)))

    cleaned_row_counts = {name: len(df) for name, df in cleaned_sheets if name != "column_guide"}
    original_mapped = {"support_weights_keys" if name == "supportorkey" else name: count for name, count in original_row_counts.items()}
    if original_mapped != cleaned_row_counts:
        raise RuntimeError("Row counts changed during workbook cleanup.")

    for sheet_name, df in cleaned_sheets:
        if sheet_name == "column_guide":
            continue
        blank_headers = [col for col in df.columns if not str(col).strip()]
        if blank_headers:
            raise RuntimeError(f"Sheet {sheet_name} still has blank header cells.")

    module = load_inventory_module()
    module.write_xlsx(WORKBOOK_PATH, cleaned_sheets)

    print(f"Backed up workbook to: {backup_path}")
    print(f"Cleaned workbook in place: {WORKBOOK_PATH}")
    for sheet_name, df in cleaned_sheets:
        print(f"{sheet_name}: {len(df.columns)} columns, {len(df)} rows")


if __name__ == "__main__":
    main()
