from __future__ import annotations

import argparse
import re
from pathlib import Path

import pandas as pd

DEFAULT_METADATA_DIR = Path("/dartfs-hpc/scratch/siddiqui/seg_cleanup/metadata")

MASTER_MARKERS = ("collapsed", "blockdata", "villagedata", "towndata", "pooled", "appended")
GEOGRAPHY_PRIORITY = ("block", "ward", "town", "village", "subdistrict", "district", "city")
NON_GEOGRAPHIC_UNITS = ("household", "hh")
GENERIC_TOKENS = {
    "secc",
    "seg",
    "segregation",
    "ec",
    "clean",
    "data",
    "pooled",
    "collapsed",
    "appended",
    "blockdata",
    "villagedata",
    "towndata",
    "rural",
    "urban",
}
SCHEMA_RELATION_RANK = {
    "exact_match_family_schema": 4,
    "superset_of_modal_schema": 3,
    "subset_of_modal_schema": 2,
    "different": 1,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Annotate schema registry outputs with candidate master-file detection."
    )
    parser.add_argument(
        "--schema-registry",
        type=Path,
        default=DEFAULT_METADATA_DIR / "schema_registry.csv",
        help="Path to schema_registry.csv.",
    )
    parser.add_argument(
        "--family-summary",
        type=Path,
        default=DEFAULT_METADATA_DIR / "family_summary.csv",
        help="Path to family_summary.csv.",
    )
    parser.add_argument(
        "--schema-summary",
        type=Path,
        default=DEFAULT_METADATA_DIR / "schema_summary.csv",
        help="Path to schema_summary.csv.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="Directory for annotated outputs. Defaults to the schema_registry parent.",
    )
    return parser.parse_args()


def tokenize_name(name: str) -> list[str]:
    tokens = [token for token in re.split(r"[_\W]+", str(name).lower()) if token]
    expanded: list[str] = []
    for token in tokens:
        if token.isdigit():
            continue
        expanded.append(token)
        if token == "blockdata":
            expanded.append("block")
        elif token == "villagedata":
            expanded.append("village")
        elif token == "towndata":
            expanded.append("town")
    return expanded


def extract_sector(name: str) -> str:
    tokens = set(tokenize_name(name))
    if "rural" in tokens:
        return "rural"
    if "urban" in tokens:
        return "urban"
    return ""


def extract_unit(name: str) -> str:
    tokens = tokenize_name(name)
    token_set = set(tokens)
    for unit in GEOGRAPHY_PRIORITY:
        if unit in token_set:
            return unit
    for unit in NON_GEOGRAPHIC_UNITS:
        if unit in token_set:
            return unit
    return ""


def looks_like_master_candidate(file_family: str) -> bool:
    family_lower = str(file_family).lower()
    if not any(marker in family_lower for marker in MASTER_MARKERS):
        return False
    if family_lower.endswith("_key"):
        return False
    if re.search(r"_\d+$", family_lower):
        return False
    return True


def marker_rank(file_family: str) -> int:
    family_lower = str(file_family).lower()
    if "collapsed" in family_lower:
        return 6
    if "blockdata" in family_lower:
        return 5
    if "villagedata" in family_lower:
        return 4
    if "towndata" in family_lower:
        return 3
    if "pooled" in family_lower:
        return 2
    if "appended" in family_lower:
        return 1
    return 0


def specific_token_overlap(left: str, right: str) -> int:
    left_tokens = {token for token in tokenize_name(left) if token not in GENERIC_TOKENS}
    right_tokens = {token for token in tokenize_name(right) if token not in GENERIC_TOKENS}
    return len(left_tokens & right_tokens)


def schema_relation(
    candidate_schema_id: str,
    family_schema_ids: set[str],
    candidate_vars: set[str],
    modal_vars: set[str],
) -> str:
    if candidate_schema_id in family_schema_ids:
        return "exact_match_family_schema"
    if modal_vars < candidate_vars:
        return "superset_of_modal_schema"
    if modal_vars > candidate_vars:
        return "subset_of_modal_schema"
    return "different"


def build_schema_varsets(schema_summary: pd.DataFrame) -> dict[str, set[str]]:
    varsets: dict[str, set[str]] = {}
    for row in schema_summary.loc[:, ["schema_id", "variable_list"]].drop_duplicates().itertuples(
        index=False
    ):
        raw = "" if pd.isna(row.variable_list) else str(row.variable_list)
        varsets[row.schema_id] = {token for token in raw.split(";") if token}
    return varsets


def family_rollup(schema_registry: pd.DataFrame) -> pd.DataFrame:
    nonlegacy = schema_registry.loc[~schema_registry["likely_legacy"].fillna(False)].copy()

    counts = (
        nonlegacy.groupby("file_family", as_index=False)
        .agg(
            family_n_obs_sum=("n_obs", "sum"),
            family_n_files_nonlegacy=("filename", "size"),
        )
        .reset_index(drop=True)
    )

    modal = (
        nonlegacy.groupby(["file_family", "schema_id"], as_index=False)
        .size()
        .rename(columns={"size": "schema_files"})
        .sort_values(["file_family", "schema_files", "schema_id"], ascending=[True, False, True])
        .drop_duplicates("file_family", keep="first")
        .rename(columns={"schema_id": "family_modal_schema_id", "schema_files": "family_modal_schema_files"})
    )

    schema_sets = (
        nonlegacy.groupby("file_family")["schema_id"]
        .agg(lambda values: sorted(set(values)))
        .rename("family_schema_ids")
        .reset_index()
    )

    rollup = counts.merge(modal, on="file_family", how="left", validate="one_to_one")
    rollup = rollup.merge(schema_sets, on="file_family", how="left", validate="one_to_one")
    return rollup


def build_candidate_pool(schema_registry: pd.DataFrame) -> pd.DataFrame:
    clean = schema_registry.loc[
        schema_registry["top_level_section"].eq("clean")
        & ~schema_registry["likely_legacy"].fillna(False)
    ].copy()
    clean = clean.loc[clean["file_family"].map(looks_like_master_candidate)].copy()
    clean["candidate_sector"] = clean["file_family"].map(extract_sector)
    clean["candidate_unit"] = clean["file_family"].map(extract_unit)
    clean["candidate_marker_rank"] = clean["file_family"].map(marker_rank)
    return clean.reset_index(drop=True)


def candidate_score(
    family_row: pd.Series,
    candidate_row: pd.Series,
    relation: str,
    rowcount_match: bool,
) -> int | None:
    family_sector = family_row["family_sector"]
    candidate_sector = candidate_row["candidate_sector"]
    if family_sector and candidate_sector and family_sector != candidate_sector:
        return None

    family_unit = family_row["family_unit"]
    candidate_unit = candidate_row["candidate_unit"]
    if family_unit and candidate_unit and family_unit != candidate_unit:
        return None
    if family_unit and not candidate_unit:
        return None

    score = 0
    if family_sector and candidate_sector and family_sector == candidate_sector:
        score += 30
    if family_unit and candidate_unit and family_unit == candidate_unit:
        score += 40
    if rowcount_match:
        score += 25

    score += 10 * SCHEMA_RELATION_RANK[relation]
    score += 6 * int(candidate_row["candidate_marker_rank"])

    overlap = specific_token_overlap(family_row["file_family"], candidate_row["file_family"])
    score += min(overlap * 3, 12)

    if family_unit == "block" and "collapsed" in str(candidate_row["file_family"]).lower():
        score += 8
    if str(family_row["file_family"]).startswith("secc_") and str(candidate_row["file_family"]).startswith(
        "secc_"
    ):
        score += 4

    return score if score >= 70 else None


def build_master_notes(
    relation: str,
    rowcount_match: bool,
    alternative_count: int,
    candidate_row: pd.Series | None,
) -> str:
    if candidate_row is None:
        return "No plausible non-legacy clean pooled file matched the family sector and geography."

    relation_text = {
        "exact_match_family_schema": "candidate schema exactly matches one family schema",
        "superset_of_modal_schema": "candidate schema is a superset of the modal shard schema",
        "subset_of_modal_schema": "candidate schema is a subset of the modal shard schema",
        "different": "candidate schema differs from the modal shard schema",
    }[relation]

    row_text = "exact shard rowcount match" if rowcount_match else "rowcount does not exactly match the shard total"

    master_type = "clean collapsed/block-style pooled file"
    family_name = str(candidate_row["file_family"]).lower()
    if "blockdata" in family_name:
        master_type = "clean blockdata-style pooled file"
    elif "villagedata" in family_name or "towndata" in family_name:
        master_type = "clean geography-data pooled file"
    elif "pooled" in family_name:
        master_type = "clean pooled file"
    elif "appended" in family_name:
        master_type = "clean appended file"

    alt_text = ""
    if alternative_count > 0:
        alt_text = f"; preferred over {alternative_count} alternative plausible match(es)"

    return f"{master_type}; {row_text}; {relation_text}{alt_text}."


def coerce_schema_id_list(value: object) -> list[str]:
    if isinstance(value, list):
        return [str(item) for item in value]
    if isinstance(value, tuple):
        return [str(item) for item in value]
    if pd.isna(value):
        return []
    return [str(value)]


def detect_master_candidates(
    schema_registry: pd.DataFrame,
    family_summary: pd.DataFrame,
    schema_summary: pd.DataFrame,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    schema_varsets = build_schema_varsets(schema_summary)
    rollup = family_rollup(schema_registry)

    families = family_summary.merge(rollup, on="file_family", how="left", validate="one_to_one")
    families["family_n_obs_sum"] = families["family_n_obs_sum"].fillna(0)
    families["family_n_files_nonlegacy"] = families["family_n_files_nonlegacy"].fillna(0)
    families["family_modal_schema_id"] = families["family_modal_schema_id"].fillna(
        families["modal_schema_id"]
    )
    families["family_schema_ids"] = families["family_schema_ids"].map(coerce_schema_id_list)
    families["family_sector"] = families["file_family"].map(extract_sector)
    families["family_unit"] = families["file_family"].map(extract_unit)
    families["is_shard_family"] = (
        families["n_files"].gt(1)
        & families["top_level_sections"].str.contains("partitioned", na=False)
        & families["family_unit"].isin(GEOGRAPHY_PRIORITY)
    )

    candidate_pool = build_candidate_pool(schema_registry)
    report_rows: list[dict[str, object]] = []
    selected_rows: list[dict[str, object]] = []

    for family_row in families.itertuples(index=False):
        family_schema_ids = set(family_row.family_schema_ids)
        modal_schema_id = family_row.family_modal_schema_id
        modal_vars = schema_varsets.get(modal_schema_id, set())

        if not family_row.is_shard_family:
            selected_rows.append(
                {
                    "file_family": family_row.file_family,
                    "family_n_obs_sum": family_row.family_n_obs_sum,
                    "candidate_master_file": pd.NA,
                    "candidate_master_n_obs": pd.NA,
                    "rowcount_match": pd.NA,
                    "schema_relation_to_master": pd.NA,
                    "master_status": pd.NA,
                    "master_notes": pd.NA,
                }
            )
            continue

        family_candidates: list[dict[str, object]] = []
        for candidate_row in candidate_pool.itertuples(index=False):
            relation = schema_relation(
                candidate_schema_id=candidate_row.schema_id,
                family_schema_ids=family_schema_ids,
                candidate_vars=schema_varsets.get(candidate_row.schema_id, set()),
                modal_vars=modal_vars,
            )
            rowcount_match = bool(candidate_row.n_obs == family_row.family_n_obs_sum)
            score = candidate_score(
                family_row=pd.Series(family_row._asdict()),
                candidate_row=pd.Series(candidate_row._asdict()),
                relation=relation,
                rowcount_match=rowcount_match,
            )
            if score is None:
                continue

            family_candidates.append(
                {
                    "file_family": family_row.file_family,
                    "family_n_files": family_row.n_files,
                    "family_n_obs_sum": family_row.family_n_obs_sum,
                    "family_modal_schema_id": modal_schema_id,
                    "family_schema_count": family_row.n_unique_schemas,
                    "candidate_master_file": candidate_row.filename,
                    "candidate_master_family": candidate_row.file_family,
                    "candidate_master_n_obs": candidate_row.n_obs,
                    "candidate_master_schema_id": candidate_row.schema_id,
                    "rowcount_match": rowcount_match,
                    "schema_relation_to_master": relation,
                    "candidate_score": score,
                    "candidate_marker_rank": candidate_row.candidate_marker_rank,
                    "master_status": "candidate",
                }
            )

        if not family_candidates:
            note = build_master_notes(
                relation="different",
                rowcount_match=False,
                alternative_count=0,
                candidate_row=None,
            )
            selected_rows.append(
                {
                    "file_family": family_row.file_family,
                    "family_n_obs_sum": family_row.family_n_obs_sum,
                    "candidate_master_file": pd.NA,
                    "candidate_master_n_obs": pd.NA,
                    "rowcount_match": pd.NA,
                    "schema_relation_to_master": pd.NA,
                    "master_status": pd.NA,
                    "master_notes": note,
                }
            )
            report_rows.append(
                {
                    "file_family": family_row.file_family,
                    "family_n_files": family_row.n_files,
                    "family_n_obs_sum": family_row.family_n_obs_sum,
                    "family_modal_schema_id": modal_schema_id,
                    "family_schema_count": family_row.n_unique_schemas,
                    "candidate_master_file": pd.NA,
                    "candidate_master_family": pd.NA,
                    "candidate_master_n_obs": pd.NA,
                    "candidate_master_schema_id": pd.NA,
                    "rowcount_match": pd.NA,
                    "schema_relation_to_master": pd.NA,
                    "candidate_score": pd.NA,
                    "candidate_marker_rank": pd.NA,
                    "is_selected_candidate": False,
                    "master_status": pd.NA,
                    "master_notes": note,
                }
            )
            continue

        family_candidates = sorted(
            family_candidates,
            key=lambda row: (
                row["candidate_score"],
                int(bool(row["rowcount_match"])),
                SCHEMA_RELATION_RANK[row["schema_relation_to_master"]],
                row["candidate_marker_rank"],
                -len(str(row["candidate_master_file"])),
                str(row["candidate_master_file"]),
            ),
            reverse=True,
        )
        selected = family_candidates[0]
        alternative_count = len(family_candidates) - 1
        selected_note = build_master_notes(
            relation=str(selected["schema_relation_to_master"]),
            rowcount_match=bool(selected["rowcount_match"]),
            alternative_count=alternative_count,
            candidate_row=pd.Series(selected),
        )

        selected_rows.append(
            {
                "file_family": family_row.file_family,
                "family_n_obs_sum": family_row.family_n_obs_sum,
                "candidate_master_file": selected["candidate_master_file"],
                "candidate_master_n_obs": selected["candidate_master_n_obs"],
                "rowcount_match": selected["rowcount_match"],
                "schema_relation_to_master": selected["schema_relation_to_master"],
                "master_status": "candidate",
                "master_notes": selected_note,
            }
        )

        for idx, candidate in enumerate(family_candidates):
            report_rows.append(
                {
                    **candidate,
                    "is_selected_candidate": idx == 0,
                    "master_notes": selected_note if idx == 0 else "",
                }
            )

    selected_df = pd.DataFrame(selected_rows)
    report_df = pd.DataFrame(report_rows)
    if not report_df.empty:
        report_df = report_df.sort_values(
            ["file_family", "is_selected_candidate", "candidate_score", "candidate_master_file"],
            ascending=[True, False, False, True],
        ).reset_index(drop=True)
    return selected_df, report_df


def annotate_outputs(
    schema_registry: pd.DataFrame,
    family_summary: pd.DataFrame,
    selected: pd.DataFrame,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    family_annotated = family_summary.merge(selected, on="file_family", how="left", validate="one_to_one")

    master_lookup = (
        family_annotated.loc[family_annotated["candidate_master_file"].notna(), ["candidate_master_file", "file_family"]]
        .groupby("candidate_master_file")["file_family"]
        .agg(lambda values: ";".join(sorted(values)))
        .rename("master_for_family")
        .reset_index()
    )

    registry_annotated = schema_registry.merge(
        master_lookup,
        left_on="filename",
        right_on="candidate_master_file",
        how="left",
        validate="many_to_one",
    )
    registry_annotated["is_candidate_master"] = registry_annotated["master_for_family"].notna()
    registry_annotated["is_verified_master"] = False
    registry_annotated["master_status"] = registry_annotated["is_candidate_master"].map(
        lambda flag: "candidate" if flag else pd.NA
    )
    registry_annotated = registry_annotated.drop(columns=["candidate_master_file"])

    return family_annotated, registry_annotated


def main() -> None:
    args = parse_args()

    schema_registry_path = args.schema_registry.expanduser().resolve()
    family_summary_path = args.family_summary.expanduser().resolve()
    schema_summary_path = args.schema_summary.expanduser().resolve()
    output_dir = (
        args.output_dir.expanduser().resolve()
        if args.output_dir is not None
        else schema_registry_path.parent
    )
    output_dir.mkdir(parents=True, exist_ok=True)

    schema_registry = pd.read_csv(schema_registry_path)
    family_summary = pd.read_csv(family_summary_path)
    schema_summary = pd.read_csv(schema_summary_path)

    selected, report = detect_master_candidates(
        schema_registry=schema_registry,
        family_summary=family_summary,
        schema_summary=schema_summary,
    )
    family_annotated, registry_annotated = annotate_outputs(
        schema_registry=schema_registry,
        family_summary=family_summary,
        selected=selected,
    )

    family_output = output_dir / "family_summary_with_master_flags.csv"
    registry_output = output_dir / "schema_registry_with_master_flags.csv"
    report_output = output_dir / "master_detection_report.csv"

    family_annotated.to_csv(family_output, index=False)
    registry_annotated.to_csv(registry_output, index=False)
    report.to_csv(report_output, index=False)

    print(f"Wrote family summary with master flags: {family_output}")
    print(f"Wrote schema registry with master flags: {registry_output}")
    print(f"Wrote master detection report: {report_output}")


if __name__ == "__main__":
    main()
