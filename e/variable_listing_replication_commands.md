# Replicating `variable_listing.xlsx`

This note records the commands for rebuilding the variable-listing workbook and then applying the rename-review columns used in the active handoff workbook.

Run from the repo root:

```bash
cd /dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation

workbook=/dartfs-hpc/scratch/siddiqui/variable_listing.xlsx
csv_dir=/dartfs-hpc/scratch/siddiqui/seg_variable_listing/variable_listing_csv
manifest=inventory/paper_analysis_datasets.csv
```

## Rebuild the Base Listing

This rebuilds the workbook from the manifest and dataset metadata. It reads dataset headers and summary metadata; it does not edit source `.dta` files.

```bash
python inventory/build_variable_listing.py \
  --manifest "$manifest" \
  --scope all \
  --workbook "$workbook" \
  --csv-dir "$csv_dir"
```

Populate `used_analysis`, `used_analysis_scripts`, conflict flags, and CSV mirrors:

```bash
python inventory/scan_variable_conflicts.py \
  --manifest "$manifest" \
  --workbook "$workbook" \
  --csv-dir "$csv_dir" \
  --analysis-dir a
```

## Apply Rename Review Columns

Apply the first structured rename/storage pass. This adds or updates `renamed_variable_name` and `harmonized_storage_type`, and writes a timestamped backup next to the workbook before modifying it.

```bash
python e/apply_variable_listing_rename_harmonization.py \
  --workbook "$workbook"
```

Apply the label-aware review pass. This preserves `renamed_variable_name`, then adds `label_aware_renamed_variable_name` and `label_aware_harmonized_storage_type` for all `used_analysis = 1` rows plus all `bad_*` rows.

```bash
python e/apply_variable_listing_label_aware_rename_review.py \
  --workbook "$workbook"
```

Optional: refresh the used-analysis coverage report.

```bash
python e/build_variable_listing_used_analysis_report.py \
  --workbook "$workbook" \
  --report e/variable_listing_used_analysis_report.md
```

## Validation

Dry-run either rename pass before writing:

```bash
python e/apply_variable_listing_rename_harmonization.py --workbook "$workbook" --dry-run
python e/apply_variable_listing_label_aware_rename_review.py --workbook "$workbook" --dry-run
```

Compile-check the Python scripts:

```bash
python -m py_compile \
  e/apply_variable_listing_rename_harmonization.py \
  e/apply_variable_listing_label_aware_rename_review.py
```

The rename-review scripts also validate that proposed names are lowercase snake case, every eligible row is filled, and there are no duplicate proposed names within a sheet.

## Exact Reproduction Note

The base builder recreates metadata from the manifest and source datasets. Any hand-audited columns already present in a workbook, such as richer `renamed_variable_label` text, must be present in the starting workbook if an exact copy of the active scratch workbook is required. The rename-review scripts preserve those audited columns and use them as inputs when available.
