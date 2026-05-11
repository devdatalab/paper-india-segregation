from __future__ import annotations

import csv
import re
from pathlib import Path
from typing import Iterable
from xml.etree import ElementTree as ET
from zipfile import ZIP_DEFLATED, ZipFile


INVALID_SHEET_CHARS = re.compile(r"[\[\]:*?/\\]")
NS_MAIN = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
NS_REL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
NS_PACKAGE_REL = "http://schemas.openxmlformats.org/package/2006/relationships"


def sanitize_sheet_name(name: str, used: set[str]) -> str:
    base = INVALID_SHEET_CHARS.sub("_", str(name).strip()) or "dataset"
    base = base.strip("'") or "dataset"
    base = base[:31]
    candidate = base
    suffix = 1
    while candidate in used:
        suffix_text = f"_{suffix}"
        candidate = f"{base[:31 - len(suffix_text)]}{suffix_text}"
        suffix += 1
    used.add(candidate)
    return candidate


def write_csv(path: Path, rows: list[dict[str, object]], columns: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow({column: row.get(column, "") for column in columns})


def _cell_ref(row_number: int, col_number: int) -> str:
    letters = ""
    value = col_number
    while value:
        value, remainder = divmod(value - 1, 26)
        letters = chr(65 + remainder) + letters
    return f"{letters}{row_number}"


def _xml_text(value: object) -> str:
    if value is None:
        return ""
    return str(value)


def _worksheet_xml(rows: list[dict[str, object]], columns: list[str]) -> str:
    worksheet = ET.Element(f"{{{NS_MAIN}}}worksheet")
    sheet_data = ET.SubElement(worksheet, f"{{{NS_MAIN}}}sheetData")

    for row_number, values in enumerate([dict(zip(columns, columns)), *rows], start=1):
        row_el = ET.SubElement(sheet_data, f"{{{NS_MAIN}}}row", {"r": str(row_number)})
        for col_number, column in enumerate(columns, start=1):
            text = _xml_text(values.get(column, ""))
            cell = ET.SubElement(
                row_el,
                f"{{{NS_MAIN}}}c",
                {"r": _cell_ref(row_number, col_number), "t": "inlineStr"},
            )
            inline = ET.SubElement(cell, f"{{{NS_MAIN}}}is")
            t_el = ET.SubElement(inline, f"{{{NS_MAIN}}}t")
            t_el.text = text
    return ET.tostring(worksheet, encoding="utf-8", xml_declaration=True).decode("utf-8")


def write_xlsx(
    workbook_path: Path,
    sheets: list[tuple[str, list[dict[str, object]], list[str]]],
) -> None:
    workbook_path.parent.mkdir(parents=True, exist_ok=True)

    content_types = ET.Element(
        "Types",
        {"xmlns": "http://schemas.openxmlformats.org/package/2006/content-types"},
    )
    for part_name, content_type in [
        (
            "/_rels/.rels",
            "application/vnd.openxmlformats-package.relationships+xml",
        ),
        (
            "/xl/_rels/workbook.xml.rels",
            "application/vnd.openxmlformats-package.relationships+xml",
        ),
        (
            "/xl/workbook.xml",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml",
        ),
        (
            "/xl/styles.xml",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml",
        ),
    ]:
        ET.SubElement(content_types, "Override", {"PartName": part_name, "ContentType": content_type})
    for index in range(1, len(sheets) + 1):
        ET.SubElement(
            content_types,
            "Override",
            {
                "PartName": f"/xl/worksheets/sheet{index}.xml",
                "ContentType": "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml",
            },
        )

    package_rels = ET.Element("Relationships", {"xmlns": NS_PACKAGE_REL})
    ET.SubElement(
        package_rels,
        "Relationship",
        {
            "Id": "rId1",
            "Type": "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
            "Target": "xl/workbook.xml",
        },
    )

    workbook = ET.Element(f"{{{NS_MAIN}}}workbook", {f"xmlns:r": NS_REL})
    sheets_el = ET.SubElement(workbook, f"{{{NS_MAIN}}}sheets")
    for index, (sheet_name, _rows, _columns) in enumerate(sheets, start=1):
        ET.SubElement(
            sheets_el,
            f"{{{NS_MAIN}}}sheet",
            {"name": sheet_name, "sheetId": str(index), f"{{{NS_REL}}}id": f"rId{index}"},
        )

    workbook_rels = ET.Element("Relationships", {"xmlns": NS_PACKAGE_REL})
    for index in range(1, len(sheets) + 1):
        ET.SubElement(
            workbook_rels,
            "Relationship",
            {
                "Id": f"rId{index}",
                "Type": "http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet",
                "Target": f"worksheets/sheet{index}.xml",
            },
        )
    ET.SubElement(
        workbook_rels,
        "Relationship",
        {
            "Id": f"rId{len(sheets) + 1}",
            "Type": "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles",
            "Target": "styles.xml",
        },
    )

    style_xml = """<?xml version='1.0' encoding='UTF-8'?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>
  <fills count="1"><fill><patternFill patternType="none"/></fill></fills>
  <borders count="1"><border/></borders>
  <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
  <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>
</styleSheet>
"""

    with ZipFile(workbook_path, "w", ZIP_DEFLATED) as zf:
        zf.writestr(
            "[Content_Types].xml",
            ET.tostring(content_types, encoding="utf-8", xml_declaration=True).decode("utf-8"),
        )
        zf.writestr(
            "_rels/.rels",
            ET.tostring(package_rels, encoding="utf-8", xml_declaration=True).decode("utf-8"),
        )
        zf.writestr(
            "xl/workbook.xml",
            ET.tostring(workbook, encoding="utf-8", xml_declaration=True).decode("utf-8"),
        )
        zf.writestr(
            "xl/_rels/workbook.xml.rels",
            ET.tostring(workbook_rels, encoding="utf-8", xml_declaration=True).decode("utf-8"),
        )
        zf.writestr("xl/styles.xml", style_xml)
        for index, (_sheet_name, rows, columns) in enumerate(sheets, start=1):
            zf.writestr(f"xl/worksheets/sheet{index}.xml", _worksheet_xml(rows, columns))


def _column_index(cell_ref: str) -> int:
    letters = "".join(ch for ch in cell_ref if ch.isalpha())
    value = 0
    for ch in letters:
        value = value * 26 + ord(ch.upper()) - 64
    return value


def _cell_text(cell: ET.Element) -> str:
    cell_type = cell.attrib.get("t")
    if cell_type == "inlineStr":
        text = cell.find(f"{{{NS_MAIN}}}is/{{{NS_MAIN}}}t")
        return "" if text is None or text.text is None else text.text
    value = cell.find(f"{{{NS_MAIN}}}v")
    return "" if value is None or value.text is None else value.text


def read_xlsx(workbook_path: Path) -> list[tuple[str, list[dict[str, str]], list[str]]]:
    with ZipFile(workbook_path) as zf:
        workbook_root = ET.fromstring(zf.read("xl/workbook.xml"))
        rels_root = ET.fromstring(zf.read("xl/_rels/workbook.xml.rels"))
        rel_targets = {
            rel.attrib["Id"]: rel.attrib["Target"]
            for rel in rels_root.findall(f"{{{NS_PACKAGE_REL}}}Relationship")
        }
        parsed: list[tuple[str, list[dict[str, str]], list[str]]] = []
        for sheet in workbook_root.findall(f"{{{NS_MAIN}}}sheets/{{{NS_MAIN}}}sheet"):
            sheet_name = sheet.attrib["name"]
            rel_id = sheet.attrib[f"{{{NS_REL}}}id"]
            target = rel_targets[rel_id]
            sheet_path = f"xl/{target}" if not target.startswith("/") else target.lstrip("/")
            root = ET.fromstring(zf.read(sheet_path))
            raw_rows: list[list[str]] = []
            max_col = 0
            for row in root.findall(f"{{{NS_MAIN}}}sheetData/{{{NS_MAIN}}}row"):
                values: dict[int, str] = {}
                for cell in row.findall(f"{{{NS_MAIN}}}c"):
                    col = _column_index(cell.attrib.get("r", "A1"))
                    max_col = max(max_col, col)
                    values[col] = _cell_text(cell)
                raw_rows.append([values.get(i, "") for i in range(1, max_col + 1)])
            if not raw_rows:
                parsed.append((sheet_name, [], []))
                continue
            columns = raw_rows[0]
            rows = [
                {columns[i]: row[i] if i < len(row) else "" for i in range(len(columns))}
                for row in raw_rows[1:]
            ]
            parsed.append((sheet_name, rows, columns))
    return parsed


def write_csv_mirrors(
    output_dir: Path,
    sheets: Iterable[tuple[str, list[dict[str, object]], list[str]]],
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for old_file in output_dir.glob("*.csv"):
        old_file.unlink()
    for sheet_name, rows, columns in sheets:
        write_csv(output_dir / f"{sheet_name}.csv", rows, columns)
