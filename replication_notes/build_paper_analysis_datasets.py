#!/usr/bin/env python3
"""
Build a manifest of datasets used by the active paper analysis stage.

The output is intentionally narrower than raw_datasets.csv: it lists the
datasets consumed by active analysis scripts, plus analysis-stage handoff files
that are produced and consumed within the paper-results chain.
"""

from __future__ import annotations

import csv
import os
import re
from collections import defaultdict
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

import pandas as pd


REPO_ROOT = Path(__file__).resolve().parents[1]
NOTES_DIR = REPO_ROOT / "replication_notes"
OUTPUT_DIR = Path(
    os.environ.get("REPLICATION_DATASET_MANIFEST_DIR", "/tmp/paper-india-segregation")
)
OUTPUT = OUTPUT_DIR / "paper_analysis_datasets.csv"
FLAGS_OUTPUT = OUTPUT_DIR / "dataset_replication_flags.csv"
CLEAN_ROOT = "/dartfs/rc/lab/I/IEC/seg/clean"
IEC_ROOT = "/dartfs/rc/lab/I"
SEG_ROOT = "/dartfs/rc/lab/I/IEC/seg"

COLUMNS = [
    "basename",
    "dataset_path",
    "absolute_dataset_path",
    "clean_equivalent_path",
    "dataset_root",
    "dataset_stage",
    "analysis_handoff",
    "required_before_analysis",
    "creator_script",
    "producer_script",
    "consumer_scripts",
    "first_used_by",
    "original_pattern",
    "source_manifest",
    "notes",
]

FLAGS_COLUMNS = [
    "basename",
    "dataset_path",
    "absolute_dataset_path",
    "clean_equivalent_path",
    "dataset_root",
    "needed_replication",
    "dataset_stage",
    "analysis_handoff",
    "required_before_analysis",
    "creator_script",
    "producer_script",
    "consumer_scripts",
    "first_used_by",
    "original_pattern",
    "source_manifest",
    "notes",
]

DO_READ_PATTERNS = [
    re.compile(r"\buse\b.+?\busing\s+([^,\s]+)", re.I),
    re.compile(r"\buse\s+([^,\s]+)", re.I),
    re.compile(r"\bmerge\b.+?\busing\s+([^,\s]+)", re.I),
    re.compile(r"\bappend\s+using\s+([^,\s]+)", re.I),
    re.compile(r"\bimport\s+delimited(?:\s+using)?\s+([^,\s]+)", re.I),
    re.compile(r"\bimport\s+excel(?:\s+using)?\s+([^,\s]+)", re.I),
    re.compile(r"\binsheet(?:\s+using)?\s+([^,\s]+)", re.I),
]

STATA_MACRO_ASSIGN_PATTERN = re.compile(
    r"^\s*(?P<kind>global|local)\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s+(?P<value>[^\s,]+)",
    re.I,
)

PY_READ_PATTERNS = [
    re.compile(r"^\s*(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?P<root>RAW|TMP|OUT)\s*/\s*(?P<expr>.+)$"),
    re.compile(r"^\s*(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?P<root>OUT)\s*$"),
]

KNOWN_LOCAL_TMP = {
    "$tmp/pc11_town_vars",
    "$tmp/seg_urban_repres_reweighted",
    "$tmp/shrid_town_key",
    "$tmp/shrug_rural_seg_key",
    "$tmp/seg_rural_repres",
    "$tmp/seg_urban_repres",
    "$tmp/pre_collapse",
    "$tmp/pc01_hb_town",
    "$tmp/pc01_pca_town",
    "$tmp/seg_pc01_secc",
    "$tmp/seg_wt",
    "$tmp/urban_temp",
    "$tmp/tpop_m",
    "$tmp/tpop_sc",
    "$tmp/tpop_m_urban",
    "$tmp/tpop_sc_urban",
    "$tmp/tpop_m_rural",
    "$tmp/tpop_sc_rural",
}

COMMENT_FALSE_POSITIVES = {
    "the",
    "data",
    "clean",
    "in",
    "urban",
    "200",
    "pc11_shrid",
    "non-rescaled",
}

SUPPLIED_RAW_NOTE = (
    "No creator script found in segregation/b; treated as supplied raw input."
)


@dataclass
class ManifestRow:
    dataset_path: str
    dataset_root: str
    dataset_stage: str
    required_before_analysis: str
    producer_script: str
    consumer_scripts: str
    first_used_by: str
    original_pattern: str
    source_manifest: str
    notes: str = ""


def read_csv(name: str) -> pd.DataFrame:
    return pd.read_csv(NOTES_DIR / name, dtype=str).fillna("")


def active_scripts() -> set[str]:
    run_order = read_csv("run_order.csv")
    return set(
        run_order.loc[run_order["in_replication_make"].eq("yes"), "script_path"].tolist()
    )


def active_analysis_scripts(active: set[str]) -> set[str]:
    return {script for script in active if script.startswith("a/")}


def split_scripts(value: str) -> list[str]:
    return [part.strip() for part in value.split(";") if part.strip()]


def contains_active_analysis_script(value: str, analysis_scripts: set[str]) -> bool:
    return any(script in analysis_scripts for script in split_scripts(value))


def expand_braces(pattern: str) -> list[str]:
    match = re.search(r"\{([^{}]+)\}", pattern)
    if not match:
        return [pattern]
    choices = match.group(1).split("|")
    expanded = []
    for choice in choices:
        expanded.extend(expand_braces(pattern[: match.start()] + choice + pattern[match.end() :]))
    return expanded


def add_dta_suffix(path: str) -> str:
    if path.startswith(("RAW/", "TMP/", "OUT/")) and "." not in Path(path).name:
        return f"{path}.dta"
    return path


def expand_stata_macros(token: str) -> list[str]:
    token = token.strip()
    if "`" not in token:
        return [token]
    if "pc11`d'_social_group" in token:
        return [token.replace("`d'", value) for value in ["r_subdistrict", "u_town"]]
    if "pc11`d'_pca_clean" in token:
        return [token.replace("`d'", value) for value in ["r", "u"]]

    expanded = [token]
    for macro, values in [
        ("`loc'", ["urban", "rural"]),
        ("`bgroup'", ["200", "4000"]),
        ("`nbd'", ["200", "4000"]),
    ]:
        next_expanded: list[str] = []
        for item in expanded:
            if macro not in item:
                next_expanded.append(item)
                continue
            next_expanded.extend(item.replace(macro, value) for value in values)
        expanded = next_expanded
    return [] if any("`" in item for item in expanded) else expanded


def normalize_stata_token(token: str) -> str | None:
    token = token.strip().strip('"').strip("'").rstrip(",);]")
    token = token.lstrip("([")
    if not token or "`" in token:
        return None
    if token in COMMENT_FALSE_POSITIVES or token in KNOWN_LOCAL_TMP:
        return None
    replacements = {
        "$tmp": "TMP",
        "${tmp}": "TMP",
        "$raw": "RAW",
        "${raw}": "RAW",
        "$seg": "RAW",
        "${seg}": "RAW",
        "$sdata": "RAW",
        "${sdata}": "RAW",
        "$shrug": "RAW/shrug",
        "${shrug}": "RAW/shrug",
        "$pc11": "RAW/pc11",
        "${pc11}": "RAW/pc11",
        "$pc01": "RAW/pc01",
        "${pc01}": "RAW/pc01",
        "$mobility": "RAW/mobility",
        "${mobility}": "RAW/mobility",
        "$out": "OUT",
        "${out}": "OUT",
    }
    for old, new in replacements.items():
        if token.startswith(old):
            token = new + token[len(old) :]
            break
    else:
        return None
    return add_dta_suffix(token)


def store_stata_path_macro(line: str, macros: dict[str, str]) -> None:
    match = STATA_MACRO_ASSIGN_PATTERN.match(line)
    if not match:
        return
    value = match.group("value").strip().strip('"').strip("'").rstrip(",);]")
    if normalize_stata_token(value) is None:
        return

    name = match.group("name")
    if match.group("kind").lower() == "global":
        macros[f"${name}"] = value
        macros[f"${{{name}}}"] = value
    else:
        macros[f"`{name}'"] = value


def resolve_stata_path_macro(token: str, macros: dict[str, str]) -> str:
    stripped = token.strip().strip('"').strip("'").rstrip(",);]")
    return macros.get(stripped, token)


def normalize_manifest_path(path: str) -> str:
    return add_dta_suffix(path.strip())


def root_for(path: str) -> str:
    return path.split("/", 1)[0] if "/" in path else path


def path_sort_key(path: str) -> tuple[int, str]:
    root_order = {"RAW": 0, "TMP": 1, "OUT": 2}
    return (root_order.get(root_for(path), 9), path)


def row_to_dict(row: ManifestRow) -> dict[str, str]:
    values = {
        column: getattr(row, column)
        for column in COLUMNS
        if column
        not in {
            "analysis_handoff",
            "basename",
            "absolute_dataset_path",
            "clean_equivalent_path",
            "creator_script",
            "notes",
        }
    }
    values["basename"] = Path(row.dataset_path).name
    values["absolute_dataset_path"] = absolute_dataset_path(row.dataset_path)
    values["clean_equivalent_path"] = clean_equivalent_path(row.dataset_path)
    values["creator_script"] = row.producer_script
    values["analysis_handoff"] = (
        "1" if row.dataset_stage == "analysis_generated_handoff" else "0"
    )
    values["notes"] = notes_for_output(row)
    return values


def flag_row_to_dict(row: ManifestRow, needed_paths: set[str]) -> dict[str, str]:
    return {
        "basename": Path(row.dataset_path).name,
        "dataset_path": row.dataset_path,
        "absolute_dataset_path": absolute_dataset_path(row.dataset_path),
        "clean_equivalent_path": clean_equivalent_path(row.dataset_path),
        "dataset_root": row.dataset_root,
        "needed_replication": "1" if row.dataset_path in needed_paths else "0",
        "dataset_stage": row.dataset_stage,
        "analysis_handoff": "1"
        if row.dataset_stage == "analysis_generated_handoff"
        else "0",
        "required_before_analysis": row.required_before_analysis,
        "creator_script": row.producer_script,
        "producer_script": row.producer_script,
        "consumer_scripts": row.consumer_scripts,
        "first_used_by": row.first_used_by,
        "original_pattern": row.original_pattern,
        "source_manifest": row.source_manifest,
        "notes": notes_for_output(row),
    }


def notes_for_output(row: ManifestRow) -> str:
    notes = row.notes
    if row.dataset_root == "RAW" and not row.producer_script:
        if not notes:
            return SUPPLIED_RAW_NOTE
        if SUPPLIED_RAW_NOTE not in notes:
            return f"{notes} {SUPPLIED_RAW_NOTE}"
    return notes


def clean_equivalent_path(dataset_path: str) -> str:
    basename = Path(dataset_path).name
    if dataset_path.startswith("TMP/handbooks/pc") and dataset_path.endswith("_pdf_shrid_dissim.dta"):
        return f"{CLEAN_ROOT}/handbooks/{basename}"
    if dataset_path == "TMP/segregation_pc0111.dta":
        return f"{CLEAN_ROOT}/segregation_pc0111.dta"
    if dataset_path.startswith("TMP/city_seg_district_rural_urban_"):
        return f"{CLEAN_ROOT}/{basename}"
    if dataset_path.startswith("TMP/pc11/pc11_muslims_"):
        return f"{CLEAN_ROOT}/pc11/{basename}"
    if dataset_path.startswith("TMP/secc/segregation_blockdata_"):
        return f"{CLEAN_ROOT}/{basename}"
    if dataset_path.startswith("TMP/secc/segregation_citydata_"):
        return f"{CLEAN_ROOT}/{basename}"
    if dataset_path.startswith("TMP/us/"):
        return f"{CLEAN_ROOT}/us/{basename}"
    return ""


@lru_cache(maxsize=1)
def raw_source_lookup() -> dict[str, str]:
    lookup: dict[str, str] = {}
    raw = read_csv("raw_datasets.csv")
    for record in raw.to_dict("records"):
        targets = expand_braces(record["target_path"])
        sources = expand_braces(record["current_path"])
        if len(sources) != len(targets):
            continue
        for target, source in zip(targets, sources):
            lookup[normalize_manifest_path(target)] = source
    return lookup


def source_to_absolute_path(source: str) -> str:
    if not source:
        return ""
    if source.startswith("IEC/"):
        return f"{IEC_ROOT}/{source}"
    if source.startswith("/"):
        return source
    if source.startswith("http"):
        return source
    return ""


def direct_iec_seg_path(dataset_path: str) -> str:
    direct_paths = {
        "TMP/dissim_iso_block_groups.dta": f"{SEG_ROOT}/dissim_iso_block_groups.dta",
    }
    if dataset_path in direct_paths:
        return direct_paths[dataset_path]
    return ""


def absolute_dataset_path(dataset_path: str) -> str:
    clean_path = clean_equivalent_path(dataset_path)
    if clean_path:
        return clean_path
    direct_path = direct_iec_seg_path(dataset_path)
    if direct_path:
        return direct_path
    if dataset_path.startswith("RAW/"):
        return source_to_absolute_path(raw_source_lookup().get(dataset_path, ""))
    return ""


def parse_do_reads(analysis_scripts: set[str]) -> dict[str, set[str]]:
    consumers: dict[str, set[str]] = defaultdict(set)
    for script in sorted(analysis_scripts):
        path = REPO_ROOT / script
        if path.suffix.lower() != ".do" or not path.exists():
            continue
        script_macros: dict[str, str] = {}
        in_block_comment = False
        for raw_line in path.read_text(errors="ignore").splitlines():
            line = raw_line
            if "/*" in line:
                before, _, after = line.partition("/*")
                if "*/" in after:
                    _, _, after_comment = after.partition("*/")
                    line = before + " " + after_comment
                else:
                    line = before
                    in_block_comment = True
            elif in_block_comment:
                if "*/" in line:
                    _, _, line = line.partition("*/")
                    in_block_comment = False
                else:
                    continue
            stripped = line.strip()
            if not stripped or stripped.startswith(("*", "//")):
                continue
            store_stata_path_macro(stripped, script_macros)
            for pattern in DO_READ_PATTERNS:
                match = pattern.search(line)
                if not match:
                    continue
                resolved = resolve_stata_path_macro(match.group(1), script_macros)
                for token in expand_stata_macros(resolved):
                    normalized = normalize_stata_token(token)
                    if normalized:
                        for expanded in expand_braces(normalized):
                            consumers[expanded].add(script)
    return consumers


def parse_python_reads(analysis_scripts: set[str]) -> dict[str, set[str]]:
    consumers: dict[str, set[str]] = defaultdict(set)
    for script in sorted(analysis_scripts):
        path = REPO_ROOT / script
        if path.suffix.lower() != ".py" or not path.exists():
            continue
        constants: dict[str, str] = {}
        for line in path.read_text(errors="ignore").splitlines():
            match = next(
                (pattern.match(line) for pattern in PY_READ_PATTERNS if pattern.match(line)),
                None,
            )
            if not match:
                continue
            name = match.group("name")
            root = match.group("root")
            expr = match.groupdict().get("expr")
            if not expr:
                constants[name] = root
                continue
            parts = [part.strip() for part in expr.split("/")]
            literal_parts: list[str] = []
            for part in parts:
                quoted = re.fullmatch(r'"([^"]+)"|\'([^\']+)\'', part)
                if not quoted:
                    literal_parts = []
                    break
                literal_parts.append(quoted.group(1) or quoted.group(2))
            if literal_parts:
                constants[name] = "/".join([root, *literal_parts])

        text = path.read_text(errors="ignore")
        for name, dataset_path in constants.items():
            if root_for(dataset_path) == "OUT":
                continue
            if re.search(rf"\bread_(?:csv|stata|file)\s*\(\s*{re.escape(name)}\b", text):
                consumers[dataset_path].add(script)
        if script == "a/seg_maps.py":
            for shp in [
                "RAW/gis/pc11-district.shp",
                "RAW/gis/pc11-subdistrict.shp",
                "RAW/gis/pc11-state.shp",
            ]:
                consumers[shp].add(script)
    return consumers


def merge_consumers(*sources: dict[str, set[str]]) -> dict[str, set[str]]:
    merged: dict[str, set[str]] = defaultdict(set)
    for source in sources:
        for dataset_path, scripts in source.items():
            merged[dataset_path].update(scripts)
    return merged


def intermediate_producer_lookup() -> dict[str, str]:
    lookup: dict[str, str] = {}
    inter = read_csv("intermediate_datasets.csv")
    for record in inter.to_dict("records"):
        pattern = record["tmp_path_or_pattern"]
        if "*" in pattern:
            continue
        for expanded in expand_braces(pattern):
            lookup[normalize_manifest_path(expanded)] = record["produced_by"]
    return lookup


def build_rows() -> list[ManifestRow]:
    active = active_scripts()
    analysis_scripts = active_analysis_scripts(active)
    do_consumers = parse_do_reads(analysis_scripts)
    python_consumers = parse_python_reads(analysis_scripts)
    parsed_consumers = merge_consumers(do_consumers, python_consumers)
    producer_lookup = intermediate_producer_lookup()

    rows: dict[str, ManifestRow] = {}

    raw = read_csv("raw_datasets.csv")
    for record in raw.to_dict("records"):
        first_used_by = record["first_used_by"]
        if first_used_by not in analysis_scripts:
            continue
        for expanded in expand_braces(record["target_path"]):
            dataset_path = normalize_manifest_path(expanded)
            consumers = parsed_consumers.get(dataset_path, {first_used_by})
            ordered_consumers = sorted(consumers)
            rows[dataset_path] = ManifestRow(
                dataset_path=dataset_path,
                dataset_root=root_for(dataset_path),
                dataset_stage="raw_analysis_input",
                required_before_analysis="TRUE",
                producer_script="",
                consumer_scripts=";".join(ordered_consumers),
                first_used_by=first_used_by if first_used_by in consumers else ordered_consumers[0],
                original_pattern=record["target_path"],
                source_manifest="raw_datasets.csv",
            )

    inter = read_csv("intermediate_datasets.csv")
    for record in inter.to_dict("records"):
        consumed_by = record["consumed_by"]
        producer = record["produced_by"]
        is_analysis_input = contains_active_analysis_script(consumed_by, analysis_scripts)
        is_analysis_handoff = producer.startswith("a/") and (
            is_analysis_input
            or consumed_by == "tex tables via out/*.tex"
            or record["tmp_path_or_pattern"].startswith("TMP/a/tables/")
        )
        if not (is_analysis_input or is_analysis_handoff):
            continue
        for expanded in expand_braces(record["tmp_path_or_pattern"]):
            if "*" in expanded:
                dataset_paths = [expanded]
            else:
                dataset_paths = [normalize_manifest_path(expanded)]
            for dataset_path in dataset_paths:
                consumers = parsed_consumers.get(dataset_path)
                if consumers is None:
                    consumers = set(split_scripts(consumed_by)) & analysis_scripts
                if not consumers and consumed_by == "tex tables via out/*.tex":
                    consumers = {"tex/segregation.tex"}
                stage = (
                    "generated_analysis_input"
                    if not producer.startswith("a/")
                    else "analysis_generated_handoff"
                )
                rows[dataset_path] = ManifestRow(
                    dataset_path=dataset_path,
                    dataset_root=root_for(dataset_path),
                    dataset_stage=stage,
                    required_before_analysis="TRUE" if stage == "generated_analysis_input" else "FALSE",
                    producer_script=producer,
                    consumer_scripts=";".join(sorted(consumers)),
                    first_used_by=sorted(consumers)[0] if consumers else "",
                    original_pattern=record["tmp_path_or_pattern"],
                    source_manifest="intermediate_datasets.csv",
                    notes="Produced during analysis and consumed later."
                    if stage == "analysis_generated_handoff"
                    else "",
                )

    for dataset_path, consumers in parsed_consumers.items():
        if root_for(dataset_path) not in {"RAW", "TMP"}:
            continue
        if dataset_path in rows:
            existing = rows[dataset_path]
            merged = sorted(set(split_scripts(existing.consumer_scripts)) | consumers)
            existing.consumer_scripts = ";".join(merged)
            existing.first_used_by = existing.first_used_by or merged[0]
            continue
        stage = "raw_analysis_input" if root_for(dataset_path) == "RAW" else "generated_analysis_input"
        producer = producer_lookup.get(dataset_path, "")
        rows[dataset_path] = ManifestRow(
            dataset_path=dataset_path,
            dataset_root=root_for(dataset_path),
            dataset_stage=stage,
            required_before_analysis="TRUE",
            producer_script=producer,
            consumer_scripts=";".join(sorted(consumers)),
            first_used_by=sorted(consumers)[0],
            original_pattern=dataset_path,
            source_manifest="static_parse",
            notes="Added from direct read in active analysis code.",
        )

    return sorted(rows.values(), key=lambda row: path_sort_key(row.dataset_path))


def build_flag_rows(paper_rows: list[ManifestRow]) -> list[ManifestRow]:
    rows: dict[str, ManifestRow] = {row.dataset_path: row for row in paper_rows}

    raw = read_csv("raw_datasets.csv")
    for record in raw.to_dict("records"):
        for expanded in expand_braces(record["target_path"]):
            dataset_path = normalize_manifest_path(expanded)
            rows.setdefault(
                dataset_path,
                ManifestRow(
                    dataset_path=dataset_path,
                    dataset_root=root_for(dataset_path),
                    dataset_stage="raw_manifest_not_needed_for_analysis",
                    required_before_analysis="FALSE",
                    producer_script="",
                    consumer_scripts="",
                    first_used_by=record["first_used_by"],
                    original_pattern=record["target_path"],
                    source_manifest="raw_datasets.csv",
                    notes="Not directly used by the active paper analysis replication set.",
                ),
            )

    inter = read_csv("intermediate_datasets.csv")
    for record in inter.to_dict("records"):
        for expanded in expand_braces(record["tmp_path_or_pattern"]):
            dataset_path = expanded if "*" in expanded else normalize_manifest_path(expanded)
            rows.setdefault(
                dataset_path,
                ManifestRow(
                    dataset_path=dataset_path,
                    dataset_root=root_for(dataset_path),
                    dataset_stage="intermediate_manifest_not_needed_for_analysis",
                    required_before_analysis="FALSE",
                    producer_script=record["produced_by"],
                    consumer_scripts=record["consumed_by"],
                    first_used_by="",
                    original_pattern=record["tmp_path_or_pattern"],
                    source_manifest="intermediate_datasets.csv",
                    notes="Not directly used by the active paper analysis replication set.",
                ),
            )

    return sorted(rows.values(), key=lambda row: path_sort_key(row.dataset_path))


def validate(rows: list[ManifestRow]) -> None:
    dataset_paths = [row.dataset_path for row in rows]
    duplicates = sorted({path for path in dataset_paths if dataset_paths.count(path) > 1})
    if duplicates:
        raise RuntimeError(f"Duplicate dataset_path rows: {duplicates}")
    if any("b/gen_ec_all_village.do" in row.producer_script for row in rows):
        raise RuntimeError("Inactive gen_ec_all_village.do producer leaked into manifest.")
    if any(row.first_used_by == "b/gen_ec_all_village.do" for row in rows):
        raise RuntimeError("Inactive gen_ec_all_village.do consumer leaked into manifest.")


def write_rows(rows: list[ManifestRow]) -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=COLUMNS)
        writer.writeheader()
        for row in rows:
            writer.writerow(row_to_dict(row))


def write_flag_rows(rows: list[ManifestRow], needed_paths: set[str]) -> None:
    FLAGS_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with FLAGS_OUTPUT.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=FLAGS_COLUMNS)
        writer.writeheader()
        for row in rows:
            writer.writerow(flag_row_to_dict(row, needed_paths))


def main() -> None:
    all_rows = build_rows()
    validate(all_rows)
    paper_rows = [
        row
        for row in all_rows
        if row.dataset_stage != "analysis_generated_handoff"
    ]
    write_rows(paper_rows)
    flag_rows = build_flag_rows(all_rows)
    write_flag_rows(flag_rows, {row.dataset_path for row in paper_rows})
    print(f"Wrote {len(paper_rows)} rows to {OUTPUT}")
    print(f"Wrote {len(flag_rows)} rows to {FLAGS_OUTPUT}")


if __name__ == "__main__":
    main()
