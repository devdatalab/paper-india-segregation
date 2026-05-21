#!/usr/bin/env python
"""Add a label-aware variable-name review column to the active workbook."""

from __future__ import annotations

import argparse
import shutil
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from e.apply_variable_listing_rename_harmonization import (
    SNAKE_CASE,
    harmonized_storage,
    insert_after,
    is_data_sheet,
    is_used,
    proposal_for_row,
)
from inventory.variable_listing_utils import read_xlsx, write_xlsx


DEFAULT_WORKBOOK = Path("/dartfs-hpc/scratch/siddiqui/variable_listing.xlsx")
LABEL_AWARE_NAME = "label_aware_renamed_variable_name"
LABEL_AWARE_STORAGE = "label_aware_harmonized_storage_type"
BAD_RENAMES = {
    "bad_ed": "secc_missing_education_population",
    "bad_sc": "secc_missing_sc_classification_population",
    "bad_muslim": "secc_missing_muslim_classification_population",
}


LABEL_AWARE_GLOBAL_RENAMES = {
    "__missing_file__": None,
    "any_event": "violence_any_event",
    "bcut": "us_census_tract_black_share_bin",
    "block_group": "seg_block_group_min_population_threshold",
    "block_no": "seg_block_group_id",
    "block_pop": "secc_block_classified_population",
    "block_pop_muslim": "secc_block_muslim_population",
    "block_pop_nonscmuslim": "secc_block_non_sc_non_muslim_population",
    "block_pop_sc": "secc_block_sc_population",
    "cbsatitle": "us_census_cbsa_name",
    "city_origin_year": "pc11_town_origin_year",
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
    "event_count": "violence_event_count",
    "fips_code": "us_census_county_fips_id",
    "fipscountycode": "us_census_county_fips_suffix_id",
    "fipsstatecode": "us_census_state_fips_id",
    "geometry": "pc11_gis_geometry",
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
    "mean_muslim_dissim": "secc_muslim_weighted_mean_urban_town_dissimilarity",
    "mean_muslim_iso": "secc_muslim_weighted_mean_urban_town_isolation",
    "mean_pop": "seg_block_group_mean_population_estimate",
    "mean_sc_dissim": "secc_sc_weighted_mean_urban_town_dissimilarity",
    "mean_sc_iso": "secc_sc_weighted_mean_urban_town_isolation",
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
    "non_rel_event_count": "violence_non_religious_event_count",
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
    "pc11_sector": "pc11_place_sector",
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
    "religious_event_count": "violence_religious_event_count",
    "rural_cons_gini": "secc_rural_consumption_gini",
    "rural_land_gini": "secc_rural_land_gini",
    "sc_ed_gap": "secc_sc_education_gap",
    "sc_job_share": "ec13_sc_job_share",
    "sc_ln_cons_gap": "secc_sc_log_consumption_gap",
    "sc_pop_share": "secc_city_sc_population_share",
    "sec_pc": "pc11_secondary_schools_per_100k",
    "secondary": "ec13_block_secondary_school_count",
    "sector": "seg_sector",
    "share": "us_census_tract_black_share_bin_midpoint",
    "shrid": "shrug_id",
    "subdistrict": "pc11_subdistrict_composite_id",
    "total_pop": "pc01_hb_total_population",
    "town": "shrug_town_id",
    "town_cons_gini": "secc_town_consumption_gini",
    "town_name_pc01_pdf": "pc01_pdf_town_name",
    "town_name_pc11_pdf": "pc11_pdf_town_name",
    "tpop_b": "us_census_black_only_population_share_in_tract_bin",
    "tract_black_pop": "us_census_tract_black_population",
    "tract_black_prop": "us_census_tract_black_share",
    "tract_blackonly_pop": "us_census_tract_black_only_population",
    "tract_nonblack_pop": "us_census_tract_nonblack_population",
    "tract_total_pop_bw": "us_census_tract_black_white_population",
    "wat_source_home": "secc_water_source_at_home_share",
}


def is_bad_row(row: dict[str, str]) -> bool:
    return row.get("variable_name", "") in BAD_RENAMES


def is_eligible(row: dict[str, str]) -> bool:
    return is_used(row) or is_bad_row(row)


def label_text(row: dict[str, str]) -> str:
    return (row.get("renamed_variable_label") or row.get("variable_label") or "").lower()


def sheet_stem(sheet_name: str) -> str:
    return sheet_name.removesuffix(".dta").replace(".", "_").strip("_")


def file_placeholder_name(sheet_name: str) -> str:
    stem = sheet_stem(sheet_name).replace("-", "_")
    if sheet_name.endswith(".prj"):
        return f"{stem}_projection_file"
    if sheet_name.endswith(".shx"):
        return f"{stem}_shape_index_file"
    return f"{stem}_file_placeholder"


def missing_file_name(sheet_name: str) -> str:
    return f"{sheet_stem(sheet_name)}_missing_file".replace("-", "_")


def geo_from_label(row: dict[str, str], sheet_name: str) -> str:
    text = label_text(row)
    if "district mean rural subdistrict" in text:
        return "district_mean_rural_subdistrict"
    if "district mean urban town" in text:
        return "district_mean_urban_town"
    if "subdistrict" in text or "rural" in sheet_name:
        return "subdistrict"
    if "town" in text or "urban" in sheet_name or sheet_name == "seg_correlates.dta":
        return "town"
    return "city"


def segregation_measure_name(sheet_name: str, row: dict[str, str]) -> str | None:
    variable_name = row.get("variable_name", "")
    parts = variable_name.split("_")
    if len(parts) < 3 or parts[0] != "city":
        return None
    measure_map = {"dissim": "dissimilarity", "iso": "isolation"}
    if parts[1] not in measure_map:
        return None
    group = parts[2]
    if group not in {"sc", "muslim"}:
        return None
    suffix = ""
    if len(parts) == 4 and parts[3] in {"r", "u"}:
        suffix = "_rural_subdistrict" if parts[3] == "r" else "_urban_town"
        return f"secc_district_mean{suffix}_{group}_{measure_map[parts[1]]}"
    geo = geo_from_label(row, sheet_name)
    return f"secc_{geo}_{group}_{measure_map[parts[1]]}"


def sheet_aware_name(sheet_name: str, row: dict[str, str]) -> str | None:
    variable_name = row.get("variable_name", "")
    if variable_name == "__file__":
        return file_placeholder_name(sheet_name)
    if variable_name == "__missing_file__":
        return missing_file_name(sheet_name)
    if variable_name in BAD_RENAMES:
        return BAD_RENAMES[variable_name]

    segregation_name = segregation_measure_name(sheet_name, row)
    if segregation_name:
        return segregation_name

    if variable_name == "city_pop":
        return "secc_city_classified_population"

    if variable_name == "hh":
        if sheet_name.startswith("segregation_citydata_"):
            return "secc_city_household_count"
        return "secc_block_household_count"

    if variable_name in {"closed_drain", "wat_source_home", "light_source_elec"}:
        base = LABEL_AWARE_GLOBAL_RENAMES[variable_name]
        if sheet_name.startswith("segregation_citydata_"):
            return base.replace("secc_", "secc_city_", 1)
        return base.replace("secc_", "secc_block_", 1)

    if variable_name == "slum":
        if sheet_name.startswith("segregation_blockdata_"):
            return "secc_block_slum_share_or_indicator"
        return "secc_city_slum_share_or_indicator"

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
        group = variable_name.removesuffix("_share")
        if sheet_name.startswith("segregation_citydata_"):
            return f"secc_city_{group}_population_share"
        return f"secc_block_{group}_population_share"

    if variable_name == "city_pop_pc11":
        if sheet_name.startswith("segregation_citydata_rural_"):
            return "pc11_vd_subdistrict_population"
        return "pc11_td_town_population"

    if variable_name == "log_city_pop_pc11":
        if sheet_name.startswith("segregation_citydata_rural_"):
            return "pc11_log_vd_subdistrict_population"
        return "pc11_log_td_town_population"

    if sheet_name.startswith("segregation_citydata_rural_"):
        rural_vd = {
            "pc11_vd_all_hosp": "pc11_vd_subdistrict_allopathic_hospital_count",
            "pc11_vd_area": "pc11_vd_subdistrict_area",
            "pc11_vd_m_sch": "pc11_vd_subdistrict_middle_school_count",
            "pc11_vd_p_sch": "pc11_vd_subdistrict_primary_school_count",
            "pc11_vd_s_sch": "pc11_vd_subdistrict_secondary_school_count",
        }
        if variable_name in rural_vd:
            return rural_vd[variable_name]

    if variable_name in LABEL_AWARE_GLOBAL_RENAMES:
        candidate = LABEL_AWARE_GLOBAL_RENAMES[variable_name]
        if candidate:
            return candidate

    return row.get("renamed_variable_name") or proposal_for_row(sheet_name, row)


def transform_sheets(
    sheets: list[tuple[str, list[dict[str, str]], list[str]]],
) -> tuple[list[tuple[str, list[dict[str, str]], list[str]]], dict[str, int]]:
    transformed = []
    storage_groups: dict[str, list[str]] = defaultdict(list)
    counts = defaultdict(int)

    for sheet_name, rows, columns in sheets:
        rows = [dict(row) for row in rows]
        columns = list(columns)
        if is_data_sheet(sheet_name, columns):
            counts["data_sheets"] += 1
            columns = insert_after(columns, LABEL_AWARE_NAME, "renamed_variable_name")
            columns = insert_after(columns, LABEL_AWARE_STORAGE, "harmonized_storage_type")

            for row in rows:
                row.setdefault(LABEL_AWARE_NAME, "")
                row.setdefault(LABEL_AWARE_STORAGE, "")

                if is_eligible(row):
                    proposed_name = sheet_aware_name(sheet_name, row)
                    row[LABEL_AWARE_NAME] = proposed_name
                    storage_groups[proposed_name].append(row.get("storage_type", ""))
                    counts["eligible_rows"] += 1
                    counts["used_rows"] += int(is_used(row))
                    counts["bad_rows"] += int(is_bad_row(row))
                else:
                    row[LABEL_AWARE_NAME] = ""
                    row[LABEL_AWARE_STORAGE] = ""

        transformed.append((sheet_name, rows, columns))

    group_storage = {
        name: label_aware_harmonized_storage(name, storage_types)
        for name, storage_types in storage_groups.items()
    }

    final_sheets = []
    for sheet_name, rows, columns in transformed:
        if is_data_sheet(sheet_name, columns):
            for row in rows:
                if is_eligible(row):
                    row[LABEL_AWARE_STORAGE] = group_storage[row[LABEL_AWARE_NAME]]
        final_sheets.append((sheet_name, rows, columns))

    counts["name_groups"] = len(storage_groups)
    return final_sheets, dict(counts)


def label_aware_harmonized_storage(name: str, storage_types: list[str]) -> str:
    if name.endswith("_estimate"):
        clean_storages = {storage.strip() for storage in storage_types if storage.strip()}
        return "double" if "double" in clean_storages else "float"
    return harmonized_storage(name, storage_types)


def validate_sheets(sheets: list[tuple[str, list[dict[str, str]], list[str]]]) -> None:
    errors = []

    for sheet_name, rows, columns in sheets:
        if not is_data_sheet(sheet_name, columns):
            continue

        for required in (LABEL_AWARE_NAME, LABEL_AWARE_STORAGE):
            if required not in columns:
                errors.append(f"{sheet_name}: missing {required}")

        proposed_names: dict[str, list[str]] = defaultdict(list)
        for row in rows:
            variable_name = row.get("variable_name", "")
            proposed_name = row.get(LABEL_AWARE_NAME, "")

            if is_eligible(row):
                if not proposed_name:
                    errors.append(f"{sheet_name}:{variable_name}: missing {LABEL_AWARE_NAME}")
                    continue
                if not SNAKE_CASE.match(proposed_name):
                    errors.append(f"{sheet_name}:{variable_name}: invalid name {proposed_name}")
                if not row.get(LABEL_AWARE_STORAGE, ""):
                    errors.append(f"{sheet_name}:{variable_name}: missing {LABEL_AWARE_STORAGE}")
                proposed_names[proposed_name].append(variable_name)
            elif proposed_name:
                errors.append(f"{sheet_name}:{variable_name}: non-eligible row has {LABEL_AWARE_NAME}")

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
        f"{workbook_path.stem}.before_label_aware_rename_review_{timestamp}{workbook_path.suffix}"
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
        help="Validate transformed workbook without writing.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    transformed, summary = transform_sheets(read_xlsx(args.workbook))
    validate_sheets(transformed)
    print(
        "Validated "
        f"{summary.get('eligible_rows', 0)} eligible rows "
        f"({summary.get('used_rows', 0)} used rows, {summary.get('bad_rows', 0)} bad_* rows) "
        f"across {summary.get('data_sheets', 0)} data sheets and "
        f"{summary.get('name_groups', 0)} proposed-name groups."
    )

    if args.dry_run:
        print("Dry run only; workbook not written.")
        return

    backup_path = backup_workbook(args.workbook)
    write_xlsx(args.workbook, transformed)
    print(f"Backup written: {backup_path}")
    print(f"Workbook updated: {args.workbook}")


if __name__ == "__main__":
    main()
