from __future__ import annotations

import csv
import importlib.util
import re
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

import pandas as pd


SEG_ROOT = Path("/dartfs/rc/lab/I/IEC/seg")
REPO_ROOT = Path("/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation")
SEGREGATION_REPO = Path("/dartfs-hpc/rc/home/m/f00858m/ddl/segregation")
METADATA_DIR = Path("/dartfs-hpc/scratch/siddiqui/seg_cleanup/metadata")
NOTE_OUT_DIR = REPO_ROOT / "inventory"
DATA_OUT_DIR = Path("/dartfs-hpc/scratch/siddiqui/seg_cleanup/inventory_review")

BASE_SHEETS = {
    "all_files_with_master": METADATA_DIR / "seg_dataset_inventory_all_files.csv",
    "standalone_datasets": METADATA_DIR / "seg_dataset_inventory_standalone.csv",
    "canonical_complete_datasets": METADATA_DIR / "seg_dataset_inventory_canonical_complete.csv",
    "derived_complete_datasets": METADATA_DIR / "seg_dataset_inventory_derived_complete.csv",
    "source_complete_datasets": METADATA_DIR / "seg_dataset_inventory_source_complete.csv",
    "legacy_complete_datasets": METADATA_DIR / "seg_dataset_inventory_legacy_complete.csv",
    "excluded_complete_candidates": METADATA_DIR / "seg_dataset_inventory_excluded_complete_candidates.csv",
}

CODE_SUFFIXES = {
    ".do",
    ".ado",
    ".py",
    ".r",
    ".R",
    ".sh",
    ".mk",
}

FINAL_COLUMNS = [
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

STANDALONE_CLASSES = {
    "canonical_standalone",
    "standalone_source",
    "legacy_standalone",
}

NON_FINAL_STANDALONE_CLASSES = {
    "raw_input",
    "support_or_key",
    "partition_or_shard",
    "derived_complete",
    "excluded_bad_artifact",
}


@dataclass(frozen=True)
class CodeEvent:
    dataset_file: str
    access: str
    script: str
    line: int
    evidence: str


def load_write_xlsx():
    module_path = REPO_ROOT / "e" / "build_master_dataset_inventory.py"
    spec = importlib.util.spec_from_file_location("build_master_dataset_inventory", module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to import {module_path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module.write_xlsx


def read_base_sheets() -> dict[str, pd.DataFrame]:
    sheets = {name: pd.read_csv(path, dtype=str).fillna("") for name, path in BASE_SHEETS.items()}
    column_guide = pd.read_csv(METADATA_DIR / "seg_dataset_inventory_all_files.csv", dtype=str, nrows=0)
    guide_records = [
        {"column": col, "meaning": "Original inventory column.", "category": "existing inventory"}
        for col in column_guide.columns
    ]
    guide_records.extend(
        {"column": col, "meaning": final_column_description(col), "category": "review classification"}
        for col in FINAL_COLUMNS
    )
    sheets["column_guide"] = pd.DataFrame(guide_records)
    return sheets


def final_column_description(column: str) -> str:
    descriptions = {
        "final_inventory_class": "Final reviewed taxonomy class.",
        "primary_standalone_flag": "TRUE only for rows retained in final_standalone_datasets.",
        "family_id": "Stable family identifier used to group variants, inputs, and duplicates.",
        "unit_of_observation": "Best inferred observation unit.",
        "conceptual_object": "Human-readable object represented by the dataset.",
        "canonical_parent_file": "Upstream complete parent or canonical representative.",
        "lineage_inputs": "Semicolon-delimited direct upstream files found in code lineage.",
        "lineage_outputs": "Semicolon-delimited direct downstream files found in code lineage.",
        "writer_script": "Script most directly writing the dataset.",
        "writer_line": "Line number for writer_script when available.",
        "reader_scripts": "Semicolon-delimited scripts that read the dataset.",
        "used_in_analysis": "TRUE if read by analysis/table/figure code or classified as analysis-ready.",
        "evidence_summary": "Short explanation for the final classification.",
        "confidence": "high, medium, or low confidence in the classification.",
        "manual_review_reason": "Reason the row remains ambiguous or contradictory.",
    }
    return descriptions[column]


def repo_label(script: Path) -> str:
    for root in (REPO_ROOT, SEGREGATION_REPO):
        try:
            rel = script.relative_to(root)
            return f"{root.name}/{rel.as_posix()}"
        except ValueError:
            continue
    return script.as_posix()


def iter_code_files() -> list[Path]:
    files: list[Path] = []
    for root in (REPO_ROOT, SEGREGATION_REPO):
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            if path.name.lower() in {"makefile", "gnumakefile"} or path.suffix in CODE_SUFFIXES:
                if ".git" not in path.parts:
                    files.append(path)
    return sorted(files)


def strip_stata_comment(line: str) -> str:
    stripped = line.strip()
    if stripped.startswith("*"):
        return ""
    return re.sub(r"/\*.*?\*/", "", line)


def clean_token(token: str) -> str:
    token = token.strip().strip('"').strip("'")
    token = token.rstrip(",);]")
    token = token.lstrip("([")
    return token.strip().strip('"').strip("'")


def expand_macros(token: str) -> str | None:
    if not token:
        return None
    if "`" in token:
        return None

    replacements = {
        "${sdata}": str(SEG_ROOT / "clean"),
        "$sdata": str(SEG_ROOT / "clean"),
        "${tmp}": str(SEG_ROOT / "clean"),
        "$tmp": str(SEG_ROOT / "clean"),
        "${seg}": str(SEG_ROOT / "raw"),
        "$seg": str(SEG_ROOT / "raw"),
        "${raw}": str(SEG_ROOT),
        "$raw": str(SEG_ROOT),
        "${iec}/seg": str(SEG_ROOT),
        "$iec/seg": str(SEG_ROOT),
        "${out}": str(SEG_ROOT / "output"),
        "$out": str(SEG_ROOT / "output"),
        "${shrug}": str(SEG_ROOT / "raw" / "shrug"),
        "$shrug": str(SEG_ROOT / "raw" / "shrug"),
    }
    expanded = token
    for macro, value in replacements.items():
        expanded = expanded.replace(macro, value)
    if expanded.startswith("/"):
        return expanded
    if expanded.startswith("clean/") or expanded.startswith("raw/") or expanded.startswith("old-2020/"):
        return str(SEG_ROOT / expanded)
    return None


def normalize_dataset_token(token: str, default_suffix: str = ".dta") -> str | None:
    token = clean_token(token)
    expanded = expand_macros(token)
    if expanded is None:
        return None
    path = Path(expanded)
    if path.suffix == "" and default_suffix:
        path = path.with_suffix(default_suffix)
    suffix = path.suffix.lower()
    if suffix not in {".dta", ".csv", ".xlsx", ".xls", ".geojson", ".parquet"}:
        return None
    return path.as_posix()


def parse_code_events() -> list[CodeEvent]:
    events: list[CodeEvent] = []
    state_by_script: dict[Path, str] = {}
    stata_patterns = [
        ("read", re.compile(r"\buse\s+([^,\s]+)", re.I), ".dta"),
        ("read", re.compile(r"\bmerge\b.+?\busing\s+([^,\s]+)", re.I), ".dta"),
        ("read", re.compile(r"\bappend\s+using\s+([^,\s]+)", re.I), ".dta"),
        ("read", re.compile(r"\bimport\s+delimited(?:\s+using)?\s+([^,\s]+)", re.I), ".csv"),
        ("read", re.compile(r"\bimport\s+excel(?:\s+using)?\s+([^,\s]+)", re.I), ".xlsx"),
        ("write", re.compile(r"\bsave\s+([^,\s]+)", re.I), ".dta"),
        ("write", re.compile(r"\bexport\s+delimited(?:\s+using)?\s+([^,\s]+)", re.I), ".csv"),
        ("write", re.compile(r"\bexport\s+excel(?:\s+using)?\s+([^,\s]+)", re.I), ".xlsx"),
        ("read", re.compile(r"\binsheet(?:\s+using)?\s+([^,\s]+)", re.I), ".csv"),
        ("write", re.compile(r"\boutfile\b.+?\busing\s+([^,\s]+)", re.I), ".csv"),
    ]
    python_r_patterns = [
        ("read", re.compile(r"(?:read_csv|read\.csv)\s*\(\s*[\"']([^\"']+)[\"']", re.I), ".csv"),
        ("write", re.compile(r"(?:to_csv|write\.csv)\s*\(\s*[\"']([^\"']+)[\"']", re.I), ".csv"),
        ("read", re.compile(r"(?:read_stata|read_dta|read\.dta)\s*\(\s*[\"']([^\"']+)[\"']", re.I), ".dta"),
        ("write", re.compile(r"(?:to_stata|write_dta|write\.dta)\s*\(\s*[\"']([^\"']+)[\"']", re.I), ".dta"),
        ("read", re.compile(r"read_parquet\s*\(\s*[\"']([^\"']+)[\"']", re.I), ".parquet"),
        ("write", re.compile(r"to_parquet\s*\(\s*[\"']([^\"']+)[\"']", re.I), ".parquet"),
    ]

    for script in iter_code_files():
        try:
            lines = script.read_text(errors="ignore").splitlines()
        except OSError:
            continue
        label = repo_label(script)
        for line_no, raw_line in enumerate(lines, start=1):
            line = strip_stata_comment(raw_line)
            upper = raw_line.upper()
            if "INPUTS:" in upper:
                state_by_script[script] = "read"
            elif "OUTPUTS:" in upper:
                state_by_script[script] = "write"
            elif "GOAL:" in upper or "DATA SOURCES" in upper:
                state_by_script.pop(script, None)

            summary_match = re.search(r"-\s+([$/][^ \t]+(?:\.(?:dta|csv|xlsx|xls|geojson|parquet))?)", raw_line)
            if summary_match and script in state_by_script:
                dataset = normalize_dataset_token(summary_match.group(1))
                if dataset:
                    events.append(CodeEvent(dataset, state_by_script[script], label, line_no, "ai_summary"))

            for access, pattern, suffix in stata_patterns:
                match = pattern.search(line)
                if match:
                    dataset = normalize_dataset_token(match.group(1), suffix)
                    if dataset:
                        events.append(CodeEvent(dataset, access, label, line_no, "stata_command"))

            for access, pattern, suffix in python_r_patterns:
                match = pattern.search(line)
                if match:
                    dataset = normalize_dataset_token(match.group(1), suffix)
                    if dataset:
                        events.append(CodeEvent(dataset, access, label, line_no, "python_r_command"))

    return dedupe_events(events)


def dedupe_events(events: list[CodeEvent]) -> list[CodeEvent]:
    seen: set[tuple[str, str, str, int, str]] = set()
    deduped: list[CodeEvent] = []
    for event in events:
        key = (event.dataset_file, event.access, event.script, event.line, event.evidence)
        if key not in seen:
            seen.add(key)
            deduped.append(event)
    return deduped


def build_edges(events: list[CodeEvent]) -> pd.DataFrame:
    by_script: dict[str, list[CodeEvent]] = defaultdict(list)
    for event in events:
        by_script[event.script].append(event)
    records: list[dict[str, object]] = []
    for script, script_events in by_script.items():
        inputs: list[CodeEvent] = []
        for event in sorted(script_events, key=lambda e: e.line):
            if event.access == "read":
                inputs.append(event)
                continue
            if event.access != "write":
                continue
            for source in inputs:
                records.append(
                    {
                        "source_file": source.dataset_file,
                        "target_file": event.dataset_file,
                        "script": script,
                        "source_line": source.line,
                        "target_line": event.line,
                        "evidence": f"{source.evidence}->{event.evidence}",
                    }
                )
            inputs.append(event)
    if not records:
        return pd.DataFrame(columns=["source_file", "target_file", "script", "source_line", "target_line", "evidence"])
    return pd.DataFrame(records).drop_duplicates().sort_values(["script", "target_line", "source_file"])


def semi(values: list[object]) -> str:
    cleaned = []
    seen = set()
    for value in values:
        if pd.isna(value):
            continue
        text = str(value).strip()
        if text and text not in seen:
            seen.add(text)
            cleaned.append(text)
    return "; ".join(cleaned)


def family_id_for(row: pd.Series, parent: str) -> str:
    filename = str(row.get("filename", ""))
    basename = str(row.get("basename", Path(filename).name)).lower()
    anchor = parent or filename
    stem = Path(anchor).stem.lower() if anchor else Path(basename).stem.lower()
    stem = re.sub(r"_pooled_?\d*$", "_pooled", stem)
    stem = re.sub(r"_(?:200|4000|10000|[0-9]+p)$", "", stem)
    stem = re.sub(r"_(?:rural|urban)$", "_sector", stem)
    return stem


def infer_unit(row: pd.Series) -> str:
    text = f"{row.get('filename', '')} {row.get('basename', '')} {row.get('variable_list', '')}".lower()
    if "tract" in text:
        return "census tract"
    if "msa" in text:
        return "metropolitan area"
    if "block" in text or "eb" in text:
        return "enumeration block"
    if "city" in text or "town" in text:
        return "city/town"
    if "village" in text or "shrid" in text:
        return "village/shrid"
    if "district" in text:
        return "district"
    if "individual" in text:
        return "individual"
    if "household" in text or "hh" in text:
        return "household"
    if "state" in text:
        return "state"
    return "dataset-specific"


def infer_object(row: pd.Series) -> str:
    basename = str(row.get("basename", "")).lower()
    represents = str(row.get("represents", "")).strip()
    if represents:
        return represents
    if "secc_ec" in basename:
        return "Merged SECC and Economic Census dataset"
    if "secc" in basename and "individual" in basename:
        return "SECC individual sample"
    if basename.startswith("ec") and "appended" in basename:
        return "Appended Economic Census establishment dataset"
    if "ed_health" in basename:
        return "Economic Census education and health subset"
    if "dissim" in basename or "segregation" in basename:
        return "Segregation/dissimilarity analysis dataset"
    if "muslim" in basename:
        return "PC11 Muslim share dataset"
    if "violence" in basename:
        return "Violence and segregation analysis dataset"
    if "brown" in basename:
        return "Brown US segregation comparison dataset"
    if "us_" in basename or "msa" in basename:
        return "US census segregation comparison dataset"
    return Path(str(row.get("filename", basename))).stem.replace("_", " ")


def classify_row(
    row: pd.Series,
    old_standalone: set[str],
    inputs_by_target: dict[str, list[str]],
    outputs_by_source: dict[str, list[str]],
    readers: dict[str, list[str]],
    writers: dict[str, list[CodeEvent]],
    basename_counts: dict[str, int],
) -> dict[str, object]:
    filename = str(row["filename"])
    basename = str(row.get("basename", Path(filename).name))
    lower = basename.lower()
    rel_dir = str(row.get("relative_dir", ""))
    old_decision = str(row.get("inventory_decision", ""))
    dataset_role = str(row.get("dataset_role", ""))
    likely_legacy = str(row.get("likely_legacy", "")).lower() == "true"
    complete_class = str(row.get("complete_dataset_class", ""))
    current_parent = str(row.get("canonical_parent_file", "")).strip()
    linked = str(row.get("linked_complete_dataset_file", "")).strip()
    direct_inputs = inputs_by_target.get(filename, [])
    direct_outputs = outputs_by_source.get(filename, [])
    writer_events = writers.get(filename, [])
    reader_scripts = readers.get(filename, [])
    writer_script = writer_events[0].script if writer_events else str(row.get("creator_script", ""))
    writer_line = writer_events[0].line if writer_events else str(row.get("creator_line", ""))
    used_in_analysis = any("/a/" in s or "table" in s.lower() or "figure" in s.lower() for s in reader_scripts)
    if dataset_role in {"analysis_dataset", "final_analysis_dataset"}:
        used_in_analysis = True

    final_class = "manual_review"
    parent = current_parent or linked
    confidence = "medium"
    manual_reason = ""
    evidence_parts: list[str] = []

    def set_decision(cls: str, conf: str, reason: str = "", parent_override: str | None = None) -> None:
        nonlocal final_class, confidence, manual_reason, parent
        final_class = cls
        confidence = conf
        manual_reason = reason
        if parent_override is not None:
            parent = parent_override

    if old_decision == "not_complete" and filename in old_standalone:
        manual_reason = "Row was present in standalone_datasets despite inventory_decision=not_complete."

    if str(row.get("top_level_section", "")).lower() == "partitioned" or "partitioned" in rel_dir:
        set_decision("partition_or_shard", "high")
    elif lower in {"ec13__city.dta", "append_hb_test.csv"} or "test" in lower:
        set_decision("excluded_bad_artifact", "high")
    elif rel_dir == "clean/pc11" and lower in {"pc11_muslims_rural.dta", "pc11_muslims_urban.dta"}:
        set_decision("canonical_standalone", "high", parent_override=filename)
    elif rel_dir == "religion" and lower in {"pc11_muslims_rural.dta", "pc11_muslims_urban.dta"}:
        sector = "rural" if "rural" in lower else "urban"
        set_decision(
            "derived_complete",
            "high",
            parent_override=f"/dartfs/rc/lab/I/IEC/seg/clean/pc11/pc11_muslims_{sector}.dta",
        )
    elif lower in {"pc01_pdf_shrid_dissim.dta", "pc11_pdf_shrid_dissim.dta", "pc11_secc_shrid_dissim.dta"}:
        set_decision("derived_complete", "high", parent_override="/dartfs/rc/lab/I/IEC/seg/raw/handbook_ebs/handbook_appended.csv")
    elif dataset_role == "support_key_lookup" or re.search(r"(^|_)(key|keys|crosswalk|lookup|bridge)(_|\.|$)", lower):
        set_decision("support_or_key", "high")
    elif rel_dir == "clean/us" and lower == "msa_keys.dta":
        set_decision("support_or_key", "high")
    elif rel_dir == "raw/us/old" and lower == "us_cityleveldata.dta":
        set_decision("legacy_standalone", "high", parent_override=filename)
    elif rel_dir == "old-2020/raw/us" and lower == "us_cityleveldata.dta":
        set_decision(
            "excluded_bad_artifact",
            "high",
            "Duplicate archive copy; canonical legacy representative is raw/us/old/US_cityleveldata.dta.",
            "/dartfs/rc/lab/I/IEC/seg/raw/us/old/US_cityleveldata.dta",
        )
    elif lower in {"us_dissim.xlsx", "us_edu.csv", "us_income.csv", "us_iso.xlsx", "uscityincome.dta", "usa_msa_dissim.xlsx"} and (
        rel_dir in {"raw/us/old", "old-2020/raw/us"}
    ):
        set_decision("raw_input", "high", parent_override="/dartfs/rc/lab/I/IEC/seg/raw/us/old/US_cityleveldata.dta")
    elif lower in {"msa-level-pop-2020.csv", "census-tract-pop-2020.csv"} and rel_dir == "raw/us":
        set_decision("raw_input", "high", parent_override="/dartfs/rc/lab/I/IEC/seg/clean/us/us_census_msa_dissim.dta")
    elif lower == "msa_key.csv" and rel_dir == "raw/us":
        set_decision("support_or_key", "high", parent_override="/dartfs/rc/lab/I/IEC/seg/clean/us/msa_keys.dta")
    elif lower in {"us_tract_pop.dta", "us_tpop_b.dta", "msa_tract_race_pop.dta"} and rel_dir == "clean/us":
        target = "/dartfs/rc/lab/I/IEC/seg/clean/us/us_census_msa_dissim.dta"
        set_decision("derived_complete", "high", parent_override=target)
    elif lower == "us_census_msa_dissim.dta" and rel_dir == "clean/us":
        set_decision("canonical_standalone", "high", parent_override=filename)
    elif lower == "2020_ua_blocks.csv" and rel_dir == "clean/us":
        set_decision("support_or_key", "high")
    elif rel_dir == "clean/us" and lower in {"brown_city_dissim_1980_2020.dta", "brown_msa_dissim_1980_2020.dta"}:
        set_decision("standalone_source", "medium", parent_override=filename)
    elif rel_dir == "clean/us" and re.fullmatch(r"brown_(?:30|100)_(?:city|msa)_dissim\.dta", lower):
        parent_kind = "city" if "_city_" in lower else "msa"
        set_decision(
            "derived_complete",
            "medium",
            parent_override=f"/dartfs/rc/lab/I/IEC/seg/clean/us/brown_{parent_kind}_dissim_1980_2020.dta",
        )
    elif rel_dir == "clean/us" and lower == "brown_avg_dissim_1980_2020.dta":
        set_decision("derived_complete", "medium", parent_override="/dartfs/rc/lab/I/IEC/seg/clean/us/brown_city_dissim_1980_2020.dta")
    elif rel_dir == "clean/ec" and re.fullmatch(r"ec(?:05|13|90|98)_appended\.dta", lower):
        set_decision("canonical_standalone", "medium", parent_override=filename)
    elif rel_dir == "clean/ec" and re.fullmatch(r"ec(?:05|13|90|98)_ed_health\.dta", lower):
        parent_name = lower.replace("_ed_health", "_appended")
        set_decision("derived_complete", "high", parent_override=f"/dartfs/rc/lab/I/IEC/seg/clean/ec/{parent_name}")
    elif rel_dir == "clean" and re.fullmatch(r"ec13_(?:rural|urban)_(?:city|block)\.dta", lower):
        set_decision("derived_complete", "high", parent_override="/dartfs/rc/lab/I/IEC/seg/clean/ec/ec13_appended.dta")
    elif lower in {"dissim_block_groups.dta", "dissim_iso_block_groups.dta"}:
        set_decision("derived_complete", "medium", parent_override="/dartfs/rc/lab/I/IEC/seg/clean/secc_ec_blockdata_urban.dta")
    elif rel_dir == "clean/ec/old" and "kerala_ed_health" in lower:
        parent_name = lower.replace("_kerala_ed_health", "_ed_health")
        set_decision("derived_complete", "medium", parent_override=f"/dartfs/rc/lab/I/IEC/seg/clean/ec/{parent_name}")
    elif re.search(r"_(?:10p|1p|slum)\.dta$", lower):
        set_decision("derived_complete", "high")
    elif re.search(r"_pooled_?\d+\.dta$", lower) or re.search(r"_(?:200|4000|10000)\.dta$", lower):
        set_decision("derived_complete", "high")
    elif old_decision == "derived" or complete_class == "derived":
        if not parent and direct_inputs:
            parent = direct_inputs[0]
        if parent:
            set_decision("derived_complete", "medium")
        else:
            set_decision("manual_review", "low", "Previously marked derived, but no parent was found in inventory or code lineage.")
    elif likely_legacy or old_decision == "legacy":
        if basename_counts.get(lower, 0) > 1 and linked and linked != filename:
            set_decision("excluded_bad_artifact", "medium", "Legacy duplicate of another inventory row.", linked)
        elif old_decision in {"canonical", "legacy"} or complete_class == "legacy":
            set_decision("legacy_standalone", "medium", parent_override=filename)
        else:
            set_decision("raw_input", "medium", parent_override=direct_outputs[0] if direct_outputs else linked)
    elif str(row.get("top_level_section", "")).lower() == "raw":
        if direct_outputs or linked:
            set_decision("raw_input", "high", parent_override=direct_outputs[0] if direct_outputs else linked)
        elif old_decision == "source" or complete_class == "source":
            set_decision("standalone_source", "medium", parent_override=filename)
        else:
            set_decision("raw_input", "medium", "Raw file with no downstream output found by scanner.")
    elif old_decision == "source" or complete_class == "source":
        set_decision("standalone_source", "medium", parent_override=filename)
    elif old_decision == "canonical":
        set_decision("canonical_standalone", "high", parent_override=filename)
    elif old_decision == "excluded":
        set_decision("excluded_bad_artifact", "medium", str(row.get("excluded_from_canonical_reason", "")))
    elif old_decision == "not_complete":
        set_decision("raw_input" if str(row.get("top_level_section", "")).lower() == "raw" else "manual_review", "medium")

    if final_class == "derived_complete" and not parent:
        parent = direct_inputs[0] if direct_inputs else linked

    primary = final_class in STANDALONE_CLASSES and not manual_reason
    if final_class == "legacy_standalone" and filename.startswith("/dartfs/rc/lab/I/IEC/seg/old-2020/"):
        primary = False

    if writer_script:
        evidence_parts.append(f"writer={writer_script}:{writer_line}".rstrip(":"))
    if reader_scripts:
        evidence_parts.append(f"read by {len(reader_scripts)} script(s)")
    if direct_outputs:
        evidence_parts.append(f"feeds {len(direct_outputs)} downstream file(s)")
    if final_class == "raw_input" and not direct_outputs:
        evidence_parts.append("no downstream output found by code scanner; classified from path/role evidence")
    if parent and parent != filename:
        evidence_parts.append(f"parent={parent}")
    if basename_counts.get(lower, 0) > 1:
        evidence_parts.append("duplicate basename present")
    if not evidence_parts:
        evidence_parts.append("classification based on workbook metadata")

    return {
        "final_inventory_class": final_class,
        "primary_standalone_flag": "TRUE" if primary else "FALSE",
        "family_id": family_id_for(row, parent),
        "unit_of_observation": infer_unit(row),
        "conceptual_object": infer_object(row),
        "canonical_parent_file": parent if parent else (filename if primary else ""),
        "lineage_inputs": semi(direct_inputs),
        "lineage_outputs": semi(direct_outputs),
        "writer_script": writer_script,
        "writer_line": writer_line,
        "reader_scripts": semi(reader_scripts),
        "used_in_analysis": "TRUE" if used_in_analysis else "FALSE",
        "evidence_summary": "; ".join(evidence_parts),
        "confidence": confidence,
        "manual_review_reason": manual_reason,
    }


def build_review() -> tuple[dict[str, pd.DataFrame], pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    sheets = read_base_sheets()
    all_files = sheets["all_files_with_master"].copy()
    old_standalone = set(sheets["standalone_datasets"]["filename"].astype(str))
    basename_counts = all_files["basename"].str.lower().value_counts().to_dict()

    events = parse_code_events()
    edges = build_edges(events)

    readers: dict[str, list[str]] = defaultdict(list)
    writers: dict[str, list[CodeEvent]] = defaultdict(list)
    for event in events:
        if event.access == "read":
            readers[event.dataset_file].append(f"{event.script}:{event.line}")
        elif event.access == "write":
            writers[event.dataset_file].append(event)

    inputs_by_target: dict[str, list[str]] = defaultdict(list)
    outputs_by_source: dict[str, list[str]] = defaultdict(list)
    for _, edge in edges.iterrows():
        inputs_by_target[str(edge["target_file"])].append(str(edge["source_file"]))
        outputs_by_source[str(edge["source_file"])].append(str(edge["target_file"]))

    review_records = [
        classify_row(row, old_standalone, inputs_by_target, outputs_by_source, readers, writers, basename_counts)
        for _, row in all_files.iterrows()
    ]
    review_df = pd.DataFrame(review_records)
    base_all = all_files.drop(columns=[col for col in FINAL_COLUMNS if col in all_files.columns], errors="ignore")
    enriched_all = pd.concat([base_all.reset_index(drop=True), review_df], axis=1)

    enriched_by_file = enriched_all.set_index("filename")[FINAL_COLUMNS]
    reviewed_sheets: dict[str, pd.DataFrame] = {}
    for sheet_name, df in sheets.items():
        if "filename" in df.columns and sheet_name != "all_files_with_master":
            df_base = df.drop(columns=[col for col in FINAL_COLUMNS if col in df.columns], errors="ignore")
            extra = df["filename"].map(lambda f: enriched_by_file.loc[f].to_dict() if f in enriched_by_file.index else {})
            extra_df = pd.DataFrame(list(extra))
            reviewed_sheets[sheet_name] = pd.concat([df_base.reset_index(drop=True), extra_df.reset_index(drop=True)], axis=1)
        elif sheet_name == "all_files_with_master":
            reviewed_sheets[sheet_name] = enriched_all
        else:
            reviewed_sheets[sheet_name] = df

    final_standalone = (
        enriched_all.loc[enriched_all["primary_standalone_flag"].eq("TRUE")]
        .sort_values(["final_inventory_class", "family_id", "filename"])
        .reset_index(drop=True)
    )
    manual_queue = (
        enriched_all.loc[
            enriched_all["confidence"].eq("low")
            | enriched_all["manual_review_reason"].astype(str).str.strip().ne("")
            | enriched_all["final_inventory_class"].eq("manual_review")
        ]
        .sort_values(["final_inventory_class", "relative_dir", "basename", "filename"])
        .reset_index(drop=True)
    )
    old_class = enriched_all["inventory_decision"].map(old_decision_to_final_class).fillna(enriched_all["inventory_decision"])
    changes_mask = old_class.ne(enriched_all["final_inventory_class"]) | (
        enriched_all["filename"].isin(old_standalone) & enriched_all["primary_standalone_flag"].ne("TRUE")
    )
    decision_changes = enriched_all.loc[changes_mask].copy()
    decision_changes.insert(0, "old_standalone_flag", decision_changes["filename"].isin(old_standalone).map({True: "TRUE", False: "FALSE"}))
    decision_changes.insert(1, "old_mapped_class", old_class.loc[changes_mask].values)
    decision_changes = decision_changes.sort_values(["old_standalone_flag", "final_inventory_class", "relative_dir", "basename"])

    dataset_nodes = build_dataset_nodes(enriched_all, events)

    reviewed_sheets["final_standalone_datasets"] = final_standalone
    reviewed_sheets["manual_review_queue"] = manual_queue
    reviewed_sheets["decision_changes"] = decision_changes
    return reviewed_sheets, edges, dataset_nodes, decision_changes, manual_queue


def old_decision_to_final_class(value: str) -> str:
    return {
        "canonical": "canonical_standalone",
        "source": "standalone_source",
        "legacy": "legacy_standalone",
        "derived": "derived_complete",
        "excluded": "excluded_bad_artifact",
        "not_complete": "manual_review",
    }.get(str(value), str(value))


def build_dataset_nodes(enriched_all: pd.DataFrame, events: list[CodeEvent]) -> pd.DataFrame:
    records: dict[str, dict[str, object]] = {}
    for _, row in enriched_all.iterrows():
        records[str(row["filename"])] = {
            "dataset_file": row["filename"],
            "in_inventory": "TRUE",
            "final_inventory_class": row["final_inventory_class"],
            "primary_standalone_flag": row["primary_standalone_flag"],
            "family_id": row["family_id"],
            "conceptual_object": row["conceptual_object"],
            "unit_of_observation": row["unit_of_observation"],
            "confidence": row["confidence"],
        }
    for event in events:
        records.setdefault(
            event.dataset_file,
            {
                "dataset_file": event.dataset_file,
                "in_inventory": "FALSE",
                "final_inventory_class": "",
                "primary_standalone_flag": "FALSE",
                "family_id": Path(event.dataset_file).stem.lower(),
                "conceptual_object": "",
                "unit_of_observation": "",
                "confidence": "",
            },
        )
    return pd.DataFrame(records.values()).sort_values(["in_inventory", "dataset_file"], ascending=[False, True])


def validate_outputs(sheets: dict[str, pd.DataFrame]) -> list[str]:
    errors: list[str] = []
    final = sheets["final_standalone_datasets"]
    bad_final = final.loc[final["final_inventory_class"].isin(NON_FINAL_STANDALONE_CLASSES)]
    if not bad_final.empty:
        errors.append(f"{len(bad_final)} final standalone rows have non-standalone classes.")
    all_files = sheets["all_files_with_master"]
    derived_missing = all_files.loc[
        all_files["final_inventory_class"].eq("derived_complete")
        & all_files["canonical_parent_file"].astype(str).str.strip().eq("")
    ]
    if not derived_missing.empty:
        errors.append(f"{len(derived_missing)} derived_complete rows are missing canonical_parent_file.")
    raw_missing = all_files.loc[
        all_files["final_inventory_class"].eq("raw_input")
        & all_files["lineage_outputs"].astype(str).str.strip().eq("")
        & all_files["manual_review_reason"].astype(str).str.strip().eq("")
        & ~all_files["evidence_summary"].astype(str).str.contains("no downstream output found", case=False, na=False)
    ]
    if not raw_missing.empty:
        errors.append(f"{len(raw_missing)} raw_input rows lack downstream output and explanatory note.")
    primary_missing = final.loc[
        final[["conceptual_object", "unit_of_observation", "evidence_summary", "confidence"]]
        .astype(str)
        .apply(lambda col: col.str.strip().eq(""))
        .any(axis=1)
    ]
    if not primary_missing.empty:
        errors.append(f"{len(primary_missing)} primary standalone rows are missing required descriptive fields.")
    return errors


def write_memo(sheets: dict[str, pd.DataFrame], validation_errors: list[str]) -> None:
    all_files = sheets["all_files_with_master"]
    final = sheets["final_standalone_datasets"]
    changes = sheets["decision_changes"]
    manual = sheets["manual_review_queue"]
    old_standalone_removed = changes.loc[
        changes["old_standalone_flag"].eq("TRUE") & changes["primary_standalone_flag"].ne("TRUE")
    ]
    class_counts = final["final_inventory_class"].value_counts().to_dict()
    removed_examples = old_standalone_removed[
        ["filename", "final_inventory_class", "evidence_summary", "manual_review_reason"]
    ].head(20)
    manual_examples = manual[["filename", "final_inventory_class", "manual_review_reason", "evidence_summary"]].head(20)

    lines = [
        "# Standalone Dataset Inventory Review",
        "",
        "## Definition Used",
        "A final standalone dataset is a complete dataset that captures a distinct conceptual object and is not a raw input, support key, partition, threshold variant, subsample, deterministic derivative, intermediate output, or duplicate archive copy.",
        "",
        "Complete external comparison/source datasets are retained as `standalone_source` only when code evidence does not show them being collapsed into a cleaner final dataset. Complete archive datasets are retained as `legacy_standalone` only when they are distinct family representatives.",
        "",
        "## Final Counts",
        f"- Final standalone datasets: {len(final)}",
        f"- Class counts: {class_counts}",
        f"- Manual review queue rows: {len(manual)}",
        f"- Decision change rows: {len(changes)}",
        "",
        "## Major Rows Removed From Old Standalone",
    ]
    if removed_examples.empty:
        lines.append("- No old standalone rows were reclassified out of primary standalone.")
    else:
        for _, row in removed_examples.iterrows():
            reason = row["manual_review_reason"] or row["evidence_summary"]
            lines.append(f"- `{row['filename']}` -> `{row['final_inventory_class']}`: {reason}")
    lines.extend(["", "## Ambiguous Rows Needing Review"])
    if manual_examples.empty:
        lines.append("- No low-confidence or contradictory rows were added to the manual review queue.")
    else:
        for _, row in manual_examples.iterrows():
            reason = row["manual_review_reason"] or row["evidence_summary"]
            lines.append(f"- `{row['filename']}` -> `{row['final_inventory_class']}`: {reason}")
    lines.extend(
        [
            "",
            "## Immediate Row Decisions",
            "- `pc11_pdf_shrid_dissim.dta` and `pc01_pdf_shrid_dissim.dta`: `derived_complete`, produced by `gen_dissim_pc0111.do` from handbook inputs.",
            "- `msa-level-pop-2020.csv`: `raw_input`, used in the US census MSA build.",
            "- `msa_keys.dta`: `support_or_key`, a clean MSA key used for merges.",
            "- `us_tract_pop.dta`: `derived_complete`, an intermediate tract-population clean file feeding later US MSA outputs.",
            "- `append_hb_test.csv`: `excluded_bad_artifact`, a test artifact.",
            "- `raw/us/old/US_cityleveldata.dta`: `legacy_standalone`, retained as the old US city-level family representative.",
            "- `clean/pc11/pc11_muslims_rural.dta` and `clean/pc11/pc11_muslims_urban.dta`: `canonical_standalone`, retained as primary PC11 Muslim-share masters.",
            "",
            "## Code-Lineage Limitations",
            "- Stata local macro interpolation such as `` `loc' `` is not fully expanded; those lines are supplemented by existing inventory creator metadata and AI-summary comments when present.",
            "- The lineage graph is script-level and conservative: it links reads before writes within a script, so some complex do-files may contain broad upstream edges.",
            "- Path aliases are resolved for the common segdata macros `$seg`, `$sdata`, `$tmp`, `$raw`, `$out`, and `$shrug`; unusual project-specific aliases remain unresolved and can enter the manual review queue.",
            "",
            "## Validation",
        ]
    )
    if validation_errors:
        lines.extend(f"- FAILED: {err}" for err in validation_errors)
    else:
        lines.append("- Passed all requested validation checks.")
    lines.append("")
    lines.append(f"Reviewed inventory rows classified: {len(all_files)}.")
    (NOTE_OUT_DIR / "standalone_inventory_notes.md").write_text("\n".join(lines))


def main() -> None:
    NOTE_OUT_DIR.mkdir(parents=True, exist_ok=True)
    DATA_OUT_DIR.mkdir(parents=True, exist_ok=True)
    sheets, edges, dataset_nodes, decision_changes, manual_queue = build_review()
    validation_errors = validate_outputs(sheets)
    if validation_errors:
        raise SystemExit("; ".join(validation_errors))

    edges.to_csv(DATA_OUT_DIR / "lineage_edges.csv", index=False, quoting=csv.QUOTE_MINIMAL)
    dataset_nodes.to_csv(DATA_OUT_DIR / "dataset_nodes.csv", index=False)
    decision_changes.to_csv(DATA_OUT_DIR / "decision_changes.csv", index=False)
    manual_queue.to_csv(DATA_OUT_DIR / "manual_review_queue.csv", index=False)
    write_memo(sheets, validation_errors)

    write_xlsx = load_write_xlsx()
    sheet_order = [
        "all_files_with_master",
        "standalone_datasets",
        "canonical_complete_datasets",
        "derived_complete_datasets",
        "source_complete_datasets",
        "legacy_complete_datasets",
        "excluded_complete_candidates",
        "column_guide",
        "final_standalone_datasets",
        "manual_review_queue",
        "decision_changes",
    ]
    write_xlsx(DATA_OUT_DIR / "seg_dataset_inventory_reviewed.xlsx", [(name, sheets[name]) for name in sheet_order])
    print(f"Wrote {DATA_OUT_DIR / 'seg_dataset_inventory_reviewed.xlsx'}")
    print(f"Final standalone datasets: {len(sheets['final_standalone_datasets'])}")
    print(f"Manual review queue: {len(sheets['manual_review_queue'])}")
    print(f"Decision changes: {len(sheets['decision_changes'])}")


if __name__ == "__main__":
    main()
