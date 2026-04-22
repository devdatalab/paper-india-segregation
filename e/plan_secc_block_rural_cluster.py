from __future__ import annotations

import argparse
import re
from pathlib import Path

import pandas as pd

CLUSTER_NAME = "secc_block_rural"
CANONICAL_TARGET_FILE = "/dartfs/rc/lab/I/IEC/seg/clean/secc_rural_collapsed_block.dta"
CANONICAL_SCHEMA_ID = "schema_0068"
DEFAULT_METADATA_DIR = Path("/dartfs-hpc/scratch/siddiqui/seg_cleanup/metadata")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build schema-first harmonization maps for the secc_block_rural cluster."
    )
    parser.add_argument(
        "--metadata-dir",
        type=Path,
        default=DEFAULT_METADATA_DIR,
        help="Directory containing the existing registry CSV outputs.",
    )
    parser.add_argument(
        "--output-root",
        type=Path,
        default=None,
        help="Root directory for cluster_maps and harmonized_clusters outputs. Defaults to <metadata parent>.",
    )
    return parser.parse_args()


def load_inputs(metadata_dir: Path) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    registry = pd.read_csv(metadata_dir / "schema_registry_with_master_flags.csv")
    schema_summary = pd.read_csv(metadata_dir / "schema_summary.csv")
    master_detection = pd.read_csv(metadata_dir / "master_detection_report.csv")
    return registry, schema_summary, master_detection


def split_variable_list(raw: str) -> list[str]:
    if pd.isna(raw) or raw == "":
        return []
    return [token for token in str(raw).split(";") if token]


def build_schema_varlists(schema_summary: pd.DataFrame) -> dict[str, list[str]]:
    return {
        row.schema_id: split_variable_list(row.variable_list)
        for row in schema_summary.loc[:, ["schema_id", "variable_list"]].drop_duplicates().itertuples(
            index=False
        )
    }


def bundle_note(variable_name: str) -> str:
    match = re.match(r"^(ed\d+)(?:_|$)", variable_name)
    if not match:
        return "Add canonical variable as Stata missing."

    bundle = match.group(1)
    if bundle == "ed9999":
        return "Add missing ed9999 education-bucket bundle member as Stata missing."
    if bundle in {"ed2", "ed3", "ed4", "ed5", "ed6", "ed7"}:
        return f"Add missing {bundle} education-bucket bundle member as Stata missing."
    return "Add canonical variable as Stata missing."


def schema_change_mode(
    n_add_missing: int, n_rename: int, n_manual_review: int, n_extra_source_vars: int
) -> str:
    if n_rename > 0 or n_manual_review > 0 or n_extra_source_vars > 0:
        return "manual_review_needed"
    if n_add_missing == 0:
        return "no_change"
    return "add_missing_only"


def require_canonical_target(
    registry: pd.DataFrame, master_detection: pd.DataFrame, schema_varlists: dict[str, list[str]]
) -> list[str]:
    canonical_rows = registry.loc[registry["filename"].eq(CANONICAL_TARGET_FILE)]
    if canonical_rows.empty:
        raise ValueError(f"Canonical target file not found in registry: {CANONICAL_TARGET_FILE}")
    if len(canonical_rows) != 1:
        raise ValueError(f"Expected one canonical target row, found {len(canonical_rows)}")

    canonical_schema_id = canonical_rows.iloc[0]["schema_id"]
    if canonical_schema_id != CANONICAL_SCHEMA_ID:
        raise ValueError(
            f"Canonical target schema mismatch: expected {CANONICAL_SCHEMA_ID}, got {canonical_schema_id}"
        )

    master_row = master_detection.loc[
        master_detection["file_family"].eq(CLUSTER_NAME) & master_detection["is_selected_candidate"].eq(True)
    ]
    if master_row.empty:
        raise ValueError(f"No selected candidate master found for cluster {CLUSTER_NAME}")

    selected_target = master_row.iloc[0]["candidate_master_file"]
    if selected_target != CANONICAL_TARGET_FILE:
        raise ValueError(
            f"Selected candidate master mismatch: expected {CANONICAL_TARGET_FILE}, got {selected_target}"
        )

    return schema_varlists[CANONICAL_SCHEMA_ID]


def build_cluster_outputs(
    registry: pd.DataFrame, schema_summary: pd.DataFrame, canonical_vars: list[str]
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    cluster = registry.loc[
        registry["file_family"].eq(CLUSTER_NAME)
        & ~registry["likely_legacy"].fillna(False)
        & ~registry["filename"].eq(CANONICAL_TARGET_FILE)
    ].copy()

    if cluster.empty:
        raise ValueError(f"No non-legacy files found for cluster {CLUSTER_NAME}")

    schema_varlists = build_schema_varlists(schema_summary)
    canonical_varset = set(canonical_vars)

    action_rows: list[dict[str, object]] = []
    summary_rows: list[dict[str, object]] = []
    manual_review_rows: list[dict[str, object]] = []

    schema_counts = cluster["schema_id"].value_counts().sort_index().to_dict()

    for source_schema_id in sorted(schema_counts):
        source_vars = schema_varlists[source_schema_id]
        source_varset = set(source_vars)
        extra_source_vars = sorted(source_varset - canonical_varset)
        missing_canonical_vars = sorted(canonical_varset - source_varset, key=canonical_vars.index)

        for canonical_var in canonical_vars:
            if canonical_var in source_varset:
                action_rows.append(
                    {
                        "cluster_name": CLUSTER_NAME,
                        "source_schema_id": source_schema_id,
                        "canonical_schema_id": CANONICAL_SCHEMA_ID,
                        "canonical_var": canonical_var,
                        "source_var": canonical_var,
                        "action": "keep",
                        "notes": "Present in source schema.",
                        "n_files_using_source_schema": schema_counts[source_schema_id],
                    }
                )
            else:
                action_rows.append(
                    {
                        "cluster_name": CLUSTER_NAME,
                        "source_schema_id": source_schema_id,
                        "canonical_schema_id": CANONICAL_SCHEMA_ID,
                        "canonical_var": canonical_var,
                        "source_var": "",
                        "action": "add_missing",
                        "notes": bundle_note(canonical_var),
                        "n_files_using_source_schema": schema_counts[source_schema_id],
                    }
                )

        for extra_var in extra_source_vars:
            manual_review_rows.append(
                {
                    "cluster_name": CLUSTER_NAME,
                    "source_schema_id": source_schema_id,
                    "canonical_schema_id": CANONICAL_SCHEMA_ID,
                    "issue_type": "extra_source_var",
                    "canonical_var": "",
                    "source_var": extra_var,
                    "notes": "Unexpected source variable not present in canonical schema; fail cluster run until reviewed.",
                    "n_files_using_source_schema": schema_counts[source_schema_id],
                }
            )

        n_keep = len(source_vars) - len(extra_source_vars)
        n_add_missing = len(missing_canonical_vars)
        n_rename = 0
        n_manual_review = len(extra_source_vars)
        change_mode = schema_change_mode(
            n_add_missing=n_add_missing,
            n_rename=n_rename,
            n_manual_review=n_manual_review,
            n_extra_source_vars=len(extra_source_vars),
        )

        summary_rows.append(
            {
                "cluster_name": CLUSTER_NAME,
                "source_schema_id": source_schema_id,
                "canonical_schema_id": CANONICAL_SCHEMA_ID,
                "n_files_using_source_schema": schema_counts[source_schema_id],
                "n_source_vars": len(source_vars),
                "n_canonical_vars": len(canonical_vars),
                "n_keep": n_keep,
                "n_add_missing": n_add_missing,
                "n_rename": n_rename,
                "n_manual_review": n_manual_review,
                "n_extra_source_vars": len(extra_source_vars),
                "expected_changes_count": n_add_missing + n_rename + n_manual_review,
                "change_mode": change_mode,
                "missing_canonical_vars": ";".join(missing_canonical_vars),
                "extra_source_vars": ";".join(extra_source_vars),
            }
        )

    action_plan = pd.DataFrame(action_rows).sort_values(
        ["source_schema_id", "canonical_var"], ascending=[True, True]
    )
    diff_summary = pd.DataFrame(summary_rows).sort_values(
        ["expected_changes_count", "source_schema_id"], ascending=[True, True]
    )
    manual_review = pd.DataFrame(
        manual_review_rows,
        columns=[
            "cluster_name",
            "source_schema_id",
            "canonical_schema_id",
            "issue_type",
            "canonical_var",
            "source_var",
            "notes",
            "n_files_using_source_schema",
        ],
    )

    file_application_map = (
        cluster.loc[:, ["filename", "schema_id"]]
        .rename(columns={"schema_id": "source_schema_id"})
        .merge(
            diff_summary.loc[:, ["source_schema_id", "expected_changes_count"]],
            on="source_schema_id",
            how="left",
            validate="many_to_one",
        )
        .assign(action_plan_schema_id=lambda df: df["source_schema_id"])
        .loc[:, ["filename", "source_schema_id", "action_plan_schema_id", "expected_changes_count"]]
        .sort_values(["source_schema_id", "filename"], ascending=[True, True])
        .reset_index(drop=True)
    )

    return action_plan, diff_summary, manual_review, file_application_map


def main() -> None:
    args = parse_args()
    metadata_dir = args.metadata_dir.expanduser().resolve()
    output_root = (
        args.output_root.expanduser().resolve()
        if args.output_root is not None
        else metadata_dir.parent
    )
    cluster_maps_dir = output_root / "cluster_maps"
    cluster_maps_dir.mkdir(parents=True, exist_ok=True)

    registry, schema_summary, master_detection = load_inputs(metadata_dir)
    schema_varlists = build_schema_varlists(schema_summary)
    canonical_vars = require_canonical_target(
        registry=registry,
        master_detection=master_detection,
        schema_varlists=schema_varlists,
    )

    action_plan, diff_summary, manual_review, file_application_map = build_cluster_outputs(
        registry=registry,
        schema_summary=schema_summary,
        canonical_vars=canonical_vars,
    )

    action_path = cluster_maps_dir / f"{CLUSTER_NAME}_schema_action_plan.csv"
    diff_path = cluster_maps_dir / f"{CLUSTER_NAME}_schema_diff_summary.csv"
    manual_path = cluster_maps_dir / f"{CLUSTER_NAME}_manual_review.csv"
    file_map_path = cluster_maps_dir / f"{CLUSTER_NAME}_file_application_map.csv"

    action_plan.to_csv(action_path, index=False)
    diff_summary.to_csv(diff_path, index=False)
    manual_review.to_csv(manual_path, index=False)
    file_application_map.to_csv(file_map_path, index=False)

    print(f"Wrote schema action plan: {action_path}")
    print(f"Wrote schema diff summary: {diff_path}")
    print(f"Wrote manual review report: {manual_path}")
    print(f"Wrote file application map: {file_map_path}")


if __name__ == "__main__":
    main()
