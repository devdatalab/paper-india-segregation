from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import zipfile
from collections import deque
from dataclasses import dataclass
from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path, PurePosixPath
from typing import Iterable
from xml.etree import ElementTree as ET
from xml.sax.saxutils import escape

import pandas as pd

SEG_ROOT = Path("/dartfs/rc/lab/I/IEC/seg")
HANDBOOK_ROOT = SEG_ROOT / "raw" / "handbook_ebs"
HANDBOOK_APPENDED = HANDBOOK_ROOT / "handbook_appended.csv"
HANDBOOK_COMBINED = HANDBOOK_ROOT / "combined_dataset.csv"
HANDBOOK_PC0111_ANALYSIS = SEG_ROOT / "clean" / "segregation_pc0111.dta"
DEFAULT_DTA_INVENTORY = Path("/dartfs-hpc/scratch/siddiqui/seg_cleanup/segdata_file_inventory.csv")
DEFAULT_OUTPUT_DIR = Path("/dartfs-hpc/scratch/siddiqui/seg_cleanup/metadata")
CODE_SEARCH_ROOTS = [
    Path("/dartfs-hpc/rc/home/m/f00858m/ddl/core"),
    Path("/dartfs-hpc/rc/home/m/f00858m/ddl/segregation"),
    Path("/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation"),
]

SUPPORTED_SUFFIXES = {".dta", ".csv", ".xlsx", ".xls", ".geojson"}
CODE_SUFFIXES = ("*.do", "*.py", "*.script", "*.sh")

NS_MAIN = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
NS_REL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
NS_PKG = "http://schemas.openxmlformats.org/package/2006/relationships"

SUPPORT_TOKENS = {
    "key",
    "keys",
    "crosswalk",
    "weights",
    "weight",
    "handbook",
    "appendix",
    "manifest",
    "pdf",
    "lookup",
}

ANALYSIS_MARKERS = (
    "collapsed",
    "blockdata",
    "citydata",
    "villagedata",
    "towndata",
    "pooled",
    "appended",
    "dissim",
    "segregation_blockdata",
    "ed_health",
)

TRACKED_CHANGE_COLUMNS = [
    "file_size_bytes",
    "n_obs",
    "n_vars",
    "variable_list",
    "dataset_role",
    "pipeline_stage",
    "is_analysis_ready_standalone",
    "master_pooled_file",
    "master_mapping_status",
    "master_mapping_basis",
    "master_mapping_note",
    "linked_complete_dataset_file",
    "linked_complete_dataset_status",
    "linked_complete_dataset_note",
    "complete_dataset_class",
    "canonical_parent_file",
    "lineage_basis",
    "inventory_decision",
    "inventory_decision_note",
    "excluded_from_canonical_reason",
]

COMPLETE_DATASET_CLASSES = ("canonical", "derived", "source", "legacy")
REFERENCE_REPO_NOTE = "reference_repo_lineage"


@dataclass(frozen=True)
class RuleMatch:
    dataset_role: str
    pipeline_stage: str
    represents: str
    creator_script: str
    creator_line: int
    creator_basis: str
    documentation_confidence: str
    is_complete_standalone: bool
    is_analysis_ready_standalone: bool


@dataclass(frozen=True)
class DatasetRule:
    pattern: re.Pattern[str]
    value_builder: callable

    def match(self, filename: str, basename: str, relative_dir: str) -> RuleMatch | None:
        match = self.pattern.match(basename)
        if match is None:
            return None
        return self.value_builder(match, filename, basename, relative_dir)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build a structured-data inventory with standalone-dataset documentation."
    )
    parser.add_argument("--root", type=Path, default=SEG_ROOT, help="Root dataset directory to scan.")
    parser.add_argument(
        "--dta-inventory",
        type=Path,
        default=DEFAULT_DTA_INVENTORY,
        help="Existing .dta inventory CSV used to avoid re-reading all Stata files.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help="Directory where workbook and flat exports will be written.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Optional limit on total files for testing.",
    )
    return parser.parse_args()


def path_after_seg(filename: str) -> tuple[str, ...]:
    parts = PurePosixPath(filename).parts
    if "seg" not in parts:
        return parts[-1:]
    seg_idx = max(idx for idx, part in enumerate(parts) if part == "seg")
    return parts[seg_idx + 1 :]


def parse_filename_fields(filename: str) -> dict[str, str]:
    rel_parts = path_after_seg(filename)
    basename = rel_parts[-1] if rel_parts else PurePosixPath(filename).name
    directory_parts = rel_parts[:-1]
    top_level_section = directory_parts[0] if directory_parts else ""
    subfolder = "/".join(directory_parts[1:]) if len(directory_parts) > 1 else ""
    relative_dir = "/".join(directory_parts)
    return {
        "top_level_section": top_level_section,
        "subfolder": subfolder,
        "relative_dir": relative_dir,
        "basename": basename,
    }


def legacy_reason(filename: str) -> str:
    reasons: list[str] = []
    if "old-2020" in filename:
        reasons.append("old-2020")
    if "/old/" in filename:
        reasons.append("/old/")
    if "clean/nbd_sizes_old" in filename:
        reasons.append("clean/nbd_sizes_old")
    return ";".join(reasons)


def normalize_extension(path: Path) -> str:
    name = path.name.lower()
    if name.endswith("csv*"):
        return ".csv"
    suffix = path.suffix.lower()
    return suffix if suffix in SUPPORTED_SUFFIXES else ""


def iter_structured_files(root: Path, limit: int | None = None) -> Iterable[Path]:
    count = 0
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        filenames.sort()
        for filename in filenames:
            path = Path(dirpath) / filename
            if normalize_extension(path):
                yield path
                count += 1
                if limit is not None and count >= limit:
                    return


def load_dta_inventory(inventory_path: Path) -> dict[str, dict[str, object]]:
    inventory = pd.read_csv(inventory_path)
    return inventory.set_index("filename").to_dict(orient="index")


def sniff_csv_dialect(sample: str) -> csv.Dialect:
    try:
        return csv.Sniffer().sniff(sample)
    except csv.Error:
        return csv.get_dialect("excel")


def read_csv_metadata(path: Path) -> dict[str, object]:
    with path.open("rb") as raw_handle:
        sample_bytes = raw_handle.read(16_384)
        raw_handle.seek(0)
        line_count = sum(1 for _ in raw_handle)

    sample = sample_bytes.decode("utf-8", errors="replace")
    first_line = sample.splitlines()[0] if sample.splitlines() else ""
    if not first_line:
        return {
            "n_obs": 0,
            "n_vars": 0,
            "variable_list": "",
            "structure_metadata_status": "full",
            "structure_notes": "empty csv",
        }

    dialect = sniff_csv_dialect(sample)
    header = next(csv.reader([first_line], dialect))
    columns = [str(cell).strip() for cell in header]
    return {
        "n_obs": max(line_count - 1, 0),
        "n_vars": len(columns),
        "variable_list": ";".join(columns),
        "structure_metadata_status": "full",
        "structure_notes": f"delimiter={dialect.delimiter!r};line_count_based",
    }


def col_ref_to_index(cell_ref: str) -> int:
    letters = "".join(ch for ch in cell_ref if ch.isalpha())
    if not letters:
        return 0
    value = 0
    for char in letters:
        value = (value * 26) + (ord(char.upper()) - 64)
    return value


def parse_shared_strings(zf: zipfile.ZipFile) -> list[str]:
    try:
        raw = zf.read("xl/sharedStrings.xml")
    except KeyError:
        return []
    root = ET.fromstring(raw)
    strings: list[str] = []
    for si in root.findall(f"{{{NS_MAIN}}}si"):
        text = "".join(node.text or "" for node in si.iterfind(f".//{{{NS_MAIN}}}t"))
        strings.append(text)
    return strings


def parse_xlsx_workbook(zf: zipfile.ZipFile) -> tuple[list[tuple[str, str]], list[str]]:
    wb_root = ET.fromstring(zf.read("xl/workbook.xml"))
    rel_root = ET.fromstring(zf.read("xl/_rels/workbook.xml.rels"))
    rel_map = {
        rel.attrib["Id"]: rel.attrib["Target"]
        for rel in rel_root.findall(f"{{{NS_PKG}}}Relationship")
    }
    sheets: list[tuple[str, str]] = []
    for sheet in wb_root.findall(f".//{{{NS_MAIN}}}sheet"):
        rel_id = sheet.attrib.get(f"{{{NS_REL}}}id", "")
        target = rel_map.get(rel_id, "")
        if target and not target.startswith("xl/"):
            target = f"xl/{target}"
        sheets.append((sheet.attrib.get("name", ""), target))
    return sheets, parse_shared_strings(zf)


def decode_xlsx_cell(cell: ET.Element, shared_strings: list[str]) -> str:
    cell_type = cell.attrib.get("t", "")
    if cell_type == "inlineStr":
        return "".join(node.text or "" for node in cell.iterfind(f".//{{{NS_MAIN}}}t"))
    value_node = cell.find(f"{{{NS_MAIN}}}v")
    value = "" if value_node is None or value_node.text is None else value_node.text
    if cell_type == "s":
        try:
            return shared_strings[int(value)]
        except Exception:
            return value
    return value


def read_xlsx_metadata(path: Path) -> dict[str, object]:
    with zipfile.ZipFile(path) as zf:
        sheets, shared_strings = parse_xlsx_workbook(zf)
        if not sheets:
            return {
                "n_obs": pd.NA,
                "n_vars": pd.NA,
                "variable_list": "",
                "structure_metadata_status": "partial",
                "structure_notes": "xlsx without worksheets",
            }

        sheet_name, target = sheets[0]
        ws_root = ET.fromstring(zf.read(target))
        rows = ws_root.findall(f".//{{{NS_MAIN}}}sheetData/{{{NS_MAIN}}}row")

        header_cells: list[str] = []
        max_cols = 0
        for idx, row in enumerate(rows, start=1):
            values: dict[int, str] = {}
            for cell in row.findall(f"{{{NS_MAIN}}}c"):
                col_idx = col_ref_to_index(cell.attrib.get("r", ""))
                max_cols = max(max_cols, col_idx)
                values[col_idx] = decode_xlsx_cell(cell, shared_strings).strip()
            if idx == 1:
                if values:
                    header_cells = [values.get(i, "") for i in range(1, max(values) + 1)]
                else:
                    header_cells = []

    return {
        "n_obs": max(len(rows) - 1, 0),
        "n_vars": len(header_cells) if header_cells else (max_cols or pd.NA),
        "variable_list": ";".join(header_cells),
        "structure_metadata_status": "partial",
        "structure_notes": f"first_sheet={sheet_name};sheet_count={len(sheets)}",
    }


def read_xls_metadata(path: Path) -> dict[str, object]:
    return {
        "n_obs": pd.NA,
        "n_vars": pd.NA,
        "variable_list": "",
        "structure_metadata_status": "engine_unavailable",
        "structure_notes": "xls reader engine not installed",
    }


def read_geojson_metadata(path: Path) -> dict[str, object]:
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        data = json.load(handle)
    features = data.get("features", [])
    property_keys = sorted(
        {
            key
            for feature in features
            for key in (feature.get("properties") or {}).keys()
        }
    )
    return {
        "n_obs": len(features),
        "n_vars": len(property_keys),
        "variable_list": ";".join(property_keys),
        "structure_metadata_status": "full",
        "structure_notes": "geojson features/properties parsed",
    }


def read_non_dta_metadata(path: Path) -> dict[str, object]:
    ext = normalize_extension(path)
    if ext == ".csv":
        return read_csv_metadata(path)
    if ext == ".xlsx":
        return read_xlsx_metadata(path)
    if ext == ".xls":
        return read_xls_metadata(path)
    if ext == ".geojson":
        return read_geojson_metadata(path)
    raise ValueError(f"Unsupported structured file type: {path}")


def should_skip_deep_parse(filename: str, top_level_section: str) -> bool:
    lowered = filename.lower()
    if lowered.endswith("/raw/handbook_ebs/combined_dataset.csv"):
        return False
    if lowered.endswith("/raw/handbook_ebs/handbook_appended.csv"):
        return False
    if top_level_section == "raw":
        return True
    if "/old-2020/raw/" in lowered:
        return True
    if "handbook_ebs/" in lowered:
        return True
    if "/ocr/" in lowered:
        return True
    return False


def shorten_code_path(path: str | Path) -> str:
    path = Path(path)
    anchor = Path("/dartfs-hpc/rc/home/m/f00858m")
    try:
        return str(path.relative_to(anchor))
    except ValueError:
        return str(path)


def normalize_handbook_text(value: str) -> str:
    text = str(value).strip().lower()
    text = text.replace(".", "")
    text = text.replace(",", "")
    text = re.sub(r"\s+", " ", text)
    return text


def normalize_handbook_numeric(value: str) -> str:
    digits = re.sub(r"\D", "", str(value))
    return digits


def make_handbook_eb_key(
    town_id: str,
    town_name: str,
    ward: str,
    eb: str,
    total_pop: str,
) -> tuple[str, str, str, str, str] | None:
    town_id_norm = normalize_handbook_numeric(town_id)
    total_pop_norm = normalize_handbook_numeric(total_pop)
    town_name_norm = normalize_handbook_text(town_name)
    ward_norm = normalize_handbook_text(ward)
    eb_norm = normalize_handbook_text(eb)
    if not all([town_id_norm, town_name_norm, ward_norm, eb_norm, total_pop_norm]):
        return None
    return (town_id_norm, town_name_norm, ward_norm, eb_norm, total_pop_norm)


@lru_cache(maxsize=1)
def handbook_appended_keyset() -> frozenset[tuple[str, str, str, str, str]]:
    keys: set[tuple[str, str, str, str, str]] = set()
    with HANDBOOK_APPENDED.open(newline="") as handle:
        reader = csv.reader(handle)
        next(reader, None)
        for row in reader:
            if len(row) < 8:
                continue
            key = make_handbook_eb_key(row[3], row[4], row[5], row[6], row[7])
            if key is not None:
                keys.add(key)
    return frozenset(keys)


@lru_cache(maxsize=10000)
def handbook_page_matches_appended(filename: str) -> bool:
    path = Path(filename)
    if path.parent == HANDBOOK_ROOT:
        return False
    if path.suffix.lower() != ".csv":
        return False
    if "handbook_ebs" not in filename:
        return False
    try:
        with path.open(newline="") as handle:
            reader = csv.reader(handle)
            header = next(reader, None)
            if header is None:
                return False
            if not {"1", "2", "3", "4", "5"}.issubset(header):
                return False
            idx_town_id = header.index("1")
            idx_town_name = header.index("2")
            idx_ward = header.index("3")
            idx_eb = header.index("4")
            idx_total_pop = header.index("5")
            for row in reader:
                if len(row) <= max(idx_town_id, idx_town_name, idx_ward, idx_eb, idx_total_pop):
                    continue
                key = make_handbook_eb_key(
                    row[idx_town_id],
                    row[idx_town_name],
                    row[idx_ward],
                    row[idx_eb],
                    row[idx_total_pop],
                )
                if key is not None and key in handbook_appended_keyset():
                    return True
    except Exception:
        return False
    return False


def sector_label(match: re.Match[str], group_name: str = "sector") -> str:
    return match.groupdict().get(group_name, match.group(1) if match.groups() else "")


def build_rule_match(
    *,
    dataset_role: str,
    pipeline_stage: str,
    represents: str,
    creator_script: str,
    creator_line: int,
    creator_basis: str,
    documentation_confidence: str,
    is_complete_standalone: bool,
    is_analysis_ready_standalone: bool,
) -> RuleMatch:
    return RuleMatch(
        dataset_role=dataset_role,
        pipeline_stage=pipeline_stage,
        represents=represents,
        creator_script=creator_script,
        creator_line=creator_line,
        creator_basis=creator_basis,
        documentation_confidence=documentation_confidence,
        is_complete_standalone=is_complete_standalone,
        is_analysis_ready_standalone=is_analysis_ready_standalone,
    )


RULES: list[DatasetRule] = [
    DatasetRule(
        pattern=re.compile(r"^ec13__city\.dta$", re.I),
        value_builder=lambda m, *_: build_rule_match(
            dataset_role="artifact_misnamed_crosswalk",
            pipeline_stage="bad collapsed EC13 artifact",
            represents=(
                "Misnamed EC13/PC11 identifier crosswalk artifact. It is not a "
                "complete city-level EC13 dataset and is excluded from complete inventories."
            ),
            creator_script=pd.NA,
            creator_line=pd.NA,
            creator_basis="artifact_no_creator_found",
            documentation_confidence="high",
            is_complete_standalone=False,
            is_analysis_ready_standalone=False,
        ),
    ),
    DatasetRule(
        pattern=re.compile(r"^ec13_(?P<sector>rural|urban)_(?P<unit>city|block)\.dta$", re.I),
        value_builder=lambda m, *_: build_rule_match(
            dataset_role="ec13_collapsed_master",
            pipeline_stage="clean collapsed EC13 master",
            represents=(
                f"Complete collapsed EC13 {m.group('unit')}-level dataset for "
                f"{m.group('sector')} areas, used as an input to SECC-EC merges."
            ),
            creator_script="ddl/segregation/b/not-used/gen_ec_block_city_data.do",
            creator_line=341 if m.group("unit").lower() == "city" else 326,
            creator_basis="template_save_match",
            documentation_confidence="high",
            is_complete_standalone=True,
            is_analysis_ready_standalone=True,
        ),
    ),
    DatasetRule(
        pattern=re.compile(r"^secc_(?P<sector>rural|urban)_collapsed_block\.dta$", re.I),
        value_builder=lambda m, *_: build_rule_match(
            dataset_role="collapsed_master",
            pipeline_stage="clean collapsed master",
            represents=f"SECC block-level collapsed master dataset for {sector_label(m)} areas.",
            creator_script="ddl/segregation/b/discovery/assemble_secc_small_part.do",
            creator_line=74,
            creator_basis="template_save_match",
            documentation_confidence="high",
            is_complete_standalone=True,
            is_analysis_ready_standalone=True,
        ),
    ),
    DatasetRule(
        pattern=re.compile(r"^secc_(?P<sector>rural|urban)_collapsed\.dta$", re.I),
        value_builder=lambda m, *_: build_rule_match(
            dataset_role="collapsed_master",
            pipeline_stage="clean collapsed master",
            represents=f"SECC upper-level collapsed master dataset for {sector_label(m)} areas.",
            creator_script="ddl/segregation/b/discovery/assemble_secc_small_part.do",
            creator_line=74,
            creator_basis="template_save_match",
            documentation_confidence="high",
            is_complete_standalone=True,
            is_analysis_ready_standalone=True,
        ),
    ),
    DatasetRule(
        pattern=re.compile(r"^secc_(?P<sector>rural|urban)_individual_sample\.dta$", re.I),
        value_builder=lambda m, *_: build_rule_match(
            dataset_role="individual_sample_master",
            pipeline_stage="clean full individual sample",
            represents=f"Full clean SECC {m.group('sector')} individual-level sample assembled from partitioned individual-sample files.",
            creator_script="reference_repo:b/clean_individual_sample.do",
            creator_line=72,
            creator_basis=REFERENCE_REPO_NOTE,
            documentation_confidence="medium",
            is_complete_standalone=True,
            is_analysis_ready_standalone=True,
        ),
    ),
    DatasetRule(
        pattern=re.compile(r"^secc_(?P<sector>rural|urban)_individual_sample_(?P<variant>10p|1p|slum)\.dta$", re.I),
        value_builder=lambda m, *_: build_rule_match(
            dataset_role="derived_individual_sample",
            pipeline_stage="derived individual sample variant",
            represents=(
                f"Derived SECC {m.group('sector')} individual-level "
                f"{m.group('variant')} variant of the full clean individual sample."
            ),
            creator_script=(
                "reference_repo:b/clean_individual_sample.do"
                if m.group("variant").lower() in {"10p", "1p"}
                else pd.NA
            ),
            creator_line=(
                78
                if m.group("variant").lower() == "10p"
                else 84
                if m.group("variant").lower() == "1p"
                else pd.NA
            ),
            creator_basis=(
                REFERENCE_REPO_NOTE
                if m.group("variant").lower() in {"10p", "1p"}
                else "derived_variant_no_creator_found"
            ),
            documentation_confidence="medium",
            is_complete_standalone=True,
            is_analysis_ready_standalone=True,
        ),
    ),
    DatasetRule(
        pattern=re.compile(r"^secc_ec_(?P<unit>city|block)data_(?P<sector>rural|urban)\.dta$", re.I),
        value_builder=lambda m, *_: build_rule_match(
            dataset_role="merged_analysis_input",
            pipeline_stage="merged secc-ec dataset",
            represents=f"SECC-EC merged {m.group('unit')}-level dataset for {m.group('sector')} areas.",
            creator_script="ddl/paper-india-segregation/b/merge_secc_ec.do",
            creator_line=88 if m.group("unit").lower() == "block" else 72,
            creator_basis="exact_save_match",
            documentation_confidence="high",
            is_complete_standalone=True,
            is_analysis_ready_standalone=True,
        ),
    ),
    DatasetRule(
        pattern=re.compile(r"^secc_(?P<sector>rural|urban)_block_to_nbd_(?P<threshold>.+)_key\.dta$", re.I),
        value_builder=lambda m, *_: build_rule_match(
            dataset_role="support_key_lookup",
            pipeline_stage="block grouping support key",
            represents=f"Key mapping SECC {m.group('sector')} blocks to neighborhood groups at threshold {m.group('threshold')}.",
            creator_script="ddl/paper-india-segregation/seg_programs.do",
            creator_line=981,
            creator_basis="exact_save_match",
            documentation_confidence="high",
            is_complete_standalone=True,
            is_analysis_ready_standalone=False,
        ),
    ),
    DatasetRule(
        pattern=re.compile(r"^pc11_muslims_(?P<sector>rural|urban)\.dta$", re.I),
        value_builder=lambda m, *_: build_rule_match(
            dataset_role="support_key_lookup",
            pipeline_stage="pc11 religion support key",
            represents=(
                f"PC11 {m.group('sector')} Muslim population share key by "
                f"{'subdistrict' if m.group('sector').lower() == 'rural' else 'town'} "
                "used in segregation citydata builds and representativeness checks."
            ),
            creator_script="ddl/paper-india-segregation/b/gen_pc_muslim_share.do",
            creator_line=42 if m.group("sector").lower() == "rural" else 62,
            creator_basis="exact_save_match",
            documentation_confidence="high",
            is_complete_standalone=True,
            is_analysis_ready_standalone=False,
        ),
    ),
    DatasetRule(
        pattern=re.compile(r"^violence_matched_except_jk\.dta$", re.I),
        value_builder=lambda m, *_: build_rule_match(
            dataset_role="raw_source_extract",
            pipeline_stage="raw input to violence analysis build",
            represents="Matched violence-event source data outside Jammu and Kashmir used to build shrid-level violence measures.",
            creator_script="ddl/paper-india-segregation/b/prep_correlates.do",
            creator_line=31,
            creator_basis="downstream_usage_only",
            documentation_confidence="high",
            is_complete_standalone=False,
            is_analysis_ready_standalone=False,
        ),
    ),
    DatasetRule(
        pattern=re.compile(r"^violence_matched_jk\.dta$", re.I),
        value_builder=lambda m, *_: build_rule_match(
            dataset_role="raw_source_extract",
            pipeline_stage="raw input to violence analysis build",
            represents="Matched violence-event source data for Jammu and Kashmir used to build shrid-level violence measures.",
            creator_script="ddl/paper-india-segregation/b/prep_correlates.do",
            creator_line=40,
            creator_basis="downstream_usage_only",
            documentation_confidence="high",
            is_complete_standalone=False,
            is_analysis_ready_standalone=False,
        ),
    ),
    DatasetRule(
        pattern=re.compile(r"^AV_Data_matched\.dta$", re.I),
        value_builder=lambda m, *_: build_rule_match(
            dataset_role="raw_source_extract",
            pipeline_stage="matched violence source dataset",
            represents="Matched violence source dataset retained alongside the final violence analysis file.",
            creator_script=pd.NA,
            creator_line=pd.NA,
            creator_basis="unknown",
            documentation_confidence="unknown",
            is_complete_standalone=False,
            is_analysis_ready_standalone=False,
        ),
    ),
    DatasetRule(
        pattern=re.compile(r"^AV_Data\.xls$", re.I),
        value_builder=lambda m, *_: build_rule_match(
            dataset_role="raw_source_extract",
            pipeline_stage="raw violence spreadsheet source",
            represents="Spreadsheet source in the violence-analysis input family.",
            creator_script=pd.NA,
            creator_line=pd.NA,
            creator_basis="unknown",
            documentation_confidence="unknown",
            is_complete_standalone=False,
            is_analysis_ready_standalone=False,
        ),
    ),
    DatasetRule(
        pattern=re.compile(r"^secc_ec_blockdata_(?P<sector>rural|urban)_pooled_(?P<threshold>.+)\.dta$", re.I),
        value_builder=lambda m, *_: build_rule_match(
            dataset_role="pooled_analysis_dataset",
            pipeline_stage="pooled block-group analysis dataset",
            represents=f"Pooled SECC-EC block-group dataset for {m.group('sector')} areas at threshold {m.group('threshold')}.",
            creator_script="ddl/paper-india-segregation/b/create_secc_block_groups.do",
            creator_line=54,
            creator_basis="template_save_match",
            documentation_confidence="high",
            is_complete_standalone=True,
            is_analysis_ready_standalone=True,
        ),
    ),
    DatasetRule(
        pattern=re.compile(r"^segregation_blockdata_(?P<sector>rural|urban)_(?P<threshold>.+)\.dta$", re.I),
        value_builder=lambda m, *_: build_rule_match(
            dataset_role="final_analysis_dataset",
            pipeline_stage="segregation metric dataset",
            represents=f"Segregation-metric block-group dataset for {m.group('sector')} areas at threshold {m.group('threshold')}.",
            creator_script="ddl/paper-india-segregation/b/gen_seg_variables.do",
            creator_line=149,
            creator_basis="exact_save_match",
            documentation_confidence="high",
            is_complete_standalone=True,
            is_analysis_ready_standalone=True,
        ),
    ),
    DatasetRule(
        pattern=re.compile(r"^segregation_citydata_(?P<sector>rural|urban)_(?P<threshold>.+)\.dta$", re.I),
        value_builder=lambda m, *_: build_rule_match(
            dataset_role="final_analysis_dataset",
            pipeline_stage="segregation city metric dataset",
            represents=f"City-level segregation-metric dataset for {m.group('sector')} areas at threshold {m.group('threshold')}.",
            creator_script="ddl/paper-india-segregation/b/gen_segregation_city_block_data.do",
            creator_line=163,
            creator_basis="template_save_match",
            documentation_confidence="high",
            is_complete_standalone=True,
            is_analysis_ready_standalone=True,
        ),
    ),
    DatasetRule(
        pattern=re.compile(r"^violence_seg_analysis\.dta$", re.I),
        value_builder=lambda m, *_: build_rule_match(
            dataset_role="analysis_dataset",
            pipeline_stage="standalone violence analysis dataset",
            represents="Complete violence-enriched segregation analysis dataset at the urban/shrid level.",
            creator_script="ddl/paper-india-segregation/b/prep_correlates.do",
            creator_line=31,
            creator_basis="downstream_usage_only",
            documentation_confidence="medium",
            is_complete_standalone=True,
            is_analysis_ready_standalone=True,
        ),
    ),
    DatasetRule(
        pattern=re.compile(r"^pg_discrimination_counts_(?P<sector>rural|urban)_200\.dta$", re.I),
        value_builder=lambda m, *_: build_rule_match(
            dataset_role="analysis_dataset",
            pipeline_stage="standalone discrimination summary dataset",
            represents=f"Neighborhood-count summary dataset for the {m.group('sector')} discrimination analysis at threshold 200.",
            creator_script=pd.NA,
            creator_line=pd.NA,
            creator_basis="unknown",
            documentation_confidence="unknown",
            is_complete_standalone=True,
            is_analysis_ready_standalone=True,
        ),
    ),
    DatasetRule(
        pattern=re.compile(r"^pg_discrimination_(?P<sector>rural|urban)_200\.dta$", re.I),
        value_builder=lambda m, *_: build_rule_match(
            dataset_role="analysis_dataset",
            pipeline_stage="standalone discrimination analysis dataset",
            represents=f"Complete {m.group('sector')} discrimination analysis dataset at threshold 200.",
            creator_script=pd.NA,
            creator_line=pd.NA,
            creator_basis="unknown",
            documentation_confidence="unknown",
            is_complete_standalone=True,
            is_analysis_ready_standalone=True,
        ),
    ),
    DatasetRule(
        pattern=re.compile(r"^ias_collectors_01012021\.dta$", re.I),
        value_builder=lambda m, *_: build_rule_match(
            dataset_role="analysis_dataset",
            pipeline_stage="cleaned side-analysis dataset",
            represents="Cleaned district-level IAS collectors dataset for the January 1, 2021 COVID/administrative side analysis.",
            creator_script="ddl/core/misc/sam/covid_ias.do",
            creator_line=139,
            creator_basis="template_save_match",
            documentation_confidence="medium",
            is_complete_standalone=True,
            is_analysis_ready_standalone=True,
        ),
    ),
    DatasetRule(
        pattern=re.compile(r"^dissim(_iso)?_block_groups\.dta$", re.I),
        value_builder=lambda m, *_: build_rule_match(
            dataset_role="final_analysis_dataset",
            pipeline_stage="summary metric dataset",
            represents="Summary dataset of segregation metrics across block-group sizes.",
            creator_script="ddl/paper-india-segregation/b/gen_seg_block_groups.do",
            creator_line=152,
            creator_basis="template_save_match",
            documentation_confidence="medium",
            is_complete_standalone=True,
            is_analysis_ready_standalone=True,
        ),
    ),
]


def apply_rules(row: pd.Series) -> RuleMatch | None:
    for rule in RULES:
        matched = rule.match(
            filename=str(row["filename"]),
            basename=str(row["basename"]),
            relative_dir=str(row["relative_dir"]),
        )
        if matched is not None:
            return matched
    return None


def explicit_us_rule(row: pd.Series) -> RuleMatch | None:
    basename = str(row["basename"])
    rel_dir = str(row["relative_dir"])
    lower_basename = basename.lower()

    if rel_dir == "raw/us":
        if lower_basename == "census-tract-pop-2020.csv":
            return build_rule_match(
                dataset_role="raw_source_extract",
                pipeline_stage="raw input to clean us build",
                represents="2020 Census tract population source used to build clean US tract and MSA segregation inputs.",
                creator_script="ddl/paper-india-segregation/b/gen_us_seg_variables.do",
                creator_line=41,
                creator_basis="downstream_usage_only",
                documentation_confidence="high",
                is_complete_standalone=False,
                is_analysis_ready_standalone=False,
            )
        if lower_basename == "msa_key.csv":
            return build_rule_match(
                dataset_role="support_key_lookup",
                pipeline_stage="raw input to clean us build",
                represents="Raw MSA-to-county key used to build the clean US MSA key and downstream MSA segregation inputs.",
                creator_script="ddl/paper-india-segregation/b/gen_us_seg_variables.do",
                creator_line=164,
                creator_basis="downstream_usage_only",
                documentation_confidence="high",
                is_complete_standalone=False,
                is_analysis_ready_standalone=False,
            )
        if lower_basename == "msa-level-pop-2020.csv":
            return build_rule_match(
                dataset_role="raw_source_extract",
                pipeline_stage="raw input to clean us build",
                represents="2020 Census MSA population source used to build clean US MSA tract-race and dissimilarity datasets.",
                creator_script="ddl/paper-india-segregation/b/gen_us_seg_variables.do",
                creator_line=186,
                creator_basis="downstream_usage_only",
                documentation_confidence="high",
                is_complete_standalone=False,
                is_analysis_ready_standalone=False,
            )
        if lower_basename == "tract-place-key.csv":
            return build_rule_match(
                dataset_role="standalone_source_dataset",
                pipeline_stage="standalone exploratory source",
                represents="Complete tract-to-place correspondence dataset used in exploratory US place/CZ segregation work, not the main paper build.",
                creator_script="ddl/segregation/e/us/us_seg.do",
                creator_line=5,
                creator_basis="downstream_usage_only",
                documentation_confidence="high",
                is_complete_standalone=True,
                is_analysis_ready_standalone=True,
            )
        if lower_basename == "oi-tract-data.dta":
            return build_rule_match(
                dataset_role="standalone_source_dataset",
                pipeline_stage="standalone exploratory source",
                represents="Complete Opportunity Insights tract dataset used in exploratory US place/CZ segregation calculations, not the main paper build.",
                creator_script="ddl/segregation/e/us/us_seg.do",
                creator_line=79,
                creator_basis="downstream_usage_only",
                documentation_confidence="high",
                is_complete_standalone=True,
                is_analysis_ready_standalone=True,
            )
        if lower_basename == "brown_city_dissimilarity.dta":
            return build_rule_match(
                dataset_role="raw_source_extract",
                pipeline_stage="raw input to clean us comparison series",
                represents="Brown city dissimilarity source panel that underlies the clean US city comparison series.",
                creator_script="ddl/segregation/e/us_segregation_measures.do",
                creator_line=282,
                creator_basis="downstream_usage_only",
                documentation_confidence="high",
                is_complete_standalone=False,
                is_analysis_ready_standalone=False,
            )
        if lower_basename == "brown_msa_dissimilarity.dta":
            return build_rule_match(
                dataset_role="raw_source_extract",
                pipeline_stage="raw input to clean us comparison series",
                represents="Brown MSA dissimilarity source panel that underlies the clean US MSA comparison series.",
                creator_script="ddl/segregation/e/us_segregation_measures.do",
                creator_line=313,
                creator_basis="downstream_usage_only",
                documentation_confidence="high",
                is_complete_standalone=False,
                is_analysis_ready_standalone=False,
            )
        if lower_basename == "frey_msa_100_dissimilarity.dta":
            return build_rule_match(
                dataset_role="standalone_source_dataset",
                pipeline_stage="standalone external comparison source",
                represents="Complete Frey MSA dissimilarity source dataset retained as a standalone comparison input.",
                creator_script=pd.NA,
                creator_line=pd.NA,
                creator_basis="unknown",
                documentation_confidence="unknown",
                is_complete_standalone=True,
                is_analysis_ready_standalone=True,
            )

    if rel_dir == "clean/us":
        if lower_basename == "2020_ua_blocks.csv":
            return build_rule_match(
                dataset_role="clean_us_support_dataset",
                pipeline_stage="clean US geography support input",
                represents="Clean 2020 US urban-area block geography file used in a side analysis of urban tract coverage.",
                creator_script="ddl/segregation/a/not-used/calc_us_black_share_over_80.do",
                creator_line=13,
                creator_basis="downstream_usage_only",
                documentation_confidence="medium",
                is_complete_standalone=True,
                is_analysis_ready_standalone=True,
            )

    if rel_dir == "raw/us/brown":
        if lower_basename in {
            "cc20d20.dta",
            "cc20p20.dta",
            "city20d20.dta",
            "city20p20.dta",
            "cityallp20.csv",
            "msa20d20.dta",
            "msa20p20.dta",
            "sb20d20.dta",
            "sb20p20.dta",
        }:
            creator_script = pd.NA
            creator_line = pd.NA
            creator_basis = "unknown"
            documentation_confidence = "unknown"
            if lower_basename == "city20d20.dta":
                creator_script = "ddl/segregation/e/us/compare_us_india_distribution.do"
                creator_line = 8
                creator_basis = "downstream_usage_only"
                documentation_confidence = "high"
            elif lower_basename == "city20p20.dta":
                creator_script = "ddl/segregation/e/us/brown_isolation_indices.do"
                creator_line = 13
                creator_basis = "downstream_usage_only"
                documentation_confidence = "high"
            elif lower_basename == "msa20p20.dta":
                creator_script = "ddl/segregation/e/us/brown_isolation_indices.do"
                creator_line = 61
                creator_basis = "downstream_usage_only"
                documentation_confidence = "high"
            elif lower_basename in {
                "cc20d20.dta",
                "cc20p20.dta",
                "msa20d20.dta",
                "sb20d20.dta",
                "sb20p20.dta",
            }:
                creator_script = "ddl/segregation/e/us/compare_dd.do"
                creator_line = 4
                creator_basis = "downstream_usage_only"
                documentation_confidence = "high"
            return build_rule_match(
                dataset_role="standalone_source_dataset",
                pipeline_stage="standalone external comparison source",
                represents=f"Complete Brown source dataset `{basename}` retained as a standalone comparison input.",
                creator_script=creator_script,
                creator_line=creator_line,
                creator_basis=creator_basis,
                documentation_confidence=documentation_confidence,
                is_complete_standalone=True,
                is_analysis_ready_standalone=True,
            )
        if lower_basename.endswith(".xlsx"):
            return build_rule_match(
                dataset_role="alternate_format_source",
                pipeline_stage="alternate source format",
                represents=f"Spreadsheet-format copy of Brown source dataset `{basename}`.",
                creator_script=pd.NA,
                creator_line=pd.NA,
                creator_basis="unknown",
                documentation_confidence="unknown",
                is_complete_standalone=False,
                is_analysis_ready_standalone=False,
            )

    if rel_dir == "raw/us/old":
        if lower_basename in {"brown_city_dissimilarity.csv", "brown_msa_dissimilarity.csv"}:
            return build_rule_match(
                dataset_role="alternate_format_source",
                pipeline_stage="legacy alternate source format",
                represents=f"Legacy CSV-format copy of Brown source dataset `{basename}`.",
                creator_script=pd.NA,
                creator_line=pd.NA,
                creator_basis="unknown",
                documentation_confidence="unknown",
                is_complete_standalone=False,
                is_analysis_ready_standalone=False,
            )
        if lower_basename in {
            "us_cityleveldata.dta",
            "us_dissim.xlsx",
            "us_edu.csv",
            "us_income.csv",
            "us_iso.xlsx",
            "usa_msa_dissim.xlsx",
            "uscityincome.dta",
        }:
            return build_rule_match(
                dataset_role="standalone_source_dataset",
                pipeline_stage="legacy standalone source",
                represents=f"Legacy complete US source dataset `{basename}` retained as a standalone archive copy.",
                creator_script=pd.NA,
                creator_line=pd.NA,
                creator_basis="unknown",
                documentation_confidence="unknown",
                is_complete_standalone=True,
                is_analysis_ready_standalone=True,
            )

    if rel_dir == "old-2020/raw/us":
        if lower_basename in {
            "us_cityleveldata.dta",
            "us_dissim.xlsx",
            "us_edu.csv",
            "us_income.csv",
            "us_iso.xlsx",
            "uscityincome.dta",
        }:
            return build_rule_match(
                dataset_role="standalone_source_dataset",
                pipeline_stage="legacy standalone source",
                represents=f"Legacy complete US source dataset `{basename}` retained as a standalone archive copy.",
                creator_script=pd.NA,
                creator_line=pd.NA,
                creator_basis="unknown",
                documentation_confidence="unknown",
                is_complete_standalone=True,
                is_analysis_ready_standalone=True,
            )

    return None


def is_missing_value(value: object) -> bool:
    if value is None:
        return True
    try:
        return bool(pd.isna(value))
    except TypeError:
        return False


def explicit_creator_override(row: pd.Series) -> tuple[object, object, str, str] | None:
    basename = str(row["basename"])
    lower_basename = basename.lower()
    rel_dir = str(row["relative_dir"])

    exact: dict[str, tuple[str, int, str, str]] = {
        "census_village_pg_shares.dta": (
            "ddl/paper-india-segregation/b/create_census_village_pg_shares.do",
            93,
            "exact_save_match",
            "high",
        ),
        "pc11r_pca_clean.dta": (
            "ddl/core/pc/pc11/gen_pc11_pca_clean.do",
            252,
            "exact_save_match",
            "high",
        ),
        "pc11u_pca_clean.dta": (
            "ddl/core/pc/pc11/gen_pc11_pca_clean.do",
            403,
            "exact_save_match",
            "high",
        ),
        "pc11r_subdistrict_social_group.dta": (
            "ddl/core/pc/pc11/create_religion_pca.do",
            276,
            "template_save_match",
            "high",
        ),
        "pc11u_town_social_group.dta": (
            "ddl/core/pc/pc11/create_religion_pca.do",
            343,
            "exact_save_match",
            "high",
        ),
        "segregation_pc0111.dta": (
            "ddl/paper-india-segregation/a/gen_dissim_pc0111.do",
            295,
            "template_save_match",
            "high",
        ),
        "segregation_pc910111.dta": (
            "reference_repo:b/handbooks/old-2/gen_dissim_pc910111.do",
            76,
            REFERENCE_REPO_NOTE,
            "medium",
        ),
        "seg_sc_changes_2001_2011.dta": (
            "ddl/segregation/b/not-used/calc_2001_segregation.do",
            237,
            "exact_save_match",
            "high",
        ),
        "mumbai_blockdata.dta": (
            "reference_repo:old/7_cleanmumbaimuslims.do",
            50,
            REFERENCE_REPO_NOTE,
            "medium",
        ),
        "us_dissim.xlsx": (
            "reference_repo:old/gen_us_data.do",
            57,
            REFERENCE_REPO_NOTE,
            "medium",
        ),
        "uscityincome.dta": (
            "reference_repo:old/gen_us_data.do",
            48,
            REFERENCE_REPO_NOTE,
            "medium",
        ),
        "us_cityleveldata.dta": (
            "reference_repo:old/5a_usclean.do",
            40,
            REFERENCE_REPO_NOTE,
            "medium",
        ),
        "usa_msa_dissim.xlsx": (
            "reference_repo:old/gen_us_data.do",
            57,
            REFERENCE_REPO_NOTE,
            "medium",
        ),
        "cityallp20.csv": (
            "ddl/segregation/e/us/brown_isolation_indices.do",
            6,
            "downstream_usage_only",
            "medium",
        ),
        "frey_msa_100_dissimilarity.dta": (
            pd.NA,
            pd.NA,
            "external_source_no_creator_found",
            "unknown",
        ),
        "us_tract_pop.dta": (
            "ddl/paper-india-segregation/b/gen_us_seg_variables.do",
            131,
            "template_save_match",
            "high",
        ),
        "us_tpop_b.dta": (
            "ddl/paper-india-segregation/b/gen_us_seg_variables.do",
            153,
            "template_save_match",
            "high",
        ),
        "msa_tract_race_pop.dta": (
            "ddl/paper-india-segregation/b/gen_us_seg_variables.do",
            275,
            "template_save_match",
            "high",
        ),
    }
    if lower_basename in exact:
        return exact[lower_basename]

    city_district_match = re.fullmatch(
        r"city_seg_district_rural_urban_(?:200|4000)\.dta",
        lower_basename,
    )
    if city_district_match:
        return (
            "ddl/paper-india-segregation/b/gen_district_correlates_urban_rural.do",
            61,
            "template_save_match",
            "high",
        )

    ec_appended_or_health = re.fullmatch(r"ec(?:05|13|90|98)_(?:appended|ed_health)\.dta", lower_basename)
    if rel_dir == "clean/ec" and ec_appended_or_health:
        return (
            "reference_repo:b/gen_ec_all_village.do",
            213 if "ed_health" in lower_basename else 33,
            REFERENCE_REPO_NOTE,
            "medium",
        )

    return None


CANONICAL_COMPLETE_PATTERNS = (
    re.compile(r"^secc_(rural|urban)_collapsed(_block)?\.dta$", re.I),
    re.compile(r"^secc_ec_blockdata_(rural|urban)\.dta$", re.I),
    re.compile(r"^secc_(rural|urban)_individual_sample\.dta$", re.I),
    re.compile(r"^census_village_pg_shares\.dta$", re.I),
    re.compile(r"^pc11r_pca_clean\.dta$", re.I),
    re.compile(r"^pc11u_pca_clean\.dta$", re.I),
    re.compile(r"^ec13_(rural|urban)_(city|block)\.dta$", re.I),
)

DERIVED_COMPLETE_PATTERNS = (
    re.compile(r"^secc_ec_blockdata_(rural|urban)_pooled_.+\.dta$", re.I),
    re.compile(r"^secc_(rural|urban)_individual_sample_(10p|1p|slum)\.dta$", re.I),
    re.compile(r"^2020_UA_BLOCKS\.csv$", re.I),
    re.compile(r"^us_tract_pop\.dta$", re.I),
    re.compile(r"^us_tpop_b\.dta$", re.I),
    re.compile(r"^msa_tract_race_pop\.dta$", re.I),
    re.compile(r"^segregation_blockdata_(rural|urban)_(200|4000)\.dta$", re.I),
    re.compile(r"^segregation_citydata_(rural|urban)_(200|4000)\.dta$", re.I),
    re.compile(r"^city_seg_district_rural_urban_(200|4000)\.dta$", re.I),
    re.compile(r"^segregation_pc0111\.dta$", re.I),
    re.compile(r"^segregation_pc910111\.dta$", re.I),
    re.compile(r"^seg_sc_changes_2001_2011\.dta$", re.I),
    re.compile(r"^pc11[ru]_(subdistrict|town)_social_group\.dta$", re.I),
    re.compile(r"^ec(?:05|13|90|98)_(?:appended|ed_health)\.dta$", re.I),
    re.compile(r"^ec13_appended\.dta$", re.I),
    re.compile(r"^violence_seg_analysis\.dta$", re.I),
    re.compile(r"^pg_discrimination(_counts)?_(rural|urban)_200\.dta$", re.I),
    re.compile(r"^ias_collectors_01012021\.dta$", re.I),
    re.compile(r"^dissim(_iso)?_block_groups\.dta$", re.I),
)

SOURCE_COMPLETE_PATTERNS = (
    re.compile(r"^frey_msa_100_dissimilarity\.dta$", re.I),
    re.compile(r"^cityallp20\.csv$", re.I),
    re.compile(r"^tract-place-key\.csv$", re.I),
    re.compile(r"^oi-tract-data\.dta$", re.I),
)


def match_any_pattern(patterns: tuple[re.Pattern[str], ...], value: str) -> bool:
    return any(pattern.fullmatch(value) for pattern in patterns)


def complete_parent_for_row(row: pd.Series, inventory_class: str) -> object:
    basename = str(row["basename"])
    lower_basename = basename.lower()
    rel_dir = str(row["relative_dir"])

    if inventory_class in {"canonical", "source", "legacy"}:
        return str(row["filename"])

    individual_sample_variant = re.fullmatch(
        r"secc_(rural|urban)_individual_sample_(?:10p|1p|slum)\.dta",
        lower_basename,
        re.I,
    )
    if individual_sample_variant:
        sector = individual_sample_variant.group(1)
        return f"/dartfs/rc/lab/I/IEC/seg/clean/secc_{sector}_individual_sample.dta"

    nbd_old_pooled_variant = re.fullmatch(
        r"secc_ec_blockdata_(rural|urban)_pooled_.+\.dta",
        lower_basename,
        re.I,
    )
    if rel_dir == "clean/nbd_sizes_old" and nbd_old_pooled_variant:
        sector = nbd_old_pooled_variant.group(1)
        return f"/dartfs/rc/lab/I/IEC/seg/clean/nbd_sizes_old/secc_ec_blockdata_{sector}_pooled_.dta"

    if lower_basename == "2020_ua_blocks.csv":
        return pd.NA

    if lower_basename == "us_tract_pop.dta":
        return "/dartfs/rc/lab/I/IEC/seg/raw/us/census-tract-pop-2020.csv"

    if lower_basename == "us_tpop_b.dta":
        return "/dartfs/rc/lab/I/IEC/seg/clean/us/us_tract_pop.dta"

    if lower_basename == "msa_tract_race_pop.dta":
        return "/dartfs/rc/lab/I/IEC/seg/clean/us/us_tract_pop.dta"

    if re.fullmatch(r"secc_ec_blockdata_(rural|urban)_pooled_.+\.dta", lower_basename, re.I):
        sector = re.fullmatch(r"secc_ec_blockdata_(rural|urban)_pooled_.+\.dta", lower_basename, re.I).group(1)
        return f"/dartfs/rc/lab/I/IEC/seg/clean/secc_ec_blockdata_{sector}.dta"

    if re.fullmatch(r"segregation_blockdata_(rural|urban)_(200|4000)\.dta", lower_basename, re.I):
        m = re.fullmatch(r"segregation_blockdata_(rural|urban)_(200|4000)\.dta", lower_basename, re.I)
        return f"/dartfs/rc/lab/I/IEC/seg/clean/secc_ec_blockdata_{m.group(1)}_pooled_{m.group(2)}.dta"

    if re.fullmatch(r"segregation_citydata_(rural|urban)_(200|4000)\.dta", lower_basename, re.I):
        m = re.fullmatch(r"segregation_citydata_(rural|urban)_(200|4000)\.dta", lower_basename, re.I)
        return f"/dartfs/rc/lab/I/IEC/seg/clean/segregation_blockdata_{m.group(1)}_{m.group(2)}.dta"

    if re.fullmatch(r"city_seg_district_rural_urban_(200|4000)\.dta", lower_basename, re.I):
        m = re.fullmatch(r"city_seg_district_rural_urban_(200|4000)\.dta", lower_basename, re.I)
        return f"/dartfs/rc/lab/I/IEC/seg/clean/segregation_citydata_urban_{m.group(1)}.dta"

    if lower_basename == "segregation_pc0111.dta":
        return "/dartfs/rc/lab/I/IEC/seg/clean/segregation_citydata_urban_200.dta"

    if lower_basename == "segregation_pc910111.dta":
        return "/dartfs/rc/lab/I/IEC/seg/clean/segregation_pc0111.dta"

    if lower_basename == "seg_sc_changes_2001_2011.dta":
        return "/dartfs/rc/lab/I/IEC/seg/clean/segregation_pc0111.dta"

    if lower_basename in {"pc11r_subdistrict_social_group.dta", "pc11u_town_social_group.dta"}:
        return (
            "/dartfs/rc/lab/I/IEC/seg/clean/pc11/pc11r_pca_clean.dta"
            if "pc11r_" in lower_basename
            else "/dartfs/rc/lab/I/IEC/seg/clean/pc11/pc11u_pca_clean.dta"
        )

    if lower_basename in {"ec05_appended.dta", "ec13_appended.dta", "ec90_appended.dta", "ec98_appended.dta"}:
        return pd.NA

    if lower_basename in {"ec05_ed_health.dta", "ec13_ed_health.dta", "ec90_ed_health.dta", "ec98_ed_health.dta"}:
        appended_name = lower_basename.replace("_ed_health", "_appended")
        return f"/dartfs/rc/lab/I/IEC/seg/clean/ec/{appended_name}"

    if lower_basename == "violence_seg_analysis.dta":
        return pd.NA

    if lower_basename == "ias_collectors_01012021.dta":
        return pd.NA

    return pd.NA


def classify_complete_dataset(row: pd.Series) -> dict[str, object]:
    filename = str(row["filename"])
    basename = str(row["basename"])
    lower_basename = basename.lower()
    rel_dir = str(row["relative_dir"])
    dataset_role = str(row["dataset_role"])
    likely_legacy = bool(row["likely_legacy"])
    is_complete = bool(row["is_complete_standalone"])
    is_analysis_ready = bool(row["is_analysis_ready_standalone"])

    result = {
        "complete_dataset_class": pd.NA,
        "canonical_parent_file": pd.NA,
        "lineage_basis": pd.NA,
        "inventory_decision": "excluded",
        "inventory_decision_note": "",
        "excluded_from_canonical_reason": "",
    }

    if lower_basename == "ec13__city.dta":
        result.update(
            {
                "complete_dataset_class": "excluded",
                "lineage_basis": "artifact_no_creator_found",
                "inventory_decision": "excluded",
                "inventory_decision_note": "Misnamed EC13/PC11 crosswalk artifact excluded from complete dataset sheets.",
                "excluded_from_canonical_reason": "misnamed crosswalk artifact",
            }
        )
        return result

    if rel_dir == "clean/pc11" and lower_basename in {"pc11_muslims_rural.dta", "pc11_muslims_urban.dta"}:
        result.update(
            {
                "complete_dataset_class": "canonical",
                "canonical_parent_file": filename,
                "lineage_basis": "promoted_support_master_rule",
                "inventory_decision": "canonical",
                "inventory_decision_note": "Primary PC11 Muslim-share master promoted to the standalone sheet.",
                "excluded_from_canonical_reason": "",
            }
        )
        return result

    if rel_dir == "violence" and lower_basename == "violence_seg_analysis.dta":
        result.update(
            {
                "complete_dataset_class": "canonical",
                "canonical_parent_file": filename,
                "lineage_basis": "promoted_analysis_master_rule",
                "inventory_decision": "canonical",
                "inventory_decision_note": "Primary violence analysis master promoted to the standalone sheet.",
                "excluded_from_canonical_reason": "",
            }
        )
        return result

    if rel_dir == "raw/us/old" and lower_basename == "us_cityleveldata.dta":
        result.update(
            {
                "complete_dataset_class": "canonical",
                "canonical_parent_file": filename,
                "lineage_basis": "promoted_legacy_master_rule",
                "inventory_decision": "canonical",
                "inventory_decision_note": "Legacy US city-level master promoted because no active standalone dataset captures this family.",
                "excluded_from_canonical_reason": "",
            }
        )
        return result

    if not is_complete and not is_analysis_ready:
        result["inventory_decision_note"] = "Not a complete standalone dataset."
        result["excluded_from_canonical_reason"] = "not complete standalone"
        result["inventory_decision"] = "not_complete"
        return result

    if dataset_role == "support_key_lookup":
        result.update(
            {
                "complete_dataset_class": "excluded",
                "lineage_basis": "support_key_lookup",
                "inventory_decision": "excluded",
                "inventory_decision_note": "Support key or lookup file; not treated as a complete dataset.",
                "excluded_from_canonical_reason": "support key / lookup",
            }
        )
        return result

    if rel_dir == "clean/nbd_sizes_old" and re.fullmatch(
        r"secc_ec_blockdata_(rural|urban)_pooled_.+\.dta",
        lower_basename,
        re.I,
    ):
        result.update(
            {
                "complete_dataset_class": "derived",
                "canonical_parent_file": complete_parent_for_row(row, "derived"),
                "lineage_basis": "legacy_threshold_family_rule",
                "inventory_decision": "derived",
                "inventory_decision_note": "Legacy thresholded pooled file derived from the archived pooled parent.",
                "excluded_from_canonical_reason": "derived legacy threshold output",
            }
        )
        return result

    if likely_legacy:
        result.update(
            {
                "complete_dataset_class": "legacy",
                "canonical_parent_file": filename,
                "lineage_basis": "legacy_archive_rule",
                "inventory_decision": "legacy",
                "inventory_decision_note": "Legacy archive copy retained on its own sheet.",
                "excluded_from_canonical_reason": "legacy archive copy",
            }
        )
        return result

    if match_any_pattern(SOURCE_COMPLETE_PATTERNS, basename) or dataset_role == "standalone_source_dataset":
        result.update(
            {
                "complete_dataset_class": "source",
                "canonical_parent_file": filename,
                "lineage_basis": "standalone_source_unit",
                "inventory_decision": "source",
                "inventory_decision_note": "Standalone source dataset retained separately from clean canonical masters.",
                "excluded_from_canonical_reason": "standalone source unit",
            }
        )
        return result

    if match_any_pattern(DERIVED_COMPLETE_PATTERNS, basename) or dataset_role in {
        "analysis_dataset",
        "final_analysis_dataset",
        "pooled_analysis_dataset",
        "ec13_collapsed_master",
        "derived_individual_sample",
        "clean_us_support_dataset",
    }:
        result.update(
            {
                "complete_dataset_class": "derived",
                "canonical_parent_file": complete_parent_for_row(row, "derived"),
                "lineage_basis": "family_derivation_rule",
                "inventory_decision": "derived",
                "inventory_decision_note": "Complete dataset, but derived from another complete dataset family.",
                "excluded_from_canonical_reason": "derived family output",
            }
        )
        return result

    if match_any_pattern(CANONICAL_COMPLETE_PATTERNS, basename) or dataset_role in {
        "collapsed_master",
        "merged_analysis_input",
        "clean_dataset",
        "individual_sample_master",
    }:
        result.update(
            {
                "complete_dataset_class": "canonical",
                "canonical_parent_file": filename,
                "lineage_basis": "canonical_master_rule",
                "inventory_decision": "canonical",
                "inventory_decision_note": "Canonical complete dataset retained in the primary sheet.",
                "excluded_from_canonical_reason": "",
            }
        )
        return result

    if is_analysis_ready:
        result.update(
            {
                "complete_dataset_class": "derived",
                "canonical_parent_file": pd.NA,
                "lineage_basis": "fallback_analysis_ready_rule",
                "inventory_decision": "derived",
                "inventory_decision_note": "Analysis-ready complete dataset without a tighter family rule.",
                "excluded_from_canonical_reason": "derived analysis-ready output",
            }
        )
        return result

    result["inventory_decision_note"] = "Complete candidate could not be classified into a retained class."
    result["excluded_from_canonical_reason"] = "unclassified complete candidate"
    return result


def build_column_guide() -> pd.DataFrame:
    descriptions = {
        "filename": "Absolute file path for the structured dataset.",
        "file_format": "Normalized file format without the leading dot.",
        "file_extension_normalized": "Normalized extension used by the scanner.",
        "file_size_bytes": "File size in bytes.",
        "top_level_section": "Top-level directory immediately under `seg`.",
        "subfolder": "Nested folder path below the top-level section.",
        "relative_dir": "Directory path relative to `seg`.",
        "basename": "Leaf filename.",
        "legacy_reason": "Semicolon-delimited legacy markers inferred from the path.",
        "likely_legacy": "Boolean flag for files in old/archive locations.",
        "read_error_type": "Read error type if file metadata could not be parsed.",
        "read_error_message": "Read error message if metadata parsing failed.",
        "structure_notes": "Short note about how structure metadata was obtained.",
        "n_obs": "Observed row count from metadata extraction.",
        "n_vars": "Observed variable count from metadata extraction.",
        "variable_list": "Semicolon-delimited list of column or variable names.",
        "structure_metadata_status": "Status of structure metadata extraction.",
        "dataset_role": "Heuristic role assigned from filename, path, and code lineage.",
        "pipeline_stage": "High-level pipeline stage inferred from code and path.",
        "represents": "Human-readable description of what the file contains.",
        "creator_script": "Script most likely responsible for creating the file.",
        "creator_line": "Line number in the creator script or reference source.",
        "creator_basis": "Basis for the creator mapping, such as exact save match or reference repo lineage.",
        "documentation_confidence": "Confidence in the creator mapping.",
        "is_complete_standalone": "Boolean flag for complete standalone datasets.",
        "is_analysis_ready_standalone": "Boolean flag for complete datasets suitable for direct analysis use.",
        "master_pooled_file": "Mapped master file used for lineage or comparison.",
        "master_mapping_status": "Whether the row maps to itself or another master.",
        "master_mapping_basis": "Rule or evidence used for the master mapping.",
        "master_mapping_note": "Short note explaining the master mapping decision.",
        "linked_complete_dataset_file": "Complete dataset linked to this row when it is an input or fragment.",
        "linked_complete_dataset_in_standalone": "Boolean flag indicating whether the linked complete dataset is in the standalone inventory.",
        "linked_complete_dataset_status": "Status of the linked complete dataset relation.",
        "linked_complete_dataset_note": "Short note explaining the linked complete dataset relation.",
        "complete_dataset_class": "Canonical, derived, source, legacy, or excluded class for the complete dataset inventory.",
        "canonical_parent_file": "Immediate parent complete dataset used for lineage tracing.",
        "lineage_basis": "Rule basis used to assign the complete dataset class and parent.",
        "inventory_decision": "Final inventory decision for the complete-dataset workbook sheets.",
        "inventory_decision_note": "Short explanation of the inventory decision.",
        "excluded_from_canonical_reason": "Reason the file is not on the canonical sheet.",
        "needs_complete_dataset_flag": "Boolean flag marking rows that need complete-dataset linkage work.",
    }
    records = [
        {
            "column_name": column,
            "meaning": descriptions.get(column, ""),
        }
        for column in [
            "filename",
            "file_format",
            "file_extension_normalized",
            "file_size_bytes",
            "top_level_section",
            "subfolder",
            "relative_dir",
            "basename",
            "legacy_reason",
            "likely_legacy",
            "read_error_type",
            "read_error_message",
            "structure_notes",
            "n_obs",
            "n_vars",
            "variable_list",
            "structure_metadata_status",
            "dataset_role",
            "pipeline_stage",
            "represents",
            "creator_script",
            "creator_line",
            "creator_basis",
            "documentation_confidence",
            "is_complete_standalone",
            "is_analysis_ready_standalone",
            "master_pooled_file",
            "master_mapping_status",
            "master_mapping_basis",
            "master_mapping_note",
            "linked_complete_dataset_file",
            "linked_complete_dataset_in_standalone",
            "linked_complete_dataset_status",
            "linked_complete_dataset_note",
            "complete_dataset_class",
            "canonical_parent_file",
            "lineage_basis",
            "inventory_decision",
            "inventory_decision_note",
            "excluded_from_canonical_reason",
            "needs_complete_dataset_flag",
        ]
    ]
    return pd.DataFrame(records)


def split_complete_inventory(inventory: pd.DataFrame) -> dict[str, pd.DataFrame]:
    complete_mask = inventory["inventory_decision"].isin(COMPLETE_DATASET_CLASSES)
    filename_index = {
        str(row["filename"]): row for _, row in inventory.loc[complete_mask].iterrows()
    }
    standalone_files = set(
        inventory.loc[inventory["inventory_decision"].isin({"canonical", "source", "legacy"}), "filename"]
        .astype(str)
        .tolist()
    )
    parent_queue: deque[str] = deque()
    for _, row in inventory.loc[inventory["inventory_decision"].eq("derived")].iterrows():
        for parent_col in ("canonical_parent_file", "linked_complete_dataset_file"):
            parent = row.get(parent_col)
            if pd.notna(parent) and str(parent).strip():
                parent_queue.append(str(parent))

    seen_parents: set[str] = set()
    while parent_queue:
        parent = parent_queue.popleft()
        if parent in seen_parents:
            continue
        seen_parents.add(parent)
        parent_row = filename_index.get(parent)
        if parent_row is None:
            continue
        if parent not in standalone_files:
            standalone_files.add(parent)
            for parent_col in ("canonical_parent_file", "linked_complete_dataset_file"):
                upstream = parent_row.get(parent_col)
                if pd.notna(upstream) and str(upstream).strip():
                    upstream = str(upstream)
                    if upstream != parent:
                        parent_queue.append(upstream)
    frames = {}
    for complete_class in COMPLETE_DATASET_CLASSES:
        frames[complete_class] = (
            inventory.loc[inventory["inventory_decision"].eq(complete_class)]
            .sort_values(["top_level_section", "relative_dir", "basename", "filename"])
            .reset_index(drop=True)
        )
    frames["excluded"] = (
        inventory.loc[inventory["inventory_decision"].eq("excluded")]
        .sort_values(["top_level_section", "relative_dir", "basename", "filename"])
        .reset_index(drop=True)
    )
    frames["standalone"] = (
        inventory.loc[inventory["filename"].astype(str).isin(standalone_files)]
        .sort_values(["top_level_section", "relative_dir", "basename", "filename"])
        .reset_index(drop=True)
    )
    return frames


def is_support_dataset(filename: str, basename: str, relative_dir: str) -> bool:
    path_tokens = set(re.split(r"[_/\W]+", f"{relative_dir}/{basename}".lower()))
    if SUPPORT_TOKENS & path_tokens:
        return True
    if "handbook_ebs" in filename:
        return True
    if basename.lower().endswith("_file_manifest.csv"):
        return True
    return False


def infer_role_stage(row: pd.Series) -> tuple[str, str]:
    filename = str(row["filename"]).lower()
    basename = str(row["basename"]).lower()
    if str(row["top_level_section"]) == "partitioned":
        return "partition_or_shard", "partitioned intermediate"
    if str(row["top_level_section"]) == "raw":
        return "raw_source_extract", "raw input"
    if is_support_dataset(str(row["filename"]), str(row["basename"]), str(row["relative_dir"])):
        return "support_key_lookup", "support / lookup"
    if any(marker in basename for marker in ANALYSIS_MARKERS):
        return "analysis_dataset", "analysis-ready dataset"
    if str(row["top_level_section"]) == "clean":
        return "clean_dataset", "clean output"
    return "unknown_dataset", "unknown"


def is_complete_standalone_candidate(row: pd.Series, dataset_role: str) -> bool:
    filename = str(row["filename"])
    if str(row["top_level_section"]) == "partitioned":
        return False
    if is_support_dataset(filename, str(row["basename"]), str(row["relative_dir"])):
        return False
    if str(row["top_level_section"]) == "raw":
        return False
    if "ocr/" in filename or "handbook_ebs/" in filename:
        return False
    return dataset_role in {"analysis_dataset", "clean_dataset", "final_analysis_dataset", "collapsed_master", "merged_analysis_input", "pooled_analysis_dataset"}


def is_analysis_ready_standalone_candidate(row: pd.Series, dataset_role: str) -> bool:
    filename = str(row["filename"]).lower()
    if not is_complete_standalone_candidate(row, dataset_role):
        return False
    if dataset_role in {
        "collapsed_master",
        "merged_analysis_input",
        "pooled_analysis_dataset",
        "final_analysis_dataset",
        "analysis_dataset",
    }:
        return True
    if str(row["top_level_section"]) == "clean":
        if is_support_dataset(str(row["filename"]), str(row["basename"]), str(row["relative_dir"])):
            return False
        return True
    return any(marker in filename for marker in ANALYSIS_MARKERS)


def master_mapping_for_row(row: pd.Series) -> tuple[object, str, str, str]:
    filename = str(row["filename"])
    basename = str(row["basename"])
    rel_dir = str(row["relative_dir"])
    if bool(row["is_analysis_ready_standalone"]):
        return filename, "self", "self", ""

    lowered = filename.lower()
    if lowered.endswith("/raw/handbook_ebs/handbook_appended.csv"):
        return (
            str(HANDBOOK_APPENDED),
            "self",
            "self",
            "Non-standalone handbook aggregate used as the master for matched EB page CSVs.",
        )
    if "/raw/handbook_ebs/" in lowered and handbook_page_matches_appended(filename):
        return (
            str(HANDBOOK_APPENDED),
            "mapped",
            "eb_page_handbook_row_match",
            "EB page CSV matched to handbook_appended.csv on shared town/ward/EB/pop fields.",
        )

    handbook_pc0111_inputs = {
        "pc01_eb_appendix.csv",
        "pc01_pca_key.dta",
        "pc01_pdf.dta",
        "pc01_pdf_eb_clean.dta",
        "pc01_pdf_key.dta",
        "pc01_pdf_shrid_dissim.dta",
        "pc01_pdf_shrid_key.dta",
        "pc01_pdf_town_clean.dta",
        "pc01_unmerged_pdf.dta",
        "pc11_eb_appendix.csv",
        "pc11_pca_key.dta",
        "pc11_pdf.dta",
        "pc11_pdf_eb_clean.dta",
        "pc11_pdf_key.dta",
        "pc11_pdf_shrid_dissim.dta",
        "pc11_pdf_shrid_key.dta",
        "pc11_pdf_town_clean.dta",
    }
    if rel_dir == "clean/handbooks" and basename in handbook_pc0111_inputs:
        return (
            str(HANDBOOK_PC0111_ANALYSIS),
            "mapped",
            "explicit_creator_lineage",
            "Handbook support or intermediate dataset used in gen_dissim_pc0111.do to build the merged cross-year handbook segregation analysis dataset.",
        )

    block_to_nbd_match = re.fullmatch(
        r"secc_(?P<sector>rural|urban)_block_to_nbd_(?P<threshold>.+)_key\.dta",
        basename,
        re.I,
    )
    if rel_dir == "clean/block_to_nbd" and block_to_nbd_match:
        sector = block_to_nbd_match.group("sector").lower()
        threshold = block_to_nbd_match.group("threshold")
        pooled_master = (
            f"/dartfs/rc/lab/I/IEC/seg/clean/secc_ec_blockdata_{sector}_pooled_{threshold}.dta"
        )
        note = (
            "Support key used to create pooled block-group analysis dataset; "
            "mapped to pooled DTA as the analysis master."
        )
        return pooled_master, "mapped", "explicit_creator_lineage", note

    if rel_dir == "religion":
        religion_match = re.fullmatch(r"pc11_muslims_(?P<sector>rural|urban)\.dta", basename, re.I)
        if religion_match:
            sector = religion_match.group("sector").lower()
            return (
                f"/dartfs/rc/lab/I/IEC/seg/clean/pc11/pc11_muslims_{sector}.dta",
                "mapped",
                "family_lineage_rule",
                "Duplicate religion-folder copy of the PC11 Muslim-share master; mapped to the promoted clean/pc11 master dataset.",
            )

    if rel_dir == "violence":
        if basename in {"violence_matched_except_jk.dta", "violence_matched_jk.dta"}:
            return (
                "/dartfs/rc/lab/I/IEC/seg/violence/violence_seg_analysis.dta",
                "mapped",
                "explicit_creator_lineage",
                "Matched violence event input merged in prep_correlates.do to build shrid-level violence measures; mapped to the complete violence analysis dataset.",
            )
        if basename in {"AV_Data_matched.dta", "AV_Data.xls"}:
            return (
                "/dartfs/rc/lab/I/IEC/seg/violence/violence_seg_analysis.dta",
                "mapped",
                "family_lineage_rule",
                "Violence source file in the same matched-analysis family; mapped to the complete violence analysis dataset.",
            )

    if rel_dir == "partitioned/secc_collapse/muslim_classification":
        muslim_household_match = re.fullmatch(
            r"secc_(?P<sector>rural|urban)_\d{4,5}_muslim_household\.dta",
            basename,
            re.I,
        )
        if muslim_household_match:
            sector = muslim_household_match.group("sector").lower()
            return (
                f"/dartfs/rc/lab/I/IEC/seg/clean/secc_{sector}_collapsed_block.dta",
                "mapped",
                "explicit_creator_lineage",
                "Partitioned muslim-household classification shard merged into the block-collapse build for the clean collapsed block master; the same shard is also merged into the full clean individual sample build.",
            )

    if rel_dir == "partitioned/secc_collapse":
        block_master_patterns = (
            r"secc_(?:members|household|educ_)?block_rural_\d{4,5}\.dta",
            r"secc_(?:members|household|educ_)?block_urban_\d{4,5}\.dta",
            r"secc_(?:members_data|members_hh|household|educ_hh|members_block|household_block|educ_block)_rural_\d{4,5}\.dta",
            r"secc_(?:members_data|members_hh|household|educ_hh|members_block|household_block|educ_block)_urban_\d{4,5}\.dta",
        )
        upper_master_patterns = (
            r"secc_(?:members_|household_|educ_)?subdistrict_rural_\d{4,5}\.dta",
            r"secc_(?:members_|household_|educ_)?town_urban_\d{4,5}\.dta",
            r"secc_members_subdistrict_rural_\d{4,5}\.dta",
            r"secc_household_subdistrict_rural_\d{4,5}\.dta",
            r"secc_educ_subdistrict_rural_\d{4,5}\.dta",
            r"secc_members_town_urban_\d{4,5}\.dta",
            r"secc_household_town_urban_\d{4,5}\.dta",
            r"secc_educ_town_urban_\d{4,5}\.dta",
        )
        if any(re.fullmatch(pattern, basename) for pattern in block_master_patterns):
            sector = "rural" if "_rural_" in basename else "urban"
            return (
                f"/dartfs/rc/lab/I/IEC/seg/clean/secc_{sector}_collapsed_block.dta",
                "mapped",
                "explicit_creator_lineage",
                "Partitioned shard or intermediate feeding the assembled clean collapsed block master.",
            )
        if any(re.fullmatch(pattern, basename) for pattern in upper_master_patterns):
            sector = "rural" if "_rural_" in basename else "urban"
            return (
                f"/dartfs/rc/lab/I/IEC/seg/clean/secc_{sector}_collapsed.dta",
                "mapped",
                "explicit_creator_lineage",
                "Partitioned shard or intermediate feeding the assembled clean collapsed upper-level master.",
            )
        if re.fullmatch(r"secc_(?:members|household|educ_)?block_rural_\d{4,5}\.dta", basename):
            return (
                "/dartfs/rc/lab/I/IEC/seg/clean/secc_rural_collapsed_block.dta",
                "mapped",
                "family_lineage_rule",
                "",
            )
        if re.fullmatch(r"secc_(?:members|household|educ_)?block_urban_\d{4,5}\.dta", basename):
            return (
                "/dartfs/rc/lab/I/IEC/seg/clean/secc_urban_collapsed_block.dta",
                "mapped",
                "family_lineage_rule",
                "",
            )
        if re.fullmatch(r"secc_(?:members_|household_|educ_)?subdistrict_rural_\d{4,5}\.dta", basename):
            return (
                "/dartfs/rc/lab/I/IEC/seg/clean/secc_rural_collapsed.dta",
                "mapped",
                "family_lineage_rule",
                "",
            )
        if re.fullmatch(r"secc_(?:members_|household_|educ_)?town_urban_\d{4,5}\.dta", basename):
            return (
                "/dartfs/rc/lab/I/IEC/seg/clean/secc_urban_collapsed.dta",
                "mapped",
                "family_lineage_rule",
                "",
            )

    if rel_dir == "partitioned/individual_sample":
        individual_sample_match = re.fullmatch(
            r"seg_individual_sample_(?P<sector>rural|urban)_\d{5}\.dta",
            basename,
            re.I,
        )
        if individual_sample_match:
            sector = individual_sample_match.group("sector").lower()
            return (
                f"/dartfs/rc/lab/I/IEC/seg/clean/secc_{sector}_individual_sample.dta",
                "mapped",
                "explicit_creator_lineage",
                "Partitioned individual-sample shard written by individual_1p_regression.do and appended in assemble_individual_1p.do into the clean full individual sample dataset.",
            )

    if rel_dir in {"partitioned/parsed_draft/rural", "partitioned/parsed_draft/urban"}:
        parsed_draft_match = re.fullmatch(
            r"secc_(?P<sector>rural|urban)_\d{4,5}_(?P<unit>members|household)\.dta",
            basename,
            re.I,
        )
        if parsed_draft_match:
            sector = parsed_draft_match.group("sector").lower()
            unit = parsed_draft_match.group("unit").lower()
            return (
                f"/dartfs/rc/lab/I/IEC/seg/clean/secc_{sector}_individual_sample.dta",
                "mapped",
                "explicit_creator_lineage",
                f"Partitioned parsed-draft {unit} shard used as input to both the block-collapse build and the full clean individual sample build; mapped to the pooled individual-level master dataset.",
            )

    if rel_dir in {
        "old-2020/raw/muslims/lstm_classifications/rural",
        "old-2020/raw/muslims/lstm_classifications/urban",
    }:
        names_pred_match = re.fullmatch(r"names_pred_[a-z0-9]+\.csv\*?", basename, re.I)
        if names_pred_match:
            sector = "rural" if rel_dir.endswith("/rural") else "urban"
            return (
                f"/dartfs/rc/lab/I/IEC/seg/clean/secc_{sector}_collapsed_block.dta",
                "mapped",
                "explicit_creator_lineage",
                "State-level LSTM Muslim-name classification output imported by classify_names.do, converted into member and household Muslim keys, and then merged into the collapsed block build; the same pipeline also feeds the full individual sample build.",
            )

    if rel_dir == "clean/shrug" and basename == "shrug_pc11_subdistrict_key.dta":
        return (
            "/dartfs/rc/lab/I/IEC/seg/clean/segregation_citydata_rural_200.dta",
            "mapped",
            "explicit_creator_lineage",
            "Support key merged into the segregation city-data build, especially the rural subdistrict pipeline; mapped to the canonical rural city-level analysis dataset.",
        )

    if rel_dir == "clean/us" and basename == "msa_keys.dta":
        return (
            "/dartfs/rc/lab/I/IEC/seg/clean/us/us_census_msa_dissim.dta",
            "mapped",
            "explicit_creator_lineage",
            "Clean MSA key merged into the downstream US census MSA dissimilarity dataset.",
        )

    if rel_dir == "raw/us":
        if basename == "census-tract-pop-2020.csv":
            return (
                "/dartfs/rc/lab/I/IEC/seg/clean/us/us_tract_pop.dta",
                "mapped",
                "explicit_creator_lineage",
                "Imported and cleaned into clean/us/us_tract_pop.dta, then used in downstream US MSA segregation inputs.",
            )
        if basename == "MSA_key.csv":
            return (
                "/dartfs/rc/lab/I/IEC/seg/clean/us/msa_keys.dta",
                "mapped",
                "explicit_creator_lineage",
                "Imported and cleaned into clean/us/msa_keys.dta, then merged into downstream US MSA segregation inputs.",
            )
        if basename == "msa-level-pop-2020.csv":
            return (
                "/dartfs/rc/lab/I/IEC/seg/clean/us/us_census_msa_dissim.dta",
                "mapped",
                "explicit_creator_lineage",
                "Imported and merged with clean MSA keys and tract populations to build clean/us/us_census_msa_dissim.dta.",
            )
        if basename == "brown_city_dissimilarity.dta":
            return (
                "/dartfs/rc/lab/I/IEC/seg/clean/us/brown_city_dissim_1980_2020.dta",
                "mapped",
                "family_lineage_rule",
                "Raw Brown city dissimilarity panel underlying the clean US Brown city comparison series.",
            )
        if basename == "brown_msa_dissimilarity.dta":
            return (
                "/dartfs/rc/lab/I/IEC/seg/clean/us/brown_msa_dissim_1980_2020.dta",
                "mapped",
                "family_lineage_rule",
                "Raw Brown MSA dissimilarity panel underlying the clean US Brown MSA comparison series.",
            )

    if rel_dir == "raw/us/brown" and basename.lower().endswith(".xlsx"):
        stem = PurePosixPath(basename).stem
        for suffix in (".dta", ".csv"):
            paired = SEG_ROOT / "raw" / "us" / "brown" / f"{stem}{suffix}"
            if paired.exists():
                return (
                    str(paired),
                    "mapped",
                    "alternate_format_pair",
                    "Alternate spreadsheet copy; paired flat/Stata file treated as the inventory master.",
                )

    if rel_dir == "raw/us/old":
        legacy_pairs = {
            "brown_city_dissimilarity.csv": "/dartfs/rc/lab/I/IEC/seg/raw/us/brown_city_dissimilarity.dta",
            "brown_msa_dissimilarity.csv": "/dartfs/rc/lab/I/IEC/seg/raw/us/brown_msa_dissimilarity.dta",
        }
        if basename in legacy_pairs:
            return (
                legacy_pairs[basename],
                "mapped",
                "legacy_alternate_format_pair",
                "Legacy alternate-format copy mapped to the current Brown source dataset.",
            )

    return pd.NA, "unmapped", "unmapped", ""


def complete_dataset_link_for_row(row: pd.Series) -> tuple[object, bool, str, str]:
    filename = str(row["filename"])
    lowered = filename.lower()
    if "/raw/handbook_ebs/" in lowered:
        combined = str(HANDBOOK_COMBINED)
        appended = str(HANDBOOK_APPENDED)
        if handbook_page_matches_appended(filename):
            return appended, False, "linked_complete_nonstandalone", "EB page matched to handbook_appended aggregate"
        if lowered.endswith("/raw/handbook_ebs/combined_dataset.csv"):
            return combined, False, "self_complete_nonstandalone", "combined handbook csv aggregate"
        if lowered.endswith("/raw/handbook_ebs/handbook_appended.csv"):
            return appended, False, "self_complete_nonstandalone", "handbook EB aggregate csv with matched page rows"
        if lowered.endswith("/raw/handbook_ebs/_file_manifest.csv"):
            return combined, False, "linked_complete_nonstandalone", "manifest points to handbook combined aggregate"
        return combined, False, "linked_complete_nonstandalone", "handbook page/raw fragment linked to combined handbook aggregate"
    if str(row["relative_dir"]) == "clean/handbooks":
        handbook_pc0111_inputs = {
            "pc01_eb_appendix.csv",
            "pc01_pca_key.dta",
            "pc01_pdf.dta",
            "pc01_pdf_eb_clean.dta",
            "pc01_pdf_key.dta",
            "pc01_pdf_shrid_dissim.dta",
            "pc01_pdf_shrid_key.dta",
            "pc01_pdf_town_clean.dta",
            "pc01_unmerged_pdf.dta",
            "pc11_eb_appendix.csv",
            "pc11_pca_key.dta",
            "pc11_pdf.dta",
            "pc11_pdf_eb_clean.dta",
            "pc11_pdf_key.dta",
            "pc11_pdf_shrid_dissim.dta",
            "pc11_pdf_shrid_key.dta",
            "pc11_pdf_town_clean.dta",
        }
        if str(row["basename"]) in handbook_pc0111_inputs:
            return (
                str(HANDBOOK_PC0111_ANALYSIS),
                True,
                "linked_complete_standalone",
                "Linked to the merged PC01-PC11 handbook analysis dataset.",
            )
    basename = str(row["basename"])
    rel_dir = str(row["relative_dir"])
    if rel_dir == "clean/us" and basename == "msa_keys.dta":
        return (
            "/dartfs/rc/lab/I/IEC/seg/clean/us/us_census_msa_dissim.dta",
            False,
            "linked_complete_nonstandalone",
            "Clean MSA key merged into the downstream US census MSA dissimilarity dataset.",
        )
    if rel_dir == "raw/us":
        raw_us_links = {
            "census-tract-pop-2020.csv": (
                "/dartfs/rc/lab/I/IEC/seg/clean/us/us_tract_pop.dta",
                "Raw Census tract population CSV cleaned by gen_us_seg_variables.do.",
            ),
            "MSA_key.csv": (
                "/dartfs/rc/lab/I/IEC/seg/clean/us/msa_keys.dta",
                "Raw MSA-county key cleaned by gen_us_seg_variables.do.",
            ),
            "msa-level-pop-2020.csv": (
                "/dartfs/rc/lab/I/IEC/seg/clean/us/us_census_msa_dissim.dta",
                "Raw Census MSA population CSV merged into the clean US census MSA dissimilarity dataset.",
            ),
            "brown_city_dissimilarity.dta": (
                "/dartfs/rc/lab/I/IEC/seg/clean/us/brown_city_dissim_1980_2020.dta",
                "Raw Brown city dissimilarity panel underlying the clean Brown city comparison series.",
            ),
            "brown_msa_dissimilarity.dta": (
                "/dartfs/rc/lab/I/IEC/seg/clean/us/brown_msa_dissim_1980_2020.dta",
                "Raw Brown MSA dissimilarity panel underlying the clean Brown MSA comparison series.",
            ),
        }
        if basename in raw_us_links:
            linked_file, note = raw_us_links[basename]
            return linked_file, False, "linked_complete_nonstandalone", note
        if basename in {"frey_msa_100_dissimilarity.dta", "oi-tract-data.dta", "tract-place-key.csv"}:
            return (
                pd.NA,
                False,
                "no_clean_counterpart_found",
                "Current code search found this as a raw/source comparison input, but not as a creator input for an active clean complete dataset.",
            )
    if rel_dir == "raw/us/brown":
        brown_clean_links = {
            "city20d20.dta": "/dartfs/rc/lab/I/IEC/seg/clean/us/brown_city_dissim_1980_2020.dta",
            "msa20d20.dta": "/dartfs/rc/lab/I/IEC/seg/clean/us/brown_msa_dissim_1980_2020.dta",
        }
        if basename in brown_clean_links:
            return (
                brown_clean_links[basename],
                False,
                "linked_complete_nonstandalone",
                "Brown 2020 dissimilarity source linked to the clean Brown dissimilarity comparison series.",
            )
        if basename in {
            "cc20d20.dta",
            "cc20p20.dta",
            "city20p20.dta",
            "cityallp20.csv",
            "msa20p20.dta",
            "sb20d20.dta",
            "sb20p20.dta",
        }:
            return (
                pd.NA,
                False,
                "no_clean_counterpart_found",
                "Current code search found this as a Brown comparison source, but not as a creator input for an active clean complete dataset.",
            )
    if rel_dir == "raw/us/old":
        legacy_us_links = {
            "US_dissim.xlsx": "/dartfs/rc/lab/I/IEC/seg/raw/us/old/US_cityleveldata.dta",
            "US_iso.xlsx": "/dartfs/rc/lab/I/IEC/seg/raw/us/old/US_cityleveldata.dta",
            "usa_msa_dissim.xlsx": "/dartfs/rc/lab/I/IEC/seg/clean/us/us_census_msa_dissim.dta",
            "US_cityleveldata.dta": "/dartfs/rc/lab/I/IEC/seg/clean/us/brown_city_dissim_1980_2020.dta",
            "US_edu.csv": "/dartfs/rc/lab/I/IEC/seg/raw/us/old/US_cityleveldata.dta",
            "US_income.csv": "/dartfs/rc/lab/I/IEC/seg/raw/us/old/US_cityleveldata.dta",
            "uscityincome.dta": "/dartfs/rc/lab/I/IEC/seg/raw/us/old/US_cityleveldata.dta",
        }
        if basename in legacy_us_links:
            note = "Legacy US source/crosswalk predecessor linked to the current clean US comparison dataset."
            if basename in {"US_dissim.xlsx", "US_iso.xlsx", "US_edu.csv", "US_income.csv", "uscityincome.dta"}:
                note = "Legacy US income/education intermediate linked to the old generated city-level US clean dataset."
            return (
                legacy_us_links[basename],
                False,
                "legacy_counterpart_link",
                note,
            )
    if rel_dir == "old-2020/raw/us":
        old_2020_us_links = {
            "US_dissim.xlsx": "/dartfs/rc/lab/I/IEC/seg/raw/us/old/US_cityleveldata.dta",
            "US_iso.xlsx": "/dartfs/rc/lab/I/IEC/seg/raw/us/old/US_cityleveldata.dta",
            "US_edu.csv": "/dartfs/rc/lab/I/IEC/seg/raw/us/old/US_cityleveldata.dta",
            "US_income.csv": "/dartfs/rc/lab/I/IEC/seg/raw/us/old/US_cityleveldata.dta",
            "uscityincome.dta": "/dartfs/rc/lab/I/IEC/seg/raw/us/old/US_cityleveldata.dta",
            "US_cityleveldata.dta": "/dartfs/rc/lab/I/IEC/seg/raw/us/old/US_cityleveldata.dta",
        }
        if basename in old_2020_us_links:
            return (
                old_2020_us_links[basename],
                False,
                "legacy_counterpart_link",
                "Old-2020 US archive copy linked to the promoted legacy city-level US master dataset.",
            )

    if rel_dir == "religion":
        religion_match = re.fullmatch(r"pc11_muslims_(?P<sector>rural|urban)\.dta", basename, re.I)
        if religion_match:
            sector = religion_match.group("sector").lower()
            return (
                f"/dartfs/rc/lab/I/IEC/seg/clean/pc11/pc11_muslims_{sector}.dta",
                True,
                "linked_complete_standalone",
                "Religion-folder duplicate linked to the promoted clean/pc11 Muslim-share master dataset.",
            )
    if str(row["relative_dir"]) == "violence" and str(row["basename"]) in {
        "violence_matched_except_jk.dta",
        "violence_matched_jk.dta",
        "AV_Data_matched.dta",
        "AV_Data.xls",
    }:
        return (
            "/dartfs/rc/lab/I/IEC/seg/violence/violence_seg_analysis.dta",
            True,
            "linked_complete_standalone",
            "Linked to the complete violence analysis dataset built from the matched violence source files.",
        )
    return pd.NA, pd.NA, "", ""


@lru_cache(maxsize=2048)
def search_code_hits(term: str) -> tuple[tuple[str, int, str], ...]:
    cmd = ["rg", "-n", "-F", term]
    for root in CODE_SEARCH_ROOTS:
        cmd.append(str(root))
    for suffix in CODE_SUFFIXES:
        cmd.extend(["-g", suffix])
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    hits: list[tuple[str, int, str]] = []
    for line in result.stdout.splitlines():
        parts = line.split(":", 2)
        if len(parts) != 3:
            continue
        path, lineno, content = parts
        try:
            hits.append((shorten_code_path(path), int(lineno), content.strip()))
        except ValueError:
            continue
    return tuple(hits)


def infer_creator_from_code(row: pd.Series) -> tuple[object, object, str, str, str]:
    basename = str(row["basename"])
    stem = PurePosixPath(basename).stem
    terms = [basename]
    if stem != basename:
        terms.append(stem)

    for idx, term in enumerate(terms):
        hits = search_code_hits(term)
        if not hits:
            continue
        for path, line, content in hits:
            lowered = content.lower()
            if "save " in lowered or "outfile(" in lowered or "export delimited" in lowered:
                return path, line, "exact_save_match" if idx == 0 else "template_save_match", "high", content
        path, line, content = hits[0]
        return path, line, "downstream_usage_only", "medium", content

    return pd.NA, pd.NA, "unknown", "unknown", ""


def infer_represents(row: pd.Series) -> str:
    basename = str(row["basename"]).lower()
    top_level_section = str(row["top_level_section"])
    if "collapsed_block" in basename:
        sector = "rural" if "rural" in basename else "urban" if "urban" in basename else ""
        return f"Collapsed block-level master dataset for {sector} areas.".strip()
    if "collapsed" in basename:
        sector = "rural" if "rural" in basename else "urban" if "urban" in basename else ""
        return f"Collapsed upper-level master dataset for {sector} areas.".strip()
    if "blockdata" in basename:
        return "Block-level merged or analysis dataset."
    if "citydata" in basename:
        return "City-level merged or analysis dataset."
    if "pooled" in basename:
        return "Pooled analysis dataset."
    if top_level_section == "clean":
        return "Complete clean dataset."
    if top_level_section == "raw":
        return "Raw source dataset or extract."
    return "Structured dataset file."


def build_row(path: Path, dta_inventory: dict[str, dict[str, object]]) -> dict[str, object]:
    filename = str(path)
    parsed = parse_filename_fields(filename)
    ext = normalize_extension(path)
    row: dict[str, object] = {
        "filename": filename,
        "file_format": ext.lstrip("."),
        "file_extension_normalized": ext,
        "file_size_bytes": path.stat().st_size,
        **parsed,
    }
    row["legacy_reason"] = legacy_reason(filename)
    row["likely_legacy"] = bool(row["legacy_reason"])
    row["read_error_type"] = pd.NA
    row["read_error_message"] = pd.NA
    row["structure_notes"] = pd.NA

    if ext == ".dta":
        metadata = dta_inventory.get(filename)
        if metadata is None:
            row.update(
                {
                    "n_obs": pd.NA,
                    "n_vars": pd.NA,
                    "variable_list": "",
                    "structure_metadata_status": "missing_dta_inventory_row",
                    "read_error_type": "MissingInventoryRow",
                    "read_error_message": "No matching row in segdata_file_inventory.csv",
                }
            )
        else:
            row.update(
                {
                    "n_obs": metadata.get("n_obs", pd.NA),
                    "n_vars": metadata.get("n_vars", pd.NA),
                    "variable_list": metadata.get("variable_list", "") or "",
                    "structure_metadata_status": "full",
                    "structure_notes": "metadata sourced from existing dta inventory",
                }
            )
    else:
        if should_skip_deep_parse(filename, str(row["top_level_section"])):
            row.update(
                {
                    "n_obs": pd.NA,
                    "n_vars": pd.NA,
                    "variable_list": "",
                    "structure_metadata_status": "file_only_raw_fragment",
                    "structure_notes": "raw/support fragment; skipped deep parse for runtime",
                }
            )
        else:
            try:
                row.update(read_non_dta_metadata(path))
            except Exception as exc:
                row.update(
                    {
                        "n_obs": pd.NA,
                        "n_vars": pd.NA,
                        "variable_list": "",
                        "structure_metadata_status": "unreadable",
                        "read_error_type": type(exc).__name__,
                        "read_error_message": str(exc),
                    }
                )
    return row


def write_sheet_xml(df: pd.DataFrame) -> str:
    rows_xml: list[str] = []
    headers = list(df.columns)
    all_rows = [headers] + df.astype(object).where(pd.notna(df), "").values.tolist()
    for row_idx, values in enumerate(all_rows, start=1):
        cells: list[str] = []
        for col_idx, value in enumerate(values, start=1):
            ref = f"{column_letter(col_idx)}{row_idx}"
            cell_xml = to_xlsx_cell_xml(ref, value)
            cells.append(cell_xml)
        rows_xml.append(f'<row r="{row_idx}">{"".join(cells)}</row>')
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        f'<worksheet xmlns="{NS_MAIN}"><sheetData>'
        f'{"".join(rows_xml)}'
        "</sheetData></worksheet>"
    )


def column_letter(index: int) -> str:
    letters: list[str] = []
    while index > 0:
        index, remainder = divmod(index - 1, 26)
        letters.append(chr(65 + remainder))
    return "".join(reversed(letters))


def to_xlsx_cell_xml(ref: str, value: object) -> str:
    if value is None or value == "":
        return f'<c r="{ref}" t="inlineStr"><is><t></t></is></c>'
    if isinstance(value, bool):
        return f'<c r="{ref}" t="inlineStr"><is><t>{str(value)}</t></is></c>'
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if pd.isna(value):
            return f'<c r="{ref}" t="inlineStr"><is><t></t></is></c>'
        return f'<c r="{ref}"><v>{value}</v></c>'
    text = escape(str(value))
    return f'<c r="{ref}" t="inlineStr"><is><t>{text}</t></is></c>'


def write_xlsx(workbook_path: Path, sheets: list[tuple[str, pd.DataFrame]]) -> None:
    now = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    with zipfile.ZipFile(workbook_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr(
            "[Content_Types].xml",
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            '<Default Extension="xml" ContentType="application/xml"/>'
            '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
            '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
            '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
            + "".join(
                f'<Override PartName="/xl/worksheets/sheet{idx}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
                for idx in range(1, len(sheets) + 1)
            )
            + "</Types>",
        )
        zf.writestr(
            "_rels/.rels",
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            f'<Relationships xmlns="{NS_PKG}">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
            '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
            '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
            "</Relationships>",
        )
        zf.writestr(
            "docProps/core.xml",
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
            'xmlns:dc="http://purl.org/dc/elements/1.1/" '
            'xmlns:dcterms="http://purl.org/dc/terms/" '
            'xmlns:dcmitype="http://purl.org/dc/dcmitype/" '
            'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
            "<dc:title>SEG dataset inventory</dc:title>"
            "<dc:creator>Codex</dc:creator>"
            f'<dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created>'
            f'<dcterms:modified xsi:type="dcterms:W3CDTF">{now}</dcterms:modified>'
            "</cp:coreProperties>",
        )
        zf.writestr(
            "docProps/app.xml",
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
            'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
            "<Application>Codex</Application>"
            f"<Sheets>{len(sheets)}</Sheets>"
            "</Properties>",
        )

        workbook_sheets = []
        workbook_rels = []
        for idx, (sheet_name, df) in enumerate(sheets, start=1):
            workbook_sheets.append(
                f'<sheet name="{escape(sheet_name)}" sheetId="{idx}" r:id="rId{idx}"/>'
            )
            workbook_rels.append(
                f'<Relationship Id="rId{idx}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet{idx}.xml"/>'
            )
            zf.writestr(f"xl/worksheets/sheet{idx}.xml", write_sheet_xml(df))

        zf.writestr(
            "xl/workbook.xml",
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            f'<workbook xmlns="{NS_MAIN}" xmlns:r="{NS_REL}">'
            f"<sheets>{''.join(workbook_sheets)}</sheets>"
            "</workbook>",
        )
        zf.writestr(
            "xl/_rels/workbook.xml.rels",
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            f'<Relationships xmlns="{NS_PKG}">'
            f"{''.join(workbook_rels)}"
            "</Relationships>",
        )


def try_read_existing_csv(path: Path) -> pd.DataFrame:
    if not path.exists():
        return pd.DataFrame()
    return pd.read_csv(path, low_memory=False)


def normalize_compare_value(value: object) -> str:
    if pd.isna(value):
        return ""
    if isinstance(value, bool):
        return str(value)
    text = str(value).strip()
    if not text:
        return ""
    try:
        numeric_value = float(text)
        if numeric_value.is_integer():
            return str(int(numeric_value))
        return f"{numeric_value:.12g}"
    except ValueError:
        return text


def build_change_report(
    previous_inventory: pd.DataFrame,
    current_inventory: pd.DataFrame,
) -> pd.DataFrame:
    if previous_inventory.empty:
        return pd.DataFrame(
            [
                {
                    "filename": "",
                    "change_type": "initial_build",
                    "changed_fields": "",
                    "old_value": "",
                    "new_value": "",
                }
            ]
        )

    previous = previous_inventory.set_index("filename", drop=False)
    current = current_inventory.set_index("filename", drop=False)
    all_filenames = sorted(set(previous.index) | set(current.index))
    records: list[dict[str, str]] = []

    for filename in all_filenames:
        in_previous = filename in previous.index
        in_current = filename in current.index
        if not in_previous:
            records.append(
                {
                    "filename": filename,
                    "change_type": "added",
                    "changed_fields": "",
                    "old_value": "",
                    "new_value": "",
                }
            )
            continue
        if not in_current:
            records.append(
                {
                    "filename": filename,
                    "change_type": "removed",
                    "changed_fields": "",
                    "old_value": "",
                    "new_value": "",
                }
            )
            continue

        previous_row = previous.loc[filename]
        current_row = current.loc[filename]
        changed_fields: list[str] = []
        for column in TRACKED_CHANGE_COLUMNS:
            if column not in previous_row.index or column not in current_row.index:
                continue
            old_value = normalize_compare_value(previous_row[column])
            new_value = normalize_compare_value(current_row[column])
            if old_value != new_value:
                changed_fields.append(column)

        if changed_fields:
            for column in changed_fields:
                records.append(
                    {
                        "filename": filename,
                        "change_type": "changed",
                        "changed_fields": column,
                        "old_value": normalize_compare_value(previous_row[column]),
                        "new_value": normalize_compare_value(current_row[column]),
                    }
                )

    if not records:
        records.append(
            {
                "filename": "",
                "change_type": "no_tracked_changes",
                "changed_fields": "",
                "old_value": "",
                "new_value": "",
            }
        )
    return pd.DataFrame(records)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def current_git_commit() -> str:
    result = subprocess.run(
        ["git", "rev-parse", "--short", "HEAD"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def write_tracking_artifacts(
    *,
    output_dir: Path,
    inventory: pd.DataFrame,
    standalone: pd.DataFrame,
    complete_views: dict[str, pd.DataFrame] | None,
    errors: pd.DataFrame,
    workbook_path: Path,
    all_files_path: Path,
    standalone_path: Path,
    canonical_path: Path,
    derived_path: Path,
    source_path: Path,
    legacy_path: Path,
    excluded_path: Path,
    errors_path: Path,
    previous_inventory: pd.DataFrame,
) -> None:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    history_dir = output_dir / "history"
    history_dir.mkdir(parents=True, exist_ok=True)

    change_report = build_change_report(previous_inventory, inventory)
    change_report_path = output_dir / "seg_dataset_inventory_change_report.csv"
    change_report.to_csv(change_report_path, index=False)

    snapshot_workbook_path = history_dir / f"seg_dataset_inventory_{timestamp}.xlsx"
    shutil.copy2(workbook_path, snapshot_workbook_path)

    manifest = {
        "generated_at_utc": timestamp,
        "git_commit": current_git_commit(),
        "outputs": {
            "workbook": {
                "path": str(workbook_path),
                "sha256": sha256_file(workbook_path),
                "snapshot_path": str(snapshot_workbook_path),
            },
            "all_files_csv": {
                "path": str(all_files_path),
                "sha256": sha256_file(all_files_path),
                "row_count": int(len(inventory)),
            },
            "standalone_csv": {
                "path": str(standalone_path),
                "sha256": sha256_file(standalone_path),
                "row_count": int(len(standalone)),
            },
            "canonical_csv": {
                "path": str(canonical_path),
                "sha256": sha256_file(canonical_path),
                "row_count": int(len(complete_views["canonical"])) if complete_views else 0,
            },
            "derived_csv": {
                "path": str(derived_path),
                "sha256": sha256_file(derived_path),
                "row_count": int(len(complete_views["derived"])) if complete_views else 0,
            },
            "source_csv": {
                "path": str(source_path),
                "sha256": sha256_file(source_path),
                "row_count": int(len(complete_views["source"])) if complete_views else 0,
            },
            "legacy_csv": {
                "path": str(legacy_path),
                "sha256": sha256_file(legacy_path),
                "row_count": int(len(complete_views["legacy"])) if complete_views else 0,
            },
            "excluded_csv": {
                "path": str(excluded_path),
                "sha256": sha256_file(excluded_path),
                "row_count": int(len(complete_views["excluded"])) if complete_views else 0,
            },
            "errors_csv": {
                "path": str(errors_path),
                "sha256": sha256_file(errors_path),
                "row_count": int(len(errors)),
            },
            "change_report_csv": {
                "path": str(change_report_path),
                "sha256": sha256_file(change_report_path),
                "row_count": int(len(change_report)),
            },
        },
        "summary": {
            "all_files_rows": int(len(inventory)),
            "standalone_rows": int(len(standalone)),
            "canonical_rows": int(len(complete_views["canonical"])) if complete_views else 0,
            "derived_rows": int(len(complete_views["derived"])) if complete_views else 0,
            "source_rows": int(len(complete_views["source"])) if complete_views else 0,
            "legacy_rows": int(len(complete_views["legacy"])) if complete_views else 0,
            "excluded_rows": int(len(complete_views["excluded"])) if complete_views else 0,
            "error_rows": int(len(errors)),
            "tracked_change_rows": int(len(change_report)),
            "tracked_changed_files": int(
                change_report.loc[change_report["change_type"] == "changed", "filename"].nunique()
            ),
            "tracked_added_files": int(
                change_report.loc[change_report["change_type"] == "added", "filename"].nunique()
            ),
            "tracked_removed_files": int(
                change_report.loc[change_report["change_type"] == "removed", "filename"].nunique()
            ),
        },
    }

    latest_manifest_path = output_dir / "seg_dataset_inventory_manifest.json"
    history_manifest_path = history_dir / f"seg_dataset_inventory_manifest_{timestamp}.json"
    latest_manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    history_manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def build_inventory(root: Path, dta_inventory_path: Path, limit: int | None = None) -> tuple[pd.DataFrame, pd.DataFrame]:
    dta_inventory = load_dta_inventory(dta_inventory_path)
    rows: list[dict[str, object]] = []
    error_rows: list[dict[str, object]] = []

    for idx, path in enumerate(iter_structured_files(root, limit=limit), start=1):
        row = build_row(path, dta_inventory)
        rows.append(row)
        if pd.notna(row.get("read_error_type")):
            error_rows.append(
                {
                    "filename": row["filename"],
                    "file_format": row["file_format"],
                    "error_type": row["read_error_type"],
                    "error_message": row["read_error_message"],
                }
            )
        if idx % 500 == 0:
            print(f"Processed {idx} structured data files...")

    inventory = pd.DataFrame(rows).sort_values("filename").reset_index(drop=True)

    documentation_records: list[dict[str, object]] = []
    for _, row in inventory.iterrows():
        rule_match = explicit_us_rule(row)
        if rule_match is None:
            rule_match = apply_rules(row)
        if rule_match is not None:
            dataset_role = rule_match.dataset_role
            pipeline_stage = rule_match.pipeline_stage
            represents = rule_match.represents
            creator_script = rule_match.creator_script
            creator_line = rule_match.creator_line
            creator_basis = rule_match.creator_basis
            documentation_confidence = rule_match.documentation_confidence
            is_complete_standalone = rule_match.is_complete_standalone
            is_analysis_ready_standalone = rule_match.is_analysis_ready_standalone
        else:
            dataset_role, pipeline_stage = infer_role_stage(row)
            is_complete_standalone = is_complete_standalone_candidate(row, dataset_role)
            is_analysis_ready_standalone = is_analysis_ready_standalone_candidate(row, dataset_role)
            represents = infer_represents(row)
            needs_generic_lookup = any(
                marker in str(row["basename"]).lower() for marker in ANALYSIS_MARKERS
            ) or str(row["top_level_section"]) == ""
            if (is_complete_standalone or is_analysis_ready_standalone) and needs_generic_lookup:
                creator_script, creator_line, creator_basis, documentation_confidence, _ = infer_creator_from_code(row)
            else:
                creator_script, creator_line, creator_basis, documentation_confidence = (
                    pd.NA,
                    pd.NA,
                    "unknown",
                    "unknown",
                )

        creator_override = explicit_creator_override(row)
        if creator_override is not None and (
            is_missing_value(creator_script) or creator_basis in {"unknown", "downstream_usage_only", "template_save_match"}
        ):
            creator_script, creator_line, creator_basis, documentation_confidence = creator_override

        documentation_records.append(
            {
                "dataset_role": dataset_role,
                "pipeline_stage": pipeline_stage,
                "represents": represents,
                "creator_script": creator_script,
                "creator_line": creator_line,
                "creator_basis": creator_basis,
                "documentation_confidence": documentation_confidence,
                "is_complete_standalone": bool(is_complete_standalone),
                "is_analysis_ready_standalone": bool(is_analysis_ready_standalone),
            }
        )

    inventory = pd.concat([inventory, pd.DataFrame(documentation_records)], axis=1)
    mapping = inventory.apply(master_mapping_for_row, axis=1, result_type="expand")
    mapping.columns = [
        "master_pooled_file",
        "master_mapping_status",
        "master_mapping_basis",
        "master_mapping_note",
    ]
    inventory = pd.concat([inventory, mapping], axis=1)
    complete_links = inventory.apply(complete_dataset_link_for_row, axis=1, result_type="expand")
    complete_links.columns = [
        "linked_complete_dataset_file",
        "linked_complete_dataset_in_standalone",
        "linked_complete_dataset_status",
        "linked_complete_dataset_note",
    ]
    inventory = pd.concat([inventory, complete_links], axis=1)
    complete_class_records = inventory.apply(classify_complete_dataset, axis=1, result_type="expand")
    inventory = pd.concat([inventory, complete_class_records], axis=1)
    inventory["needs_complete_dataset_flag"] = (
        inventory["master_mapping_status"].eq("unmapped")
        & inventory["linked_complete_dataset_file"].notna()
    )

    frames = split_complete_inventory(inventory)
    standalone = frames["standalone"]
    errors = (
        pd.DataFrame(error_rows).sort_values(["file_format", "filename"]).reset_index(drop=True)
        if error_rows
        else pd.DataFrame(columns=["filename", "file_format", "error_type", "error_message"])
    )
    return inventory, standalone, errors


def main() -> None:
    args = parse_args()
    root = args.root.expanduser().resolve()
    dta_inventory_path = args.dta_inventory.expanduser().resolve()
    output_dir = args.output_dir.expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    all_files_path = output_dir / "seg_dataset_inventory_all_files.csv"
    standalone_path = output_dir / "seg_dataset_inventory_standalone.csv"
    canonical_path = output_dir / "seg_dataset_inventory_canonical_complete.csv"
    derived_path = output_dir / "seg_dataset_inventory_derived_complete.csv"
    source_path = output_dir / "seg_dataset_inventory_source_complete.csv"
    legacy_path = output_dir / "seg_dataset_inventory_legacy_complete.csv"
    excluded_path = output_dir / "seg_dataset_inventory_excluded_complete_candidates.csv"
    errors_path = output_dir / "seg_dataset_inventory_read_errors.csv"
    workbook_path = output_dir / "seg_dataset_inventory.xlsx"
    previous_inventory = try_read_existing_csv(all_files_path)

    inventory, standalone, errors = build_inventory(root, dta_inventory_path, limit=args.limit)
    complete_views = split_complete_inventory(inventory)

    inventory.to_csv(all_files_path, index=False)
    standalone.to_csv(standalone_path, index=False)
    complete_views["canonical"].to_csv(canonical_path, index=False)
    complete_views["derived"].to_csv(derived_path, index=False)
    complete_views["source"].to_csv(source_path, index=False)
    complete_views["legacy"].to_csv(legacy_path, index=False)
    complete_views["excluded"].to_csv(excluded_path, index=False)
    errors.to_csv(errors_path, index=False)
    column_guide = build_column_guide()
    write_xlsx(
        workbook_path,
        [
            ("all_files_with_master", inventory),
            ("standalone_datasets", standalone),
            ("canonical_complete_datasets", complete_views["canonical"]),
            ("derived_complete_datasets", complete_views["derived"]),
            ("source_complete_datasets", complete_views["source"]),
            ("legacy_complete_datasets", complete_views["legacy"]),
            ("excluded_complete_candidates", complete_views["excluded"]),
            ("column_guide", column_guide),
        ],
    )
    write_tracking_artifacts(
        output_dir=output_dir,
        inventory=inventory,
        standalone=standalone,
        complete_views=complete_views,
        errors=errors,
        workbook_path=workbook_path,
        all_files_path=all_files_path,
        standalone_path=standalone_path,
        canonical_path=canonical_path,
        derived_path=derived_path,
        source_path=source_path,
        legacy_path=legacy_path,
        excluded_path=excluded_path,
        errors_path=errors_path,
        previous_inventory=previous_inventory,
    )

    print(f"Wrote all-files inventory: {all_files_path}")
    print(f"Wrote standalone dataset inventory: {standalone_path}")
    print(f"Wrote canonical complete datasets: {canonical_path}")
    print(f"Wrote derived complete datasets: {derived_path}")
    print(f"Wrote source complete datasets: {source_path}")
    print(f"Wrote legacy complete datasets: {legacy_path}")
    print(f"Wrote excluded complete candidates: {excluded_path}")
    print(f"Wrote read errors: {errors_path}")
    print(f"Wrote workbook: {workbook_path}")
    print(f"Wrote manifest: {output_dir / 'seg_dataset_inventory_manifest.json'}")
    print(f"Wrote change report: {output_dir / 'seg_dataset_inventory_change_report.csv'}")


if __name__ == "__main__":
    main()
