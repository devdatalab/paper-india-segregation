#!/usr/bin/env python
"""Add used-variable rename and storage harmonization suggestions."""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from inventory.variable_listing_utils import read_xlsx, write_xlsx


DEFAULT_WORKBOOK = Path("/dartfs-hpc/scratch/siddiqui/variable_listing.xlsx")
SPECIAL_SHEETS = {"_index", "dataset_purpose", "_conflicts"}
BAD_ED_LABEL = "Population count with missing education"
SNAKE_CASE = re.compile(r"^[a-z][a-z0-9_]*$")
STR_STORAGE = re.compile(r"^str(\d+|L)$", re.IGNORECASE)


GLOBAL_RENAMES = {
    "any_event": "any_violent_event",
    "bcut": "us_census_tract_black_share_bin",
    "block_group": "seg_block_group_min_population",
    "block_no": "seg_block_group_id",
    "block_pop": "secc_block_population",
    "block_pop_muslim": "secc_block_muslim_population",
    "block_pop_nonscmuslim": "secc_block_non_sc_non_muslim_population",
    "block_pop_sc": "secc_block_sc_population",
    "cbsatitle": "us_census_cbsa_name",
    "city_dissim_muslim": "seg_city_muslim_dissimilarity",
    "city_dissim_muslim_r": "district_rural_muslim_dissimilarity",
    "city_dissim_muslim_u": "district_urban_muslim_dissimilarity",
    "city_dissim_sc": "seg_city_sc_dissimilarity",
    "city_dissim_sc_r": "district_rural_sc_dissimilarity",
    "city_dissim_sc_u": "district_urban_sc_dissimilarity",
    "city_iso_muslim": "seg_city_muslim_isolation",
    "city_iso_muslim_r": "district_rural_muslim_isolation",
    "city_iso_muslim_u": "district_urban_muslim_isolation",
    "city_iso_sc": "seg_city_sc_isolation",
    "city_iso_sc_r": "district_rural_sc_isolation",
    "city_iso_sc_u": "district_urban_sc_isolation",
    "city_origin_year": "pc11_city_origin_year",
    "city_pop": "secc_city_population",
    "city_pop_muslim": "secc_city_muslim_population",
    "city_pop_sc": "secc_city_sc_population",
    "closed_drain": "secc_closed_drain_share",
    "cons_pc": "secc_city_consumption_per_capita",
    "cons_pc_muslim": "secc_city_muslim_consumption_per_capita",
    "cons_pc_sc": "secc_city_sc_consumption_per_capita",
    "cons_pcap": "secc_block_consumption_per_capita",
    "cons_pcap_muslim": "secc_block_muslim_consumption_per_capita",
    "cons_pcap_nonscmuslim": "secc_block_non_sc_non_muslim_consumption_per_capita",
    "cons_pcap_sc": "secc_block_sc_consumption_per_capita",
    "d_sc_pc01": "pc01_sc_dissimilarity",
    "diff_tot_pop11": "pc11_pdf_pca_total_population_difference",
    "dum_hospital_priv": "ec13_has_private_hospital",
    "dum_hospital_pub": "ec13_has_public_hospital",
    "dum_primary_priv": "ec13_has_private_primary_school",
    "dum_primary_pub": "ec13_has_public_primary_school",
    "dum_secondary_priv": "ec13_has_private_secondary_school",
    "dum_secondary_pub": "ec13_has_public_secondary_school",
    "ed_yrs": "secc_city_mean_education_years",
    "ed_yrs_muslim": "secc_city_muslim_mean_education_years",
    "ed_yrs_sc": "secc_city_sc_mean_education_years",
    "event_count": "violent_event_count",
    "fips_code": "us_census_county_fips_id",
    "fipscountycode": "us_census_county_fips_suffix_id",
    "fipsstatecode": "us_census_state_fips_id",
    "geometry": "gis_geometry",
    "hh": "secc_household_count",
    "hosp_pc": "pc11_hospitals_per_100k",
    "hospital": "ec13_block_hospital_count",
    "iso_sc_pc01": "pc01_sc_isolation",
    "latitude": "shrug_latitude",
    "light_source_elec": "secc_electric_lighting_share",
    "ln_city_pop": "secc_log_city_population",
    "ln_cons_pc": "secc_log_city_consumption_per_capita",
    "ln_cons_pc_muslim": "secc_log_city_muslim_consumption_per_capita",
    "ln_cons_pc_nonscmuslim": "secc_log_city_non_sc_non_muslim_consumption_per_capita",
    "ln_cons_pc_sc": "secc_log_city_sc_consumption_per_capita",
    "ln_growth": "pc91_pc11_log_population_growth_rate",
    "log_area_pc11": "pc11_log_city_area",
    "log_block_pop": "secc_log_block_population",
    "log_cons_pcap": "secc_log_block_consumption_per_capita",
    "log_hospital_emp_priv": "ec13_log_private_hospital_employment",
    "log_hospital_emp_pub": "ec13_log_public_hospital_employment",
    "log_primary_emp_priv": "ec13_log_private_primary_school_employment",
    "log_primary_emp_pub": "ec13_log_public_primary_school_employment",
    "log_secondary_emp_priv": "ec13_log_private_secondary_school_employment",
    "log_secondary_emp_pub": "ec13_log_public_secondary_school_employment",
    "longitude": "shrug_longitude",
    "mean_muslim_dissim": "mean_muslim_dissimilarity",
    "mean_muslim_iso": "mean_muslim_isolation",
    "mean_pop": "seg_block_group_mean_population",
    "mean_sc_dissim": "mean_sc_dissimilarity",
    "mean_sc_iso": "mean_sc_isolation",
    "mid_pc": "pc11_middle_schools_per_100k",
    "msa_black_pop": "us_census_msa_black_population",
    "msa_black_prop": "us_census_msa_black_share",
    "msa_black_share": "us_census_msa_black_share",
    "msa_dissim_us_census": "us_census_msa_black_dissimilarity",
    "msa_id": "us_census_msa_id",
    "msa_iso_us_census": "us_census_msa_black_isolation",
    "msa_total_pop": "us_census_msa_total_population",
    "muslim_ed_gap": "secc_muslim_education_gap",
    "muslim_job_share": "ec13_muslim_job_share",
    "muslim_ln_cons_gap": "secc_muslim_log_consumption_gap",
    "muslim_pop_share": "secc_city_muslim_population_share",
    "muslim_share_pc11": "pc11_muslim_population_share",
    "non_rel_event_count": "non_religious_violent_event_count",
    "p25": "secc_mobility_p25",
    "pc01_pca_p_lit": "pc01_pca_literate_population",
    "pc01_pca_p_sc": "pc01_pca_sc_population",
    "pc01_pca_tot_p": "pc01_pca_total_population",
    "pc11_d_id": "pc11_shape_district_id",
    "pc11_p_muslim": "pc11_muslim_population",
    "pc11_pca_p_06": "pc11_pca_age_0_6_population",
    "pc11_pca_p_sc": "pc11_pca_sc_population",
    "pc11_pca_p_st": "pc11_pca_st_population",
    "pc11_pca_tot_p": "pc11_pca_total_population",
    "pc11_s_id": "pc11_shape_state_id",
    "pc11_sd_id": "pc11_shape_subdistrict_id",
    "pc11_td_all_hospital": "pc11_td_allopathic_hospital_count",
    "pc11_td_area": "pc11_td_town_area",
    "pc11_td_m_sch": "pc11_td_middle_school_count",
    "pc11_td_p_sc": "pc11_td_sc_population",
    "pc11_td_p_sch": "pc11_td_primary_school_count",
    "pc11_td_s_sch": "pc11_td_secondary_school_count",
    "pc11_tot_p": "pc11_total_population",
    "pc11_vd_all_hosp": "pc11_vd_village_allopathic_hospital_count",
    "pc11_vd_area": "pc11_vd_village_area",
    "pc11_vd_m_sch": "pc11_vd_village_middle_school_count",
    "pc11_vd_p_sch": "pc11_vd_village_primary_school_count",
    "pc11_vd_s_sch": "pc11_vd_village_secondary_school_count",
    "place_name": "shrug_place_name",
    "prim_pc": "pc11_primary_schools_per_100k",
    "primary": "ec13_block_primary_school_count",
    "pub": "ec13_public_ownership_count",
    "religious_event_count": "religious_violent_event_count",
    "rural_cons_gini": "secc_rural_consumption_gini",
    "rural_land_gini": "secc_rural_land_gini",
    "sc_ed_gap": "secc_sc_education_gap",
    "sc_job_share": "ec13_sc_job_share",
    "sc_ln_cons_gap": "secc_sc_log_consumption_gap",
    "sc_pop_share": "secc_city_sc_population_share",
    "sec_pc": "pc11_secondary_schools_per_100k",
    "secondary": "ec13_block_secondary_school_count",
    "sector": "seg_sector",
    "share": "us_census_population_share_bin_midpoint",
    "shrid": "shrug_id",
    "subdistrict": "pc11_subdistrict_composite_id",
    "total_pop": "pc01_hb_total_population",
    "town": "shrug_town_id",
    "town_cons_gini": "secc_town_consumption_gini",
    "town_name_pc01_pdf": "pc01_pdf_town_name",
    "town_name_pc11_pdf": "pc11_pdf_town_name",
    "tpop_b": "us_census_black_population_share_in_bin",
    "tract_black_pop": "us_census_tract_black_population",
    "tract_black_prop": "us_census_tract_black_share",
    "tract_blackonly_pop": "us_census_tract_black_only_population",
    "tract_nonblack_pop": "us_census_tract_nonblack_population",
    "tract_total_pop_bw": "us_census_tract_black_white_population",
    "wat_source_home": "secc_water_source_at_home_share",
}


PDF_EB_RENAMES = {
    "pc01_pdf_eb_clean.dta": {
        "town_name": "pc01_pdf_town_name",
        "pop_tot": "pc01_pdf_eb_total_population",
        "pop_sc": "pc01_pdf_eb_sc_population",
        "pop_st": "pc01_pdf_eb_st_population",
    },
    "pc11_pdf_eb_clean.dta": {
        "town_name": "pc11_pdf_town_name",
        "pop_tot": "pc11_pdf_eb_total_population",
        "pop_sc": "pc11_pdf_eb_sc_population",
        "pop_st": "pc11_pdf_eb_st_population",
    },
}

RURAL_CITY_VD_RENAMES = {
    "pc11_vd_all_hosp": "pc11_vd_subdistrict_allopathic_hospital_count",
    "pc11_vd_area": "pc11_vd_subdistrict_area",
    "pc11_vd_m_sch": "pc11_vd_subdistrict_middle_school_count",
    "pc11_vd_p_sch": "pc11_vd_subdistrict_primary_school_count",
    "pc11_vd_s_sch": "pc11_vd_subdistrict_secondary_school_count",
}


def is_data_sheet(sheet_name: str, columns: list[str]) -> bool:
    return (
        sheet_name not in SPECIAL_SHEETS
        and "variable_name" in columns
        and "storage_type" in columns
    )


def is_used(row: dict[str, str]) -> bool:
    return str(row.get("used_analysis", "")).strip() == "1"


def snake_clean(value: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9]+", "_", value).strip("_").lower()
    cleaned = re.sub(r"_+", "_", cleaned)
    if not cleaned:
        return "unnamed_variable"
    if cleaned[0].isdigit():
        return f"v_{cleaned}"
    return cleaned


def insert_after(columns: list[str], new_column: str, anchor: str) -> list[str]:
    if anchor not in columns:
        raise ValueError(f"Cannot insert {new_column}: missing anchor column {anchor}")
    reordered = [column for column in columns if column != new_column]
    anchor_index = reordered.index(anchor)
    return reordered[: anchor_index + 1] + [new_column] + reordered[anchor_index + 1 :]


def proposal_for_row(sheet_name: str, row: dict[str, str]) -> str:
    variable_name = row.get("variable_name", "")

    if variable_name == "__file__":
        if sheet_name.endswith(".prj"):
            return "pc11_gis_projection_file"
        if sheet_name.endswith(".shx"):
            return "pc11_gis_shape_index_file"
        return f"{snake_clean(sheet_name)}_file_placeholder"

    if variable_name == "__missing_file__":
        return f"{snake_clean(sheet_name)}_missing_file"

    if sheet_name in PDF_EB_RENAMES and variable_name in PDF_EB_RENAMES[sheet_name]:
        return PDF_EB_RENAMES[sheet_name][variable_name]

    if sheet_name.startswith("segregation_citydata_rural_") and variable_name in RURAL_CITY_VD_RENAMES:
        return RURAL_CITY_VD_RENAMES[variable_name]

    if variable_name == "city_pop_pc11":
        if sheet_name.startswith("segregation_citydata_rural_"):
            return "pc11_vd_subdistrict_population"
        return "pc11_td_town_population"

    if variable_name == "log_city_pop_pc11":
        if sheet_name.startswith("segregation_citydata_rural_"):
            return "pc11_log_vd_subdistrict_population"
        return "pc11_log_td_town_population"

    if variable_name in {"sc", "muslim", "nonscmuslim"}:
        group = {
            "sc": "sc",
            "muslim": "muslim",
            "nonscmuslim": "non_sc_non_muslim",
        }[variable_name]
        if sheet_name.startswith("segregation_citydata_"):
            return f"secc_city_{group}_population_count"
        return f"secc_block_{group}_population_count"

    if variable_name in {"sc_share", "muslim_share"}:
        group = "sc" if variable_name == "sc_share" else "muslim"
        if sheet_name.startswith("segregation_citydata_"):
            return f"secc_city_{group}_population_share"
        return f"secc_block_{group}_population_share"

    if variable_name == "slum":
        if sheet_name.startswith("segregation_blockdata_"):
            return "secc_block_slum_share_or_indicator"
        return "secc_city_slum_share_or_indicator"

    if variable_name in GLOBAL_RENAMES:
        return GLOBAL_RENAMES[variable_name]

    return snake_clean(variable_name)


def is_string_storage(storage_type: str) -> bool:
    return bool(STR_STORAGE.match(storage_type.strip()))


def widest_string_storage(storage_types: list[str]) -> str:
    widths = []
    for storage_type in storage_types:
        match = STR_STORAGE.match(storage_type.strip())
        if match is None:
            continue
        width = match.group(1)
        if width.upper() == "L":
            return "strL"
        widths.append(int(width))
    return f"str{max(widths)}"


def is_integer_concept(name: str) -> bool:
    integer_markers = (
        name.endswith("_id"),
        name.endswith("_count"),
        name.endswith("_population"),
        name.endswith("_year"),
        "_population_" in name,
        "_count_" in name,
    )
    return any(integer_markers)


def is_binary_concept(name: str) -> bool:
    return name.startswith("has_") or name.startswith("any_")


def is_continuous_concept(name: str) -> bool:
    continuous_markers = (
        "share",
        "ratio",
        "rate",
        "dissimilarity",
        "isolation",
        "gini",
        "log_",
        "_log_",
        "growth",
        "gap",
        "per_capita",
        "per_100k",
        "latitude",
        "longitude",
        "area",
        "mean_",
        "midpoint",
        "p25",
        "difference",
    )
    return any(marker in name for marker in continuous_markers)


def harmonized_storage(name: str, storage_types: list[str]) -> str:
    clean_storages = [storage.strip() for storage in storage_types if storage.strip()]
    if not clean_storages:
        return ""

    if any(is_string_storage(storage) for storage in clean_storages):
        return widest_string_storage(clean_storages)

    unique = sorted(set(clean_storages))
    if len(unique) == 1 and unique[0] not in {"byte", "int", "long", "float", "double"}:
        return unique[0]

    if is_binary_concept(name):
        return "byte"

    if is_integer_concept(name):
        return "int" if name.endswith("_year") else "long"

    if is_continuous_concept(name):
        return "double" if "double" in unique else "float"

    numeric_order = ["byte", "int", "long", "float", "double"]
    numeric = [storage for storage in unique if storage in numeric_order]
    if numeric:
        return max(numeric, key=numeric_order.index)

    return unique[-1]


def transform_sheets(
    sheets: list[tuple[str, list[dict[str, str]], list[str]]],
) -> tuple[list[tuple[str, list[dict[str, str]], list[str]]], dict[str, int]]:
    transformed = []
    storage_groups: dict[str, list[str]] = defaultdict(list)
    used_rows = 0
    data_sheet_count = 0
    bad_ed_rows = 0

    for sheet_name, rows, columns in sheets:
        rows = [dict(row) for row in rows]
        columns = list(columns)
        if is_data_sheet(sheet_name, columns):
            data_sheet_count += 1
            columns = insert_after(columns, "renamed_variable_name", "variable_name")
            columns = insert_after(columns, "harmonized_storage_type", "storage_type")
            if "renamed_variable_label" not in columns:
                columns = insert_after(columns, "renamed_variable_label", "variable_label")

            for row in rows:
                row.setdefault("renamed_variable_name", "")
                row.setdefault("harmonized_storage_type", "")
                row.setdefault("renamed_variable_label", "")

                if row.get("variable_name") == "bad_ed":
                    row["renamed_variable_label"] = BAD_ED_LABEL
                    bad_ed_rows += 1

                if is_used(row):
                    used_rows += 1
                    proposal = proposal_for_row(sheet_name, row)
                    row["renamed_variable_name"] = proposal
                    storage_groups[proposal].append(row.get("storage_type", ""))
                else:
                    row["renamed_variable_name"] = ""
                    row["harmonized_storage_type"] = ""

        transformed.append((sheet_name, rows, columns))

    group_storage = {
        name: harmonized_storage(name, storage_types)
        for name, storage_types in storage_groups.items()
    }

    final_sheets = []
    for sheet_name, rows, columns in transformed:
        if is_data_sheet(sheet_name, columns):
            for row in rows:
                if is_used(row):
                    row["harmonized_storage_type"] = group_storage[row["renamed_variable_name"]]
        final_sheets.append((sheet_name, rows, columns))

    summary = {
        "data_sheets": data_sheet_count,
        "used_rows": used_rows,
        "name_groups": len(storage_groups),
        "bad_ed_rows": bad_ed_rows,
    }
    return final_sheets, summary


def validate_sheets(sheets: list[tuple[str, list[dict[str, str]], list[str]]]) -> None:
    errors = []

    for sheet_name, rows, columns in sheets:
        if not is_data_sheet(sheet_name, columns):
            continue

        for required in ("renamed_variable_name", "harmonized_storage_type"):
            if required not in columns:
                errors.append(f"{sheet_name}: missing {required}")

        proposed_names: dict[str, list[str]] = defaultdict(list)
        for row in rows:
            variable_name = row.get("variable_name", "")
            proposed_name = row.get("renamed_variable_name", "")

            if variable_name == "bad_ed" and row.get("renamed_variable_label", "") != BAD_ED_LABEL:
                errors.append(f"{sheet_name}: bad_ed label was not normalized")

            if is_used(row):
                if not proposed_name:
                    errors.append(f"{sheet_name}:{variable_name}: missing renamed_variable_name")
                    continue
                if not SNAKE_CASE.match(proposed_name):
                    errors.append(f"{sheet_name}:{variable_name}: invalid proposed name {proposed_name}")
                if not row.get("harmonized_storage_type", ""):
                    errors.append(f"{sheet_name}:{variable_name}: missing harmonized_storage_type")
                proposed_names[proposed_name].append(variable_name)
            elif proposed_name:
                errors.append(f"{sheet_name}:{variable_name}: non-used row has renamed_variable_name")

        for proposed_name, original_names in proposed_names.items():
            if len(set(original_names)) > 1:
                originals = ", ".join(sorted(set(original_names)))
                errors.append(f"{sheet_name}: duplicate proposal {proposed_name} for {originals}")

    if errors:
        preview = "\n".join(errors[:40])
        extra = "" if len(errors) <= 40 else f"\n... {len(errors) - 40} more errors"
        raise ValueError(f"Validation failed:\n{preview}{extra}")


def backup_workbook(workbook_path: Path) -> Path:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = workbook_path.with_name(
        f"{workbook_path.stem}.before_rename_harmonization_{timestamp}{workbook_path.suffix}"
    )
    shutil.copy2(workbook_path, backup_path)
    return backup_path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--workbook",
        type=Path,
        default=DEFAULT_WORKBOOK,
        help=f"Workbook to update, default: {DEFAULT_WORKBOOK}",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate the transformed workbook without writing it.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    sheets = read_xlsx(args.workbook)
    transformed, summary = transform_sheets(sheets)
    validate_sheets(transformed)

    print(
        "Validated "
        f"{summary['used_rows']} used rows across {summary['data_sheets']} data sheets "
        f"and {summary['name_groups']} proposed-name groups."
    )
    print(f"Normalized bad_ed labels in {summary['bad_ed_rows']} rows.")

    if args.dry_run:
        print("Dry run only; workbook not written.")
        return

    backup_path = backup_workbook(args.workbook)
    write_xlsx(args.workbook, transformed)
    print(f"Backup written: {backup_path}")
    print(f"Workbook updated: {args.workbook}")


if __name__ == "__main__":
    main()
