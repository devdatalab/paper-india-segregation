# Correlates dataset lineage and retention notes

## Datasets in scope

- `pg_by_seg.dta`
- `seg_corr_estimates.csv`
- `seg_correlates.dta`
- `seg_correlates_analysis.dta`

## Bottom line

These are not simple subsets.

- `seg_correlates.dta` is a constructed town-level analysis dataset assembled from multiple external and internal sources.
- `seg_correlates_analysis.dta` is a modified analysis version of `seg_correlates.dta` with outlier filtering, variable standardization, and rescaling.
- `seg_corr_estimates.csv` is an output file of regression estimates written by `a/analyze_correlates.do`.
- `pg_by_seg.dta` is **not** part of the `b/prep_correlates.do -> a/analyze_correlates.do` pipeline. It is produced by `a/explore_seg_vs_service_disparity.do`.

## 1. `seg_correlates.dta`

### Producer

- [b/prep_correlates.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/prep_correlates.do:223)

### What the script does

`b/prep_correlates.do` builds a shrid-level correlates file by creating and then merging several components:

1. Violence component:
   - harmonizes two violence source files to `shrid`
   - constructs `violence_index`, event counts, log counts, and any-event indicators
   - saves `$tmp/seg_violence.dta`
2. Upward mobility component:
   - reads mobility data, averages bounds into `p25`
   - filters low-quality entries
   - maps to `shrid`, population-weights across towns spanning districts
   - saves `$tmp/seg_mobility.dta`
3. Gini components:
   - renames rural district gini variables and saves `$tmp/seg_rural_district_gini.dta`
   - maps urban town gini to `shrid`, collapses, and saves `$tmp/seg_town_gini.dta`
4. Growth component:
   - merges PC91, PC01, and PC11 PCA populations
   - keeps urban sectors
   - computes `ln_growth` and winsorizes it
   - saves `$tmp/seg_growth.dta`
5. City covariate component 1:
   - reads `$tmp/secc/secc_ec_citydata_urban.dta`
   - creates job shares, log consumption, education gaps, and consumption gaps
   - saves `$tmp/seg_city_data_1.dta`
6. City covariate component 2:
   - reads `$tmp/secc/segregation_citydata_urban_200.dta`
   - keeps segregation measures, public facility rates, area, origin year, and population shares
   - saves `$tmp/seg_city_data_2.dta`
7. Final assembly:
   - merges all of the above by `shrid` and district
   - fills missing violence variables with zero
   - writes `$tmp/seg_correlates.dta`

### Direct inputs

- `$raw/violence/violence_matched_except_jk.dta`
- `$raw/violence/violence_matched_jk.dta`
- `$mobility/secc/secc_mobility_town.dta`
- `$mobility/covars/secc_gini_rural_district.dta`
- `$mobility/covars/secc_gini_urban_town.dta`
- `$shrug/keys/shrug_pc91u_key.dta`
- `$shrug/keys/shrug_pc01u_key.dta`
- `$shrug/keys/shrug_pc11u_key.dta`
- `$shrug/data/shrug_pc91_pca.dta`
- `$shrug/data/shrug_pc01_pca.dta`
- `$shrug/data/shrug_pc11_pca.dta`
- `$tmp/secc/secc_ec_citydata_urban.dta`
- `$tmp/secc/segregation_citydata_urban_200.dta`

### Important references

- Violence prep: [b/prep_correlates.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/prep_correlates.do:31)
- Mobility prep: [b/prep_correlates.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/prep_correlates.do:83)
- Gini prep: [b/prep_correlates.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/prep_correlates.do:111)
- Growth prep: [b/prep_correlates.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/prep_correlates.do:129)
- City data 1 from `secc_ec_citydata_urban`: [b/prep_correlates.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/prep_correlates.do:147)
- City data 2 from `segregation_citydata_urban_200`: [b/prep_correlates.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/prep_correlates.do:183)
- Final merge and save: [b/prep_correlates.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/prep_correlates.do:200)

### Retention recommendation

Keep `seg_correlates.dta`.

Reason:

- it is a true derived analysis dataset
- it merges multiple data families
- it creates new variables rather than just subsetting existing ones
- it is the direct input to `a/analyze_correlates.do`

## 2. `seg_correlates_analysis.dta`

### Producer

- [a/analyze_correlates.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/a/analyze_correlates.do:37)

### What the script does

`a/analyze_correlates.do` opens `$tmp/seg_correlates.dta` and creates an analysis-specific working version:

- flags 1st/99th percentile outliers across the correlates varlist and sets those values to missing
- creates standardized versions of the regression variables
- rescales `city_origin_year`
- saves the modified file as `$tmp/seg_correlates_analysis.dta`

This is not just a copy. It changes values and adds standardized columns used later in the regressions.

### Direct input

- `$tmp/seg_correlates.dta`

### Important references

- Open input: [a/analyze_correlates.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/a/analyze_correlates.do:7)
- Outlier filtering: [a/analyze_correlates.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/a/analyze_correlates.do:19)
- Standardization: [a/analyze_correlates.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/a/analyze_correlates.do:26)
- Save: [a/analyze_correlates.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/a/analyze_correlates.do:37)

### Retention recommendation

Keep `seg_correlates_analysis.dta` if you want the exact regression-ready dataset used in the correlates analysis.

Reason:

- it encodes analysis choices that are not present in `seg_correlates.dta`
- recreating it requires rerunning the analysis-prep logic

If you only want one retained layer, `seg_correlates_analysis.dta` is the more analysis-ready of the two; if you want reproducibility and auditability, keep both.

## 3. `seg_corr_estimates.csv`

### Producer

- [a/analyze_correlates.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/a/analyze_correlates.do:85)

### What the script does

The script initializes `$tmp/seg_corr_estimates.csv` with headers, then appends regression results from:

- joint raw regressions
- bivariate raw regressions
- joint standardized regressions
- bivariate standardized regressions

It later reimports the CSV, drops some isolation/share rows deemed uninformative, and exports it again in filtered form.

So this file is not raw data and not a simple tabulation. It is a structured regression-results artifact.

### Direct input

- `$tmp/seg_correlates_analysis.dta`

### Important references

- File init: [a/analyze_correlates.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/a/analyze_correlates.do:85)
- Raw joint and bivariate appends: [a/analyze_correlates.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/a/analyze_correlates.do:93)
- Standardized appends: [a/analyze_correlates.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/a/analyze_correlates.do:173)
- Final filtering and rewrite: [a/analyze_correlates.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/a/analyze_correlates.do:203)

### Retention recommendation

Keep `seg_corr_estimates.csv` if you want to preserve the exact coefficient artifact consumed by downstream plotting code.

Reason:

- it is the direct input to `a/correlate_coefplots.py`
- it stores processed regression outputs, not just temporary scratch values

## 4. `pg_by_seg.dta`

### Important correction

`pg_by_seg.dta` is **not** produced by `b/prep_correlates.do` or `a/analyze_correlates.do`.

It is produced by:

- [a/explore_seg_vs_service_disparity.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/a/explore_seg_vs_service_disparity.do:164)

and then read by:

- [a/graph_seg_vs_pg.py](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/a/graph_seg_vs_pg.py:10)

### What that script does

`a/explore_seg_vs_service_disparity.do`:

- opens `$tmp/secc/segregation_blockdata_urban_200.dta`
- merges in city segregation measures from `$tmp/secc/segregation_citydata_urban_200.dta`
- constructs public-service access shares and gap variables by group
- runs quartile-by-segregation regressions for public service disparities
- writes results first to `$tmp/pg_by_seg_ests.csv`
- rescales coefficients and standard errors, creates plotting fields, and saves `$tmp/pg_by_seg.dta`

### Direct inputs

- `$tmp/secc/segregation_blockdata_urban_200.dta`
- `$tmp/secc/segregation_citydata_urban_200.dta`

### Important references

- Open blockdata: [a/explore_seg_vs_service_disparity.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/a/explore_seg_vs_service_disparity.do:2)
- Merge citydata: [a/explore_seg_vs_service_disparity.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/a/explore_seg_vs_service_disparity.do:5)
- Write intermediate estimates CSV: [a/explore_seg_vs_service_disparity.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/a/explore_seg_vs_service_disparity.do:79)
- Save final `pg_by_seg.dta`: [a/explore_seg_vs_service_disparity.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/a/explore_seg_vs_service_disparity.do:164)

### Retention recommendation

Keep `pg_by_seg.dta` if you want the exact plotting-ready dataset for Appendix Figure A.8.

Reason:

- it is a derived regression-results dataset
- it includes coefficient rescaling and plotting fields
- it is consumed directly by the Python plotting script

## Recommended retention set

For the correlates pipeline:

- keep `seg_correlates.dta`
- keep `seg_correlates_analysis.dta`
- keep `seg_corr_estimates.csv`

For the separate public-goods-by-segregation pipeline:

- keep `pg_by_seg.dta`

If storage is tight, the minimum analysis-ready set is:

- `seg_correlates_analysis.dta`
- `seg_corr_estimates.csv`
- `pg_by_seg.dta`

But if you want a defensible replication archive, keeping both `seg_correlates.dta` and `seg_correlates_analysis.dta` is the better choice because they capture distinct stages of analysis construction.
