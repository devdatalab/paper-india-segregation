#!/usr/bin/env python3
from __future__ import annotations

import re
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

from variable_listing_utils import read_xlsx, write_csv_mirrors, write_xlsx


ROOT = Path(__file__).resolve().parents[1]
INVENTORY_DIR = ROOT / "inventory"
WORKBOOK_PATH = INVENTORY_DIR / "variable_listing.xlsx"
CSV_DIR = INVENTORY_DIR / "variable_listing_csv"

CONFLICT_COLUMNS = [
    "variable_name",
    "datasets_involved",
    "conflict_type",
    "evidence",
    "proposed_change",
    "risk_note",
]

CONFLICT_ORDER = ["coding", "naming", "label", "conceptual", "derivable"]
SPECIAL_VARIABLES = {
    "__file__",
    "__missing_file__",
    "__unsupported_file__",
    "__load_error__",
}


def normalize_text(value: object) -> str:
    text = str(value or "").lower()
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def normalize_code(value: str) -> str:
    text = str(value).strip()
    try:
        number = float(text)
    except ValueError:
        return text
    if number.is_integer():
        return str(int(number))
    return f"{number:.12g}"


def parse_value_labels(value_labels: str) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for raw_pair in str(value_labels or "").split(";"):
        pair = raw_pair.strip()
        if not pair or "=" not in pair:
            continue
        code, label = pair.split("=", 1)
        parsed[normalize_code(code)] = label.strip()
    return parsed


def compact(text: str, limit: int = 480) -> str:
    if len(text) <= limit:
        return text
    return text[: limit - 3].rstrip() + "..."


def signature_diff(records: list[dict[str, Any]], field: str, label: str) -> str:
    grouped: dict[str, list[str]] = defaultdict(list)
    for record in records:
        value = str(record.get(field) or "<blank>")
        grouped[value].append(record["dataset_name"])
    parts = [
        f"{value} ({'; '.join(sorted(datasets))})"
        for value, datasets in sorted(grouped.items())
    ]
    return compact(f"{label}: " + " | ".join(parts))


def mapping_signature(mapping: dict[str, str]) -> str:
    return "; ".join(f"{code}={mapping[code]}" for code in sorted(mapping, key=normalize_code))


def add_conflict(
    conflicts: list[dict[str, str]],
    seen: set[tuple[str, str, str, str]],
    variable_name: str,
    records: list[dict[str, Any]],
    conflict_type: str,
    evidence: str,
    proposed_change: str,
    risk_note: str,
) -> None:
    datasets = "; ".join(sorted({record["dataset_name"] for record in records}))
    row = {
        "variable_name": variable_name,
        "datasets_involved": datasets,
        "conflict_type": conflict_type,
        "evidence": compact(evidence),
        "proposed_change": proposed_change,
        "risk_note": risk_note,
    }
    key = (row["variable_name"], row["datasets_involved"], row["conflict_type"], row["evidence"])
    if key in seen:
        return
    seen.add(key)
    conflicts.append(row)


def mark(
    affected: dict[tuple[str, str], dict[str, Any]],
    records: list[dict[str, Any]],
    conflict_type: str,
    note: str,
) -> None:
    for record in records:
        key = (record["sheet_name"], record["variable_name"])
        affected[key]["flags"].add(conflict_type)
        affected[key]["notes"].append(note)


def different_label_records(records: list[dict[str, Any]]) -> bool:
    labels = [str(record.get("variable_label") or "") for record in records]
    normalized = {normalize_text(label) for label in labels}
    if len(normalized) > 1:
        return True
    return "" in normalized and any(label for label in normalized)


def code_label_conflicts(records: list[dict[str, Any]]) -> list[str]:
    by_code: dict[str, dict[str, list[str]]] = defaultdict(lambda: defaultdict(list))
    for record in records:
        for code, label in record["value_label_map"].items():
            by_code[code][label].append(record["dataset_name"])

    evidence = []
    for code, labels in sorted(by_code.items(), key=lambda item: normalize_code(item[0])):
        normalized_labels = {normalize_text(label) for label in labels}
        if len(normalized_labels) <= 1:
            continue
        pieces = [
            f"{label} ({'; '.join(sorted(datasets))})"
            for label, datasets in sorted(labels.items())
        ]
        evidence.append(f"code {code}: " + " | ".join(pieces))
    return evidence


def disjoint_value_label_evidence(records: list[dict[str, Any]]) -> str:
    mapped = [record for record in records if record["value_label_map"]]
    for i, left in enumerate(mapped):
        left_codes = set(left["value_label_map"])
        for right in mapped[i + 1 :]:
            right_codes = set(right["value_label_map"])
            if left_codes.isdisjoint(right_codes):
                return (
                    "value-label code sets do not overlap: "
                    f"{left['dataset_name']}={{{', '.join(sorted(left_codes, key=normalize_code))}}}; "
                    f"{right['dataset_name']}={{{', '.join(sorted(right_codes, key=normalize_code))}}}"
                )
    return ""


def value_label_signature_evidence(records: list[dict[str, Any]]) -> str:
    mapped = [record for record in records if record["value_label_map"]]
    parts = [
        f"{record['dataset_name']}={{{mapping_signature(record['value_label_map'])}}}"
        for record in mapped
    ]
    return compact("value_labels differ: " + " | ".join(parts))


def derivable_reason(variable: str, available: set[str]) -> str:
    for prefix in ("log_", "ln_"):
        if variable.startswith(prefix):
            base = variable[len(prefix) :]
            if base in available:
                return f"{variable} matches {prefix}<base> and base variable {base} exists"

    suffixes = ("_share", "_pct", "_per_capita", "_pc")
    for suffix in suffixes:
        if variable.endswith(suffix):
            base = variable[: -len(suffix)]
            if base in available:
                return f"{variable} matches <base>{suffix} and base variable {base} exists"

    return ""


def collect_records(
    data_sheets: list[tuple[str, list[dict[str, str]], list[str]]],
) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for sheet_name, rows, _columns in data_sheets:
        for row in rows:
            variable_name = row.get("variable_name", "")
            if not variable_name or variable_name in SPECIAL_VARIABLES:
                continue
            records.append(
                {
                    "sheet_name": sheet_name,
                    "dataset_name": row.get("dataset_name", sheet_name),
                    "variable_name": variable_name,
                    "variable_label": row.get("variable_label", ""),
                    "normalized_label": normalize_text(row.get("variable_label", "")),
                    "storage_type": row.get("storage_type", ""),
                    "value_labels": row.get("value_labels", ""),
                    "value_label_map": parse_value_labels(row.get("value_labels", "")),
                    "is_categorical": row.get("is_categorical", ""),
                }
            )
    return records


def scan_conflicts(records: list[dict[str, Any]]) -> tuple[list[dict[str, str]], dict[tuple[str, str], dict[str, Any]]]:
    conflicts: list[dict[str, str]] = []
    seen: set[tuple[str, str, str, str]] = set()
    affected: dict[tuple[str, str], dict[str, Any]] = defaultdict(lambda: {"flags": set(), "notes": []})

    by_name: dict[str, list[dict[str, Any]]] = defaultdict(list)
    by_label: dict[str, list[dict[str, Any]]] = defaultdict(list)
    by_sheet: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for record in records:
        by_name[record["variable_name"]].append(record)
        if record["normalized_label"]:
            by_label[record["normalized_label"]].append(record)
        by_sheet[record["sheet_name"]].append(record)

    for variable_name, same_name_records in sorted(by_name.items()):
        datasets = {record["dataset_name"] for record in same_name_records}
        if len(datasets) < 2:
            continue

        if len({record["storage_type"] for record in same_name_records}) > 1:
            evidence = signature_diff(same_name_records, "storage_type", "storage_type")
            add_conflict(
                conflicts,
                seen,
                variable_name,
                same_name_records,
                "naming",
                evidence,
                "Choose one storage convention or rename variables if concepts differ.",
                "Same name with different storage can break appends, merges, or pooled code.",
            )
            mark(affected, same_name_records, "naming", "Same variable name has inconsistent storage type.")

        if different_label_records(same_name_records):
            evidence = signature_diff(same_name_records, "variable_label", "variable_label")
            add_conflict(
                conflicts,
                seen,
                variable_name,
                same_name_records,
                "label",
                evidence,
                "Choose one authoritative variable label or rename if labels imply different concepts.",
                "Blank versus nonblank labels are flagged because documentation differs across datasets.",
            )
            mark(affected, same_name_records, "label", "Same variable name has inconsistent labels.")

        mapped_records = [record for record in same_name_records if record["value_label_map"]]
        if len(mapped_records) >= 2:
            code_conflicts = code_label_conflicts(mapped_records)
            if code_conflicts:
                evidence = " | ".join(code_conflicts)
                add_conflict(
                    conflicts,
                    seen,
                    variable_name,
                    mapped_records,
                    "coding",
                    evidence,
                    "Standardize value-label coding before pooled use.",
                    "Same code maps to different labels in different datasets.",
                )
                mark(affected, mapped_records, "coding", "Same variable name has conflicting value-label coding.")
            elif len({mapping_signature(record["value_label_map"]) for record in mapped_records}) > 1:
                evidence = value_label_signature_evidence(mapped_records)
                add_conflict(
                    conflicts,
                    seen,
                    variable_name,
                    mapped_records,
                    "coding",
                    evidence,
                    "Confirm whether extra or missing coded levels should be harmonized.",
                    "Mappings differ but shared codes do not currently map to different labels.",
                )
                mark(affected, mapped_records, "coding", "Same variable name has non-identical value-label mappings.")

            nonoverlap = disjoint_value_label_evidence(mapped_records)
            if nonoverlap:
                add_conflict(
                    conflicts,
                    seen,
                    variable_name,
                    mapped_records,
                    "naming",
                    nonoverlap,
                    "Rename if these are distinct concepts; otherwise recode to a common label set.",
                    "Fully disjoint value-label code sets may indicate concept drift or incompatible coding.",
                )
                mark(affected, mapped_records, "naming", "Same variable name has non-overlapping value-label codes.")

    for normalized_label, same_label_records in sorted(by_label.items()):
        variable_names = sorted({record["variable_name"] for record in same_label_records})
        if len(variable_names) < 2:
            continue
        display_names = "; ".join(variable_names)
        add_conflict(
            conflicts,
            seen,
            display_names,
            same_label_records,
            "conceptual",
            f"normalized label '{normalized_label}' appears under variables: {display_names}",
            f"Consider one unified name, e.g. {variable_names[0]}, if the concepts match.",
            "Heuristic label match; confirm context before renaming.",
        )
        mark(affected, same_label_records, "conceptual", "Same normalized label appears under different variable names.")

    for sheet_name, sheet_records in sorted(by_sheet.items()):
        available = {record["variable_name"] for record in sheet_records}
        for record in sheet_records:
            reason = derivable_reason(record["variable_name"], available)
            if not reason:
                continue
            add_conflict(
                conflicts,
                seen,
                record["variable_name"],
                [record],
                "derivable",
                reason,
                "Document the formula and consider deriving rather than storing a duplicate field.",
                "Name-pattern heuristic only; verify determinism before dropping or rebuilding.",
            )
            mark(affected, [record], "derivable", "Variable appears derivable from another variable in the same dataset.")

    order = {name: index for index, name in enumerate(CONFLICT_ORDER)}
    conflicts.sort(
        key=lambda row: (
            order.get(row["conflict_type"], 99),
            row["variable_name"].lower(),
            row["datasets_involved"].lower(),
            row["evidence"].lower(),
        )
    )
    return conflicts, affected


def apply_conflict_flags(
    data_sheets: list[tuple[str, list[dict[str, str]], list[str]]],
    affected: dict[tuple[str, str], dict[str, Any]],
) -> list[tuple[str, list[dict[str, str]], list[str]]]:
    updated: list[tuple[str, list[dict[str, str]], list[str]]] = []
    for sheet_name, rows, columns in data_sheets:
        columns = list(columns)
        for column in ("conflict_flag", "remedial_note"):
            if column not in columns:
                columns.append(column)

        for row in rows:
            key = (sheet_name, row.get("variable_name", ""))
            flags = affected.get(key, {"flags": set(), "notes": []})["flags"]
            notes = affected.get(key, {"flags": set(), "notes": []})["notes"]
            row["conflict_flag"] = ";".join(
                flag for flag in CONFLICT_ORDER if flag in flags
            )
            deduped_notes = list(dict.fromkeys(notes))
            row["remedial_note"] = compact(" | ".join(deduped_notes), limit=300)
        updated.append((sheet_name, rows, columns))
    return updated


def main() -> int:
    if not WORKBOOK_PATH.exists():
        raise SystemExit(
            "Missing inventory/variable_listing.xlsx. "
            "Run inventory/build_variable_listing.py first."
        )

    sheets = read_xlsx(WORKBOOK_PATH)
    index_sheet = next((sheet for sheet in sheets if sheet[0] == "_index"), None)
    data_sheets = [
        (name, rows, columns)
        for name, rows, columns in sheets
        if name not in {"_index", "_conflicts"}
    ]

    records = collect_records(data_sheets)
    conflicts, affected = scan_conflicts(records)
    updated_data_sheets = apply_conflict_flags(data_sheets, affected)

    output_sheets: list[tuple[str, list[dict[str, Any]], list[str]]] = []
    if index_sheet is not None:
        output_sheets.append(index_sheet)
    output_sheets.append(("_conflicts", conflicts, CONFLICT_COLUMNS))
    output_sheets.extend(updated_data_sheets)

    write_xlsx(WORKBOOK_PATH, output_sheets)
    write_csv_mirrors(CSV_DIR, output_sheets)

    counts = Counter(row["conflict_type"] for row in conflicts)
    categorical_count = sum(
        1
        for record in records
        if str(record.get("is_categorical", "")).strip() in {"1", "1.0", "True", "true"}
    )

    print(f"Datasets scanned: {len(data_sheets)}")
    print(f"Total variables: {len(records)}")
    print(f"Categorical variables: {categorical_count}")
    if counts:
        print("Conflicts by type:")
        for conflict_type in CONFLICT_ORDER:
            if counts.get(conflict_type, 0):
                print(f"  {conflict_type}: {counts[conflict_type]}")
    else:
        print("Conflicts by type: none")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
