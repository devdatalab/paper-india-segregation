# Paper Analysis Dataset Workflow

## Purpose

This workflow identifies the dataset files needed to reproduce the active paper
results from the replication code. It is intentionally narrower than a full
raw-data rebuild manifest.

The key output is a replication flag:

- `needed_replication = 1`: needed for the active paper-results replication
- `needed_replication = 0`: present in the raw or intermediate manifests, but
  not directly needed for the active paper-results replication set
- `analysis_handoff = 1`: created inside the `a/` analysis pipeline and not
  required before analysis starts
- `absolute_dataset_path`: best resolved persisted path for the dataset on the
  IEC filesystem, when one exists
- `clean_equivalent_path`: persisted clean-copy path for generated `TMP`
  datasets where an exact clean equivalent was found

This distinction matters because the full build has many raw inputs,
intermediate handoffs, variants, and skipped workflow files. Those are useful
for provenance or rebuilding from first principles, but they are not all needed
to rerun the paper tables and figures once the prepared/generated analysis
datasets exist.

## How To Generate The Files

Run:

```bash
python replication_notes/build_paper_analysis_datasets.py
```

By default, the script writes CSV outputs outside the repository:

```text
/tmp/paper-india-segregation/paper_analysis_datasets.csv
/tmp/paper-india-segregation/dataset_replication_flags.csv
```

To write somewhere else, set:

```bash
REPLICATION_DATASET_MANIFEST_DIR=/path/to/output \
  python replication_notes/build_paper_analysis_datasets.py
```

The CSVs are not committed to GitHub by default. They are generated artifacts.
The `dataset_path` column remains the logical path used by the replication code.
Use `absolute_dataset_path` to locate the persisted file on the IEC filesystem.

## Inputs To The Workflow

The script combines three sources of evidence:

- `replication_notes/run_order.csv`: defines the active replication scripts.
- `replication_notes/raw_datasets.csv`: lists raw inputs and their first use.
- `replication_notes/intermediate_datasets.csv`: lists generated TMP datasets
  and their producer/consumer relationships.
- Static scans of active `a/*.do` and `a/*.py` scripts: catch direct reads that
  are missing from the manifests.

The active analysis stage is defined as scripts called from
`a/make_seg_results.do`, plus their active Python subcalls.

## Why The Needed Set Has 67 Files

The paper-results replication set has 67 files because it includes only files
that the active analysis scripts directly need:

- 34 `raw_analysis_input` files
- 21 `generated_analysis_input` files
- 12 `analysis_generated_handoff` files

These 67 files are enough for active paper-results replication because they
cover the actual data reads in the analysis chain that creates the paper tables,
figures, and TeX inputs.

They are not the same as the full raw build packet. A full raw rebuild also
needs additional SECC, EC, mobility, violence, SHRUG, label, and US source files
that are consumed by `b/` build scripts. Those files are useful if the goal is
to recreate every generated analysis dataset from raw sources, but they are not
needed if the goal is to rerun the active paper analysis from the prepared
analysis inputs.

## Dataset Stages

`raw_analysis_input`

Raw or supplied files read directly by active analysis scripts. These remain
needed even when using generated analysis datasets, because some paper exhibits
still read raw comparison, handbook, PC01/PC11, SHRUG, or GIS files directly.
The manifest leaves `creator_script` blank for these rows unless a script that
writes the exact file is found. A scan of `segregation/b/` found consumers of
several PC11/SHRUG inputs, but no active `b/` script that creates the exact
`RAW` files required by the paper analysis packet, so those rows are annotated
as supplied raw inputs.

`generated_analysis_input`

Prepared datasets that should exist before running the active analysis stage.
Most are produced by `b/` build scripts, such as the SECC segregation block and
city datasets, correlates, US comparison datasets, and PC11 Muslim-share files.
Several generated inputs are read from `$tmp` by the analysis code but also
exist as persisted clean datasets under `/dartfs/rc/lab/I/IEC/seg/clean`; those
rows carry the clean path in `clean_equivalent_path`.
Generated inputs that are persisted elsewhere in `/dartfs/rc/lab/I/IEC/seg`
are recorded in `absolute_dataset_path` even when they are not clean-copy files.

`analysis_generated_handoff`

Files created inside the `a/` analysis stage and then consumed later by another
analysis step, Python plotting step, or TeX table generation. These are marked
`analysis_handoff = 1` and `required_before_analysis = FALSE` because they do
not need to exist before `a/make_seg_results.do` starts.

`raw_manifest_not_needed_for_analysis`

Raw manifest files that are not directly read by the active paper analysis
stage. Many of these are still needed for a full raw rebuild, but not for
paper-results replication from prepared analysis data.

`intermediate_manifest_not_needed_for_analysis`

Intermediate manifest files that are not directly consumed by the active paper
analysis stage. These include skipped, internal-only, or non-paper-run handoffs.

## Interpreting `needed_replication`

Use `dataset_replication_flags.csv` for keep/drop decisions around the compact
paper-results replication packet.

- Keep rows with `needed_replication = 1`.
- Rows with `needed_replication = 0` can be excluded from the compact
  paper-results replication packet.
- If preparing only the files that must exist before analysis starts, keep rows
  with `needed_replication = 1` and `analysis_handoff = 0`.
- Do not interpret `0` as "never useful." It means "not required for active
  paper-results replication from prepared/generated analysis inputs."

For full raw rebuild reproducibility, use the broader raw and intermediate
manifests instead.

## Current Counts

As of the latest generated outputs:

- `paper_analysis_datasets.csv`: 67 rows
- `dataset_replication_flags.csv`: 155 rows
- `needed_replication = 1`: 67 rows
- `needed_replication = 0`: 88 rows
- `analysis_handoff = 1`: 12 rows
- upfront files required before analysis: 55 rows

The 67 needed rows are exactly the rows in `paper_analysis_datasets.csv`.
