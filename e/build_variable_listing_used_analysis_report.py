#!/usr/bin/env python
"""Summarize used_analysis coverage from the variable listing workbook."""

from __future__ import annotations

import argparse
import re
import zipfile
from collections import Counter
from datetime import date
from pathlib import Path
from typing import Dict, Iterable, List, Tuple
from xml.etree import ElementTree as ET


NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
RNS = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"


def column_number(cell_ref: str) -> int:
    match = re.match(r"([A-Z]+)", cell_ref)
    if match is None:
        raise ValueError(f"Invalid cell reference: {cell_ref}")
    number = 0
    for char in match.group(1):
        number = number * 26 + ord(char) - ord("A") + 1
    return number - 1


def cell_text(cell: ET.Element, shared_strings: List[str]) -> str:
    cell_type = cell.attrib.get("t")
    if cell_type == "inlineStr":
        inline = cell.find(f"{NS}is")
        if inline is None:
            return ""
        return "".join(
            node.text or "" for node in inline.iter() if node.tag == f"{NS}t"
        )
    value = cell.find(f"{NS}v")
    if value is None or value.text is None:
        return ""
    if cell_type == "s":
        return shared_strings[int(value.text)]
    return value.text


def read_shared_strings(workbook: zipfile.ZipFile) -> List[str]:
    if "xl/sharedStrings.xml" not in workbook.namelist():
        return []
    root = ET.fromstring(workbook.read("xl/sharedStrings.xml"))
    strings = []
    for item in root.findall(f"{NS}si"):
        strings.append("".join(node.text or "" for node in item.iter() if node.tag == f"{NS}t"))
    return strings


def sheet_targets(workbook: zipfile.ZipFile) -> Dict[str, str]:
    root = ET.fromstring(workbook.read("xl/workbook.xml"))
    rels_root = ET.fromstring(workbook.read("xl/_rels/workbook.xml.rels"))
    rels = {rel.attrib["Id"]: rel.attrib["Target"] for rel in rels_root}
    targets = {}
    for sheet in root.find(f"{NS}sheets"):
        rel_id = sheet.attrib[f"{RNS}id"]
        targets[sheet.attrib["name"]] = rels[rel_id]
    return targets


def read_sheet(
    workbook: zipfile.ZipFile, target: str, shared_strings: List[str]
) -> List[List[str]]:
    path = target if target.startswith("xl/") else f"xl/{target}"
    root = ET.fromstring(workbook.read(path))
    rows = []
    for row in root.findall(f".//{NS}sheetData/{NS}row"):
        values = {
            column_number(cell.attrib["r"]): cell_text(cell, shared_strings)
            for cell in row.findall(f"{NS}c")
        }
        if values:
            rows.append([values.get(index, "") for index in range(max(values) + 1)])
    return rows


def records_from_rows(rows: List[List[str]]) -> List[Dict[str, str]]:
    if not rows:
        return []
    header = rows[0]
    records = []
    for row in rows[1:]:
        padded = row + [""] * max(0, len(header) - len(row))
        records.append(dict(zip(header, padded)))
    return records


def parse_int(value: str, default: int = 0) -> int:
    if value == "":
        return default
    return int(float(value))


def load_summary(workbook_path: Path) -> Tuple[List[Dict[str, object]], Dict[str, int]]:
    with zipfile.ZipFile(workbook_path) as workbook:
        shared_strings = read_shared_strings(workbook)
        targets = sheet_targets(workbook)
        index_rows = read_sheet(workbook, targets["_index"], shared_strings)
        index_records = records_from_rows(index_rows)

        summaries: List[Dict[str, object]] = []
        for record in index_records:
            sheet_name = record["sheet_name"]
            variable_rows = read_sheet(workbook, targets[sheet_name], shared_strings)
            variable_records = records_from_rows(variable_rows)
            used_count = sum(
                1
                for variable in variable_records
                if str(variable.get("used_analysis", "")).strip() == "1"
            )
            total_vars = parse_int(str(record.get("n_vars", "")), len(variable_records))
            percent_used = (used_count / total_vars * 100) if total_vars else 0
            summaries.append(
                {
                    "dataset_name": record.get("dataset_name", ""),
                    "sheet_name": sheet_name,
                    "absolute_dataset_path": record.get("absolute_dataset_path", ""),
                    "file_type": record.get("file_type", ""),
                    "n_obs": parse_int(str(record.get("n_obs", ""))),
                    "n_vars": total_vars,
                    "used_vars": used_count,
                    "percent_used": percent_used,
                    "dataset_stage": record.get("dataset_stage", ""),
                    "producer_script": record.get("producer_script", ""),
                }
            )

    totals = {
        "datasets": len(summaries),
        "variables": sum(int(row["n_vars"]) for row in summaries),
        "used_variables": sum(int(row["used_vars"]) for row in summaries),
        "primary_datasets": sum(1 for row in summaries if int(row["used_vars"]) > 0),
    }
    return summaries, totals


def markdown_table(headers: Iterable[str], rows: Iterable[Iterable[object]]) -> List[str]:
    header_list = list(headers)
    lines = [
        "| " + " | ".join(header_list) + " |",
        "| " + " | ".join(["---"] * len(header_list)) + " |",
    ]
    for row in rows:
        lines.append("| " + " | ".join(str(value) for value in row) + " |")
    return lines


def fmt_percent(value: object) -> str:
    return f"{float(value):.1f}%"


def write_report(
    workbook_path: Path, report_path: Path, summaries: List[Dict[str, object]], totals: Dict[str, int]
) -> None:
    stage_counts = Counter(str(row["dataset_stage"]) for row in summaries)
    stage_rows = []
    for stage in sorted(stage_counts):
        rows = [row for row in summaries if row["dataset_stage"] == stage]
        total_vars = sum(int(row["n_vars"]) for row in rows)
        used_vars = sum(int(row["used_vars"]) for row in rows)
        stage_rows.append(
            [
                stage,
                len(rows),
                total_vars,
                used_vars,
                fmt_percent(used_vars / total_vars * 100 if total_vars else 0),
                sum(1 for row in rows if int(row["used_vars"]) > 0),
            ]
        )

    all_dataset_rows = []
    for row in sorted(
        summaries,
        key=lambda item: (
            str(item["dataset_stage"]),
            str(item["dataset_name"]),
            str(item["sheet_name"]),
        ),
    ):
        label = str(row["dataset_name"])
        if row["sheet_name"] != row["dataset_name"]:
            label = f"{label} ({row['sheet_name']})"
        all_dataset_rows.append(
            [
                label,
                row["dataset_stage"],
                row["n_vars"],
                row["used_vars"],
                fmt_percent(row["percent_used"]),
            ]
        )

    primary_rows = []
    for row in sorted(
        [item for item in summaries if int(item["used_vars"]) > 0],
        key=lambda item: (
            -int(item["used_vars"]),
            -float(item["percent_used"]),
            str(item["dataset_name"]),
            str(item["sheet_name"]),
        ),
    ):
        label = str(row["dataset_name"])
        if row["sheet_name"] != row["dataset_name"]:
            label = f"{label} ({row['sheet_name']})"
        primary_rows.append(
            [
                label,
                row["dataset_stage"],
                row["used_vars"],
                row["n_vars"],
                fmt_percent(row["percent_used"]),
            ]
        )

    raw_primary_rows = [
        row
        for row in primary_rows
        if row[1] == "raw_analysis_input"
    ]

    lines = [
        "# Variable Listing Used-Analysis Report",
        "",
        f"Source workbook: `{workbook_path}`",
        f"Generated: {date.today().isoformat()}",
        "",
        "## Summary",
        "",
        f"- Datasets scanned: {totals['datasets']}",
        f"- Total variables: {totals['variables']}",
        f"- Variables marked `used_analysis = 1`: {totals['used_variables']}",
        f"- Datasets with at least one used variable: {totals['primary_datasets']}",
        "",
        "## Coverage By Dataset Stage",
        "",
    ]
    lines.extend(
        markdown_table(
            [
                "Dataset stage",
                "Datasets",
                "Total variables",
                "Used variables",
                "Used share",
                "Datasets with used vars",
            ],
            stage_rows,
        )
    )
    lines.extend(
        [
            "",
            "## Dataset-Level Used-Analysis Coverage",
            "",
        ]
    )
    lines.extend(
        markdown_table(
            ["Dataset", "Stage", "Total variables", "Used variables", "Used share"],
            all_dataset_rows,
        )
    )
    lines.extend(
        [
            "",
            "## Primary Datasets",
            "",
            "Primary datasets are defined here as datasets with at least one variable flagged `used_analysis = 1`.",
            "",
        ]
    )
    lines.extend(
        markdown_table(
            ["Dataset", "Stage", "Used variables", "Total variables", "Used share"],
            primary_rows,
        )
    )
    lines.extend(
        [
            "",
            "## Primary Raw/Supplied Inputs",
            "",
            "These are the primary datasets above that are marked `raw_analysis_input` in the workbook index.",
            "",
        ]
    )
    lines.extend(
        markdown_table(
            ["Dataset", "Stage", "Used variables", "Total variables", "Used share"],
            raw_primary_rows,
        )
    )
    lines.append("")

    report_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--workbook",
        type=Path,
        default=Path("/dartfs-hpc/scratch/siddiqui/variable_listing.xlsx"),
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=Path("e/variable_listing_used_analysis_report.md"),
    )
    args = parser.parse_args()

    summaries, totals = load_summary(args.workbook)
    write_report(args.workbook, args.report, summaries, totals)
    print(f"Wrote {args.report}")


if __name__ == "__main__":
    main()
