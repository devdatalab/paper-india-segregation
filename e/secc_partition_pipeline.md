# SECC Partition and Block-Collapse Pipeline

This note documents where the partitioned SECC block files come from, why the
partitioning exists, and what cleaning/collapse operations happen inside the
partitioned data pipeline. It is based on the code currently found in:

- `/dartfs-hpc/rc/home/m/f00858m/ddl/core/secc`
- `/dartfs-hpc/rc/home/m/f00858m/ddl/core/pc/pc11`
- `/dartfs-hpc/rc/home/m/f00858m/ddl/segregation`
- `/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation`

## Short Answer

The block-level partition files, for example
`$sdata/partitioned/secc_collapse/secc_block_rural_06006.dta`, are not created
by scraping PDFs directly. They are created from already-cleaned, state-level
SECC parsed-draft `.dta` microdata.

The direct inputs are:

```text
$secc/parsed_draft/dta/rural/*_members_clean.dta
$secc/parsed_draft/dta/rural/*_household_clean.dta
$secc/parsed_draft/dta/urban/*_members_clean.dta
$secc/parsed_draft/dta/urban/*_household_clean.dta
```

Those cleaned state files are split into small geographic partitions, processed
partition-by-partition on the cluster, collapsed to block and upper geographic
levels, and then appended into clean files such as:

```text
$sdata/clean/secc_rural_collapsed_block.dta
$sdata/clean/secc_urban_collapsed_block.dta
```

The raw upstream source is SECC 2011 PDF/CSV/XLS material, but the scraping and
raw parsing happen earlier in the core SECC pipeline. The segregation partition
pipeline starts after that parsing/cleaning has already produced `.dta` files.

## Pipeline Overview

```text
SECC PDFs / parsed CSVs / parsed XLS files
    |
    | core SECC parsing and cleaning
    v
$secc/parsed_draft/dta/{rural,urban}/*_{members,household}_clean.dta
    |
    | assign pc11_small_part_id using Census 2011 village/ward population keys
    v
$sdata/partitioned/parsed_draft/{rural,urban}/secc_{sector}_{part}_{members,household}.dta
    |
    | partition-level feature construction and collapse
    v
$sdata/partitioned/secc_collapse/secc_{members,household,educ}_block_{sector}_{part}.dta
    |
    | merge member, household, and education block components
    v
$sdata/partitioned/secc_collapse/secc_block_{sector}_{part}.dta
    |
    | append all partition outputs
    v
$sdata/clean/secc_{sector}_collapsed_block.dta
```

For the target cluster we audited:

```text
$sdata/partitioned/secc_collapse/secc_block_rural_*.dta
    -> $sdata/clean/secc_rural_collapsed_block.dta
```

## Raw SECC Origin

The upstream SECC build code indicates that the raw inputs were PDF-parsed CSVs
and Excel-parsed CSVs.

Relevant code:

- `/dartfs-hpc/rc/home/m/f00858m/ddl/core/secc/old/secc_build.do`
- `/dartfs-hpc/rc/home/m/f00858m/ddl/core/secc/clean/extract_secc_pdf.do`

`secc_build.do` describes its inputs as:

```text
pdf-parsed csv files in ~/iec2/secc/raw_input/parsed/
excel-parsed csv files in ~/iec2/secc/raw_input/rural_xls/
```

It also describes the old build flow as:

1. Append parsed CSV files by state.
2. Read those state-appended files into Stata.
3. Encode raw string values.
4. Build correspondence tables between raw encodings and final values.
5. Clean, translate, and match SECC locations to PC/Census geography.
6. Save clean state-level SECC `.dta` files.

`extract_secc_pdf.do` is a utility for finding/extracting SECC PDFs from tar
archives. It searches under `$secc/raw_input/parsed/{rural,urban}` and calls a
Python helper, `extract_secc_pdfs`, to extract selected PDF files.

Important distinction: the partitioned block files are downstream of this. The
partitioning step does not itself scrape PDFs. It consumes cleaned parsed-draft
Stata data.

## Why Partitioning Happened

The partitioning exists for memory and parallel processing.

The main partition key is created in:

```text
/dartfs-hpc/rc/home/m/f00858m/ddl/core/pc/pc11/create_partitions_small.do
```

That script sets:

```stata
global pop_limit 600000
```

It creates `pc11_small_part_id` using Census 2011 population data:

- rural partitions use `pc11r_pca_clean.dta` at the village level;
- urban partitions use `pc11u_pca_ward_clean.dta` at the ward level;
- partitions are created within states;
- small partition IDs are state-prefixed codes;
- the output keys are:

```text
$keys/pcec/pc11_rural_small_partition_key.dta
$keys/pcec/pc11_urban_small_partition_key.dta
```

The code comment in the segregation partitioner says "15 million people each,"
but the small partition key used here is explicitly built with a 600,000-person
target. The 15-million comment appears to be inherited from an older, coarser
partitioning scheme.

Partitioning lets the pipeline run many independent Stata jobs on Discovery.
The batch script:

```text
/dartfs-hpc/rc/home/m/f00858m/ddl/segregation/b/discovery/sbatch/submit_collapse_small_partitions.script
```

runs:

```bash
stata -b do ~/ddl/segregation/b/discovery/gen_secc_small_part.do ${SLURM_ARRAY_TASK_ID} urban
stata -b do ~/ddl/segregation/b/discovery/gen_secc_small_part.do ${SLURM_ARRAY_TASK_ID} rural
```

with a job array:

```bash
#SBATCH --array=1-1500%500
```

So each array task picks one `pc11_small_part_id` and processes urban/rural data
for that partition.

## How Clean State Data Become Partitioned Microdata

The splitting step is:

```text
/dartfs-hpc/rc/home/m/f00858m/ddl/segregation/b/discovery/partition/partition_secc_small_part.do
```

This script:

1. Opens each state-level clean SECC file:

```stata
use ${`sector'path}/`state'_`filetype'_clean, clear
```

where `sector` is `urban` or `rural`, and `filetype` is `household` or
`members`.

2. Drops observations missing required geography:

- missing `pc11_district_id`;
- missing `pc11_village_id` for rural;
- missing `pc11_town_id` or `pc11_ward_id` for urban.

3. Merges the relevant small partition key:

```stata
merge m:1 pc11_state_id pc11_district_id using $keys/pcec/pc11_`sector'_small_partition_key, nogen keep(match)
```

4. Saves one partition file per `pc11_small_part_id`:

```text
$sdata/partitioned/parsed_draft/{sector}/secc_{sector}_{part}_{filetype}.dta
```

These files are still microdata. They are smaller geographic shards of the
cleaned parsed-draft SECC member and household files.

## What Cleaning Happens Inside Each Partition

The partition-level cleaning and collapse happens in:

```text
/dartfs-hpc/rc/home/m/f00858m/ddl/segregation/b/discovery/gen_secc_small_part.do
```

That script has four main programs:

```text
collapse_member_data
collapse_hh_data
collapse_parent_educ
merge_data
```

At the end of the file, it calls them in that order.

### 1. Member-Level Cleaning and Collapse

Program:

```text
collapse_member_data
```

Input:

```text
$sdata/partitioned/parsed_draft/{sector}/secc_{sector}_{part}_members.dta
```

Main operations:

- Loads the partitioned member file.
- Merges Muslim-classification data from:

```text
$sdata/partitioned/secc_collapse/muslim_classification/secc_{sector}_{part}_muslim_household.dta
```

- Creates `pop = 1`.
- Recodes `sc_st` into a cleaned binary SC indicator.
- Creates demographic indicators:

```text
sc
nonsc
muslim
nonmuslim
nonscmuslim
bothscmuslim
```

- Handles the special case where a person is both SC and Muslim by assigning
  them to Muslim only for the SC/non-SC split.
- Flags missing group variables:

```text
bad_sc
bad_muslim
bad_ed
```

- Cleans education:

```stata
replace ed = . if (ed < 0 | ed == 8)
```

- Creates education dummies using the education levels observed in that
  partition.
- Creates `age25p` and education-by-age and education-by-demographic
  interactions.
- Collapses member data to:

```text
household level
block level
town/subdistrict level
```

The block-level member output is:

```text
$sdata/partitioned/secc_collapse/secc_members_block_{sector}_{part}.dta
```

Important schema implication: education dummy variables are created only for
education levels that appear in a partition. This is why many partition-level
files have schema subsets, for example missing `ed9999*`, `ed6*`, or `ed7*`
bundles. Those are not necessarily renames or separate concepts; they are often
absent because the generating `levelsof ed` did not include that category in a
given partition.

### 2. Household-Level Cleaning and Collapse

Program:

```text
collapse_hh_data
```

Inputs:

```text
$sdata/partitioned/secc_collapse/secc_members_hh_{sector}_{part}.dta
$sdata/partitioned/parsed_draft/{sector}/secc_{sector}_{part}_household.dta
```

Main operations:

- Starts from the household-level member collapse.
- Merges the partitioned household file.
- Ensures key variables exist even if missing from a partition:

```text
secc_cons
cons_pc
hh_pop
```

- Creates household count `hh = 1`.
- Renames:

```text
secc_cons -> cons
hh_pop    -> hhpop
```

- Computes per-capita consumption:

```stata
replace cons_pc = cons / hhpop
```

- Builds demographic interactions for consumption, household count, per-capita
  consumption, and household population.
- For urban data only, creates service variables:

```text
wat_source_home
light_source_elec
latrine_home
closed_drain
```

- Collapses household variables to block level, generally using household
  population weights for means:

```stata
gcollapse (rawsum) ... (mean) ... [aweight=hhpop], by(...)
```

- Uses an unweighted exception for state `33` where `hhpop` is unavailable.

The block-level household output is:

```text
$sdata/partitioned/secc_collapse/secc_household_block_{sector}_{part}.dta
```

### 3. Parent-Child Education Cleaning and Collapse

Program:

```text
collapse_parent_educ
```

Input:

```text
$sdata/partitioned/parsed_draft/{sector}/secc_{sector}_{part}_members.dta
```

Main operations:

- Keeps people with usable sex and education:

```stata
keep if inlist(sex, 1, 2) & inrange(ed, 1, 7)
```

- Drops very young people and implausible ages:

```stata
drop if age < 12
drop if age > 100
```

- Drops observations missing required location/household identifiers.
- Creates a household ID.
- Drops duplicate household-member records.
- Drops households with more than 20 members.
- Drops single-person households.
- Identifies possible fathers and mothers using sex and age-gap rules.
- Sets parent education to missing where parentage is ambiguous.
- Converts SECC education bins into years of schooling:

```text
1 or 2 -> 0 years
3      -> 5 years
4      -> 8 years
5      -> 10 years
6      -> 12 years
7      -> 14 years
```

- Creates son/daughter education variables and age-window variables.
- Merges the education household file back to member and household household
  summaries.
- Builds demographic interactions for parent-child education variables.
- Collapses parent-child education variables to block and upper levels.

The block-level education output is:

```text
$sdata/partitioned/secc_collapse/secc_educ_block_{sector}_{part}.dta
```

### 4. Merge Partition-Level Components

Program:

```text
merge_data
```

This merges the partition-level block components:

```text
secc_members_block_{sector}_{part}.dta
secc_household_block_{sector}_{part}.dta
secc_educ_block_{sector}_{part}.dta
```

into:

```text
$sdata/partitioned/secc_collapse/secc_block_{sector}_{part}.dta
```

For rural block data this produces files like:

```text
$sdata/partitioned/secc_collapse/secc_block_rural_06006.dta
```

The merge uses block geography keys:

```text
$secc_collapse_geo_vars + pc11_village_id    for rural
$secc_collapse_geo_vars + pc11_town_id       for urban
```

where `$secc_collapse_geo_vars` is the SECC/PC11 geography block key:

```text
pc11_state_id
pc11_district_id
pc11_subdistrict_id
pc11_ward_id
pc11_block_id
```

After saving the final partition-level block and upper files, the script removes
some intermediate member/household/education component files.

## How Partitioned Block Files Become the Clean Master

The append step is:

```text
/dartfs-hpc/rc/home/m/f00858m/ddl/segregation/b/discovery/assemble_secc_small_part.do
```

For block-level data, it builds a file list:

```stata
local filelist : dir "$sdata/partitioned/secc_collapse" files "secc_block_`sector'_*.dta"
```

Then appends each partition file:

```stata
clear
foreach file in `filelist' {
    append using $sdata/partitioned/secc_collapse/`file'
}
```

and saves:

```text
$sdata/clean/secc_{sector}_collapsed_block.dta
```

For rural block data:

```text
$sdata/partitioned/secc_collapse/secc_block_rural_*.dta
    -> $sdata/clean/secc_rural_collapsed_block.dta
```

For town/subdistrict-level data, the script appends first and then re-collapses
because upper geographic units can span multiple small partitions. For block
data, the output is directly appended because the intended unit is already the
block-level partition output.

## Where the Paper Repo Enters

The paper repository does not appear to create the original partitioned SECC
block files. It consumes the cleaned outputs.

For example:

```text
/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/merge_secc_ec.do
```

uses:

```text
$raw/clean/secc_{rural,urban}_collapsed.dta
$raw/clean/secc_{rural,urban}_collapsed_block.dta
```

and merges them with EC13 block/city data.

## Why the Partition Files Have Schema Differences

The inventory and harmonization work found many partition files with duplicate
or near-duplicate schemas. This is expected from the generating code.

The main reason is schema-by-observed-category generation. In
`gen_secc_small_part.do`, education dummies are generated from:

```stata
levelsof ed, local(edlevels)
foreach ed_lvl in `edlevels' {
    gen ed`ed_lvl' = 1 if ed == `ed_lvl' & !mi(`ed_lvl')
}
```

If a partition does not contain education level `9999`, `6`, `7`, etc., then the
corresponding `ed*` variables and their interaction bundles are never created in
that partition. When those partitions are appended, Stata fills absent variables
with missing values.

That explains why files such as:

```text
secc_educ_block_rural_06006.dta
secc_educ_block_rural_09017.dta
secc_educ_block_rural_24056.dta
```

can look like schema duplicates or schema subsets. They are intermediate
partition-level outputs from the same collapse code, not independent source
datasets.

## Current `secc_block_rural` Audit Result

For the `secc_block_rural` cluster, the registry/harmonization audit found:

- 1,239 shard files.
- 14 shard schemas.
- `clean/secc_rural_collapsed_block.dta` is the canonical appended master for
  this cluster.
- The summed shard row count equals the master row count.
- All shard schemas are subsets of the canonical target schema.
- The appended harmonized shards reproduce the candidate master exactly in row
  count, variable names, variable order, key columns, and values.

This supports the interpretation that:

```text
clean/secc_rural_collapsed_block.dta
```

is the assembled master file generated from:

```text
partitioned/secc_collapse/secc_block_rural_*.dta
```

## Key Source Files

Raw SECC extraction/parsing:

```text
/dartfs-hpc/rc/home/m/f00858m/ddl/core/secc/clean/extract_secc_pdf.do
/dartfs-hpc/rc/home/m/f00858m/ddl/core/secc/old/secc_build.do
```

Partition key creation:

```text
/dartfs-hpc/rc/home/m/f00858m/ddl/core/pc/pc11/create_partitions_small.do
```

SECC microdata partitioning:

```text
/dartfs-hpc/rc/home/m/f00858m/ddl/segregation/b/discovery/partition/partition_secc_small_part.do
```

Partition-level feature construction and collapse:

```text
/dartfs-hpc/rc/home/m/f00858m/ddl/segregation/b/discovery/gen_secc_small_part.do
```

HPC submission:

```text
/dartfs-hpc/rc/home/m/f00858m/ddl/segregation/b/discovery/sbatch/submit_collapse_small_partitions.script
```

Append into clean master files:

```text
/dartfs-hpc/rc/home/m/f00858m/ddl/segregation/b/discovery/assemble_secc_small_part.do
```

Downstream paper use:

```text
/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/merge_secc_ec.do
```
