from __future__ import annotations

import argparse
import re
from pathlib import Path, PurePosixPath

import pandas as pd

DEFAULT_INVENTORY = Path("/dartfs-hpc/scratch/siddiqui/seg_cleanup/segdata_file_inventory.csv")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build a schema registry from segdata_file_inventory.csv."
    )
    parser.add_argument(
        "--inventory",
        type=Path,
        default=DEFAULT_INVENTORY,
        help="Path to segdata_file_inventory.csv.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="Directory for metadata outputs. Defaults to <inventory parent>/metadata.",
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


def infer_file_family(basename: str, top_level_section: str) -> str:
    stem = re.sub(r"\.dta$", "", basename, flags=re.IGNORECASE)
    tokens = stem.split("_")

    # In partitioned data, 4/5 digit tokens are typically geographic partition codes.
    # Outside partitioned folders, numeric suffixes often mean thresholds or years instead.
    if top_level_section == "partitioned":
        for idx in range(len(tokens) - 1, -1, -1):
            if re.fullmatch(r"\d{4,5}", tokens[idx]):
                return "_".join(tokens[:idx] + tokens[idx + 1 :]) or stem

    return stem


def legacy_reason(filename: str) -> str:
    reasons: list[str] = []
    if "old-2020" in filename:
        reasons.append("old-2020")
    if "/old/" in filename:
        reasons.append("/old/")
    if "clean/nbd_sizes_old" in filename:
        reasons.append("clean/nbd_sizes_old")
    return ";".join(reasons)


def build_schema_ids(df: pd.DataFrame) -> pd.DataFrame:
    unique_variable_lists = sorted(df["variable_list"].fillna("").unique())
    schema_map = {
        variable_list: f"schema_{idx:04d}"
        for idx, variable_list in enumerate(unique_variable_lists, start=1)
    }
    df["schema_id"] = df["variable_list"].fillna("").map(schema_map)
    return df


def modal_schema_stats(group: pd.DataFrame) -> pd.Series:
    counts = (
        group["schema_id"]
        .value_counts(dropna=False)
        .rename_axis("schema_id")
        .reset_index(name="n_files")
        .sort_values(["n_files", "schema_id"], ascending=[False, True])
        .reset_index(drop=True)
    )
    modal_schema_id = counts.loc[0, "schema_id"]
    modal_schema_n_files = int(counts.loc[0, "n_files"])
    return pd.Series(
        {
            "n_files": int(len(group)),
            "n_unique_schemas": int(group["schema_id"].nunique(dropna=False)),
            "modal_schema_id": modal_schema_id,
            "modal_schema_n_files": modal_schema_n_files,
            "modal_schema_share": modal_schema_n_files / len(group),
        }
    )


def build_duplicate_basename_report(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    basename_dirs = (
        df.groupby("basename", as_index=False)
        .agg(
            n_files=("filename", "size"),
            n_directories=("relative_dir", "nunique"),
            directories=("relative_dir", lambda s: ";".join(sorted(set(filter(None, s))))),
            top_level_sections=(
                "top_level_section",
                lambda s: ";".join(sorted(set(filter(None, s)))),
            ),
            filenames=("filename", lambda s: ";".join(sorted(s))),
        )
    )
    duplicate_report = (
        basename_dirs.loc[basename_dirs["n_directories"] > 1]
        .sort_values(["n_directories", "basename"], ascending=[False, True])
        .reset_index(drop=True)
    )
    df = df.merge(
        basename_dirs.loc[:, ["basename", "n_directories"]],
        on="basename",
        how="left",
        validate="many_to_one",
    )
    df["duplicate_basename_across_dirs"] = df["n_directories"].fillna(0).gt(1)
    return df, duplicate_report


def build_family_summary(df: pd.DataFrame) -> pd.DataFrame:
    family_core = (
        df.groupby("file_family", as_index=False)
        .apply(modal_schema_stats, include_groups=False)
        .reset_index(drop=True)
    )
    family_context = (
        df.groupby("file_family", as_index=False)
        .agg(
            top_level_sections=(
                "top_level_section",
                lambda s: ";".join(sorted(set(filter(None, s)))),
            ),
            subfolders=("subfolder", lambda s: ";".join(sorted(set(filter(None, s))))),
            legacy_file_count=("likely_legacy", "sum"),
            example_file=("filename", "first"),
        )
    )
    family_summary = family_core.merge(
        family_context, on="file_family", how="left", validate="one_to_one"
    )
    family_summary["legacy_file_share"] = (
        family_summary["legacy_file_count"] / family_summary["n_files"]
    )
    return family_summary.sort_values(
        ["n_files", "file_family"], ascending=[False, True]
    ).reset_index(drop=True)


def build_schema_summary(df: pd.DataFrame) -> pd.DataFrame:
    schema_summary = (
        df.groupby(["schema_id", "variable_list"], as_index=False)
        .agg(
            n_files=("filename", "size"),
            n_families=("file_family", "nunique"),
            n_top_level_sections=("top_level_section", "nunique"),
            n_vars=("n_vars", "first"),
            example_file=("filename", "first"),
        )
        .sort_values(["n_files", "schema_id"], ascending=[False, True])
        .reset_index(drop=True)
    )
    return schema_summary


def main() -> None:
    args = parse_args()
    inventory_path = args.inventory.expanduser().resolve()
    output_dir = (
        args.output_dir.expanduser().resolve()
        if args.output_dir is not None
        else inventory_path.parent / "metadata"
    )
    output_dir.mkdir(parents=True, exist_ok=True)

    inventory = pd.read_csv(inventory_path)
    if "duplicate_group" in inventory.columns:
        inventory = inventory.rename(columns={"duplicate_group": "inventory_duplicate_group"})

    parsed_fields = inventory["filename"].apply(parse_filename_fields).apply(pd.Series)
    registry = pd.concat([inventory, parsed_fields], axis=1)
    registry["file_family"] = registry.apply(
        lambda row: infer_file_family(
            basename=row["basename"], top_level_section=row["top_level_section"]
        ),
        axis=1,
    )
    registry["legacy_reason"] = registry["filename"].map(legacy_reason)
    registry["likely_legacy"] = registry["legacy_reason"].ne("")
    registry = build_schema_ids(registry)
    registry, duplicate_basename_report = build_duplicate_basename_report(registry)

    duplicate_lookup = (
        registry.loc[registry["inventory_duplicate_group"].notna(), ["filename", "inventory_duplicate_group"]]
        if "inventory_duplicate_group" in registry.columns
        else pd.DataFrame(columns=["filename", "inventory_duplicate_group"])
    )
    del duplicate_lookup  # Explicitly unused: inventory duplicate groups are not evidence of duplication.

    family_summary = build_family_summary(registry)
    schema_summary = build_schema_summary(registry)

    schema_registry_path = output_dir / "schema_registry.csv"
    family_summary_path = output_dir / "family_summary.csv"
    schema_summary_path = output_dir / "schema_summary.csv"
    duplicate_basename_path = output_dir / "duplicate_basename_report.csv"

    registry.to_csv(schema_registry_path, index=False)
    family_summary.to_csv(family_summary_path, index=False)
    schema_summary.to_csv(schema_summary_path, index=False)
    duplicate_basename_report.to_csv(duplicate_basename_path, index=False)

    print(f"Wrote schema registry: {schema_registry_path}")
    print(f"Wrote family summary: {family_summary_path}")
    print(f"Wrote schema summary: {schema_summary_path}")
    print(f"Wrote duplicate basename report: {duplicate_basename_path}")


if __name__ == "__main__":
    main()
