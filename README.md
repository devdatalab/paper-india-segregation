# Residential Segregation and Unequal Access to Local Public Services in India

This repository contains code for the replication build of:

- Asher, Jha, Novosad, Adukia, Tan (2026, Conditionally Accepted at American Economic Review),
  ["Residential Segregation and Unequal Access to Local Public Services in India: Evidence from 1.5m Neighborhoods"](https://paulnovosad.com/pdf/india-segregation.pdf)

## Replication Guide

These instructions were tested on Linux and OSX with Stata 18.0 and Python 3.11.

To replicate this paper, take the following steps:

1. Download and extract the replication dataset from [Google Drive](https://drive.google.com/drive/folders/10WmsylJzR8w9zcsNOU99FLJSFxymi_B8) (rclone destination: `ddl_full:public-repos/data-seg-paper`).
2. Install the python conda environment from `./segregation.yml`.
3. Set essential globals:
   - In `./make_seg_rebuild.do`, set `$scode`, `$base`, and `$python`.
   - In `./.env`, set `SCODE` and `SDATA`.
4. Run `make_seg_rebuild.do` in Stata. Intermediate analysis files will be sent to `$base/tmp`, and exhibits to `$base/out`.
5. Tex compilation: Open `./tex/segregation.tex` and point `\\segpath` to `$base/out` (replacing `$base` with the data path).

### Setting globals in `make_seg_rebuild.do`:

```
global scode [path to this repo root]
global base [path to extracted data repository root, containing raw/tmp/out]
global python [path to your python executable, e.g. "/opt/homebrew/Caskroom/mambaforge/base/envs/segregation/bin/python"]
```

The Stata-Python calls use the direct path to the conda executable to ensure it runs in the correct environment. To find this (after creating the `segregation` conda env):

```
conda activate segregation
which python
```

The result of `which python` goes into the `python` Stata global. Stata calls Python with code blocks like this:
```stata
shell PYTHONPATH=$scode $python $scode/a/<script>.py
```

### Setting globals in `.env` for Python scripts

SCODE should be the same as `$scode` and SDATA the same as `$base`.

Example .env:

```
SCODE=~/mystuff/segregation
SDATA=~/Dropbox/seg-replication
```

### Build flow

Top-level execution:

1. Single file to run build and analysis: `make_seg_rebuild.do`
2. Data build scripts are in `b/`
3. Analysis scripts are in `a/`, and are run by `a/make_seg_results.do`
4. outputs go to `$out` for LaTeX consumption

### Runtime/storage expectations

Runtime is about 2 hours on an M2 Mac. Storage requirement is about 50 GB.

---

## Additional Notes

### Data Availability and Provenance Statements

All data sources used in the paper are available in the paper's data packet. The authors have legitimate access to and permission to use the data used in this manuscript. All data were downloaded from open sources and to our knowledge, can be re-used freely.

Primary provenance categories:

- Socioeconomic and Caste Census (SECC) 2011/12 neighborhood records (Originally scraped from `https://secc.gov.in/`).
- Economic Census of India (1990, 1998, 2005, 2013): [Ministry of Statistics and Programme Implementation (MOSPI) Economic Census](https://www.mospi.gov.in/economic-census).
- Population Censuses of India (1991, 2001, 2011), including District Handbooks.
- SHRUG keys and linked census files: [Socioeconomic High-resolution Rural-Urban Geographic Platform (SHRUG)](https://www.devdatalab.org/shrug).
- Intergenerational mobility covariates: [Asher, Novosad, Rafkin (AEJ: Applied, 2024)](https://www.aeaweb.org/articles?id=10.1257/app.20210686).
- Hindu-Muslim violence covariates (Varshney-Wilkinson): [ICPSR study 4342](https://www.icpsr.umich.edu/web/ICPSR/studies/4342).
- Official Census GIS shapefiles for map generation.
- US comparator files: [Diversity and Disparities Project: Residential Segregation Data](https://s4.ad.brown.edu/projects/diversity/segregation2020/) and [2020 U.S. Census redistricting tables](https://www.census.gov/data/tables/2020/dec/2020-redistricting-data.html).


#### Summary of Data Availability

| Data.Name | Data.Files | Location |
| --- | --- | --- |
| SECC/EC collapsed inputs | multiple `.dta` files | `raw/clean/` |
| SHRUG keys and data | multiple `.dta` files | `raw/shrug/` |
| PC11/PC01 social-group and handbook files | multiple `.dta` files | `raw/pc11/`, `raw/pc01/`, `raw/clean/handbooks/` |
| Mobility and violence covariates | multiple `.dta` files | `raw/mobility/`, `raw/violence/` |
| GIS files for map outputs | `.shp/.shx/.dbf/.prj` | `raw/gis/` |
| US comparison data | `.csv` | `raw/us/` |

### Computational requirements

#### Software Requirements

Required software:

- Stata (18+ recommended)
  - Stata packages used include: `binscatter`, `_gwtmean`, `rangestat`, `ebalance`, `labutil`, `distinct`, and in analysis paths `reghdfe`, `estout`, `gtools`, `ftools`.
- Python 3.11
  - Environment specified in `segregation.yml`
  - Major dependencies include `pandas`, `numpy`, `geopandas`, `matplotlib`, `statsmodels`, and related geospatial/scientific stack.

Local Stata helpers included in repo:

- `tools/do/tools.do`
- `tools/stata-tex/`
- `tools/masala-merge/`

#### Controlled Randomness

No pseudo-random generator is used in the analysis described here.

#### Memory, Runtime, Storage Requirements

##### Summary time to reproduce

Approximate runtime on a standard modern desktop: 2-8 hours

##### Summary of required storage space

Approximate storage required for full local run (raw + intermediates + outputs): 25 GB - 50 GB

### Description of programs/code

- `make_seg_rebuild.do`: top-level replication driver.
- `set_paths.do`: Stata path aliases derived from `scode` and `sdata` roots.
- `set_paths.py` + `.env`: Python path contract (`SCODE`, `SDATA`).
- `b/`: build/data preparation scripts.
- `a/`: analysis and exhibit generation scripts.
- `a/make_seg_results.do`: analysis driver for paper exhibits.
- `tex/segregation.tex`: paper source consuming generated exhibits.

#### Exhibit Mapping

| Figure/Table # | Program | Output file(s) |
| --- | --- | --- |
| Figure 1 | `a/graph_group_shares.do` | `group_share_density_urban.pdf`, `group_share_density_rural.pdf` |
| Figure 2 | `a/graph_seg_comparisons.do` | `seg_compare_dissim.pdf`, `seg_compare_iso.pdf` |
| Figure 3 | `a/graph_urban_rural_dissim_correlation.do` | `bin_seg_muslim_urban_rural_corr_200.pdf`, `bin_seg_sc_urban_rural_corr_200.pdf`, `bin_iso_muslim_urban_rural_corr_200.pdf`, `bin_iso_sc_urban_rural_corr_200.pdf` |
| Figure 4 | `a/analyze_correlates.do` -> `a/correlate_coefplots.py` | `coefplot_std_joint.pdf` |
| Figure 5 | `a/block_pg_share_binscatter_pub_dummy.do` | `block_secondary_by_mus_dum_cfe_urban_200_pub.pdf`, `block_secondary_by_sc_dum_cfe_urban_200_pub.pdf`, `block_secondary_by_mus_dum_cfe_rural_200_pub.pdf`, `block_secondary_by_sc_dum_cfe_rural_200_pub.pdf` |
| Figure 6 | `a/graph_pe_functions.do` | `pe_pub_urban_muslim_primary_all.pdf`, `pe_pub_rural_muslim_primary_all.pdf`, `pe_pub_urban_muslim_secondary_all.pdf`, `pe_pub_rural_muslim_secondary_all.pdf`, `pe_pub_urban_muslim_hospital_all.pdf`, `pe_pub_rural_muslim_hospital_all.pdf` |
| Figure 7 | `a/graph_pe_functions.do` | `pe_pub_urban_sc_primary_all.pdf`, `pe_pub_rural_sc_primary_all.pdf`, `pe_pub_urban_sc_secondary_all.pdf`, `pe_pub_rural_sc_secondary_all.pdf`, `pe_pub_urban_sc_hospital_all.pdf`, `pe_pub_rural_sc_hospital_all.pdf` |
| Figure 8 | `a/graph_pe_sanitation.do` | `pe_urban_muslim_light_source_elec_all.pdf`, `pe_urban_sc_light_source_elec_all.pdf`, `pe_urban_muslim_wat_source_home_all.pdf`, `pe_urban_sc_wat_source_home_all.pdf`, `pe_urban_muslim_closed_drain_all.pdf`, `pe_urban_sc_closed_drain_all.pdf` |
| Table 1 | `a/table_sum_stats.do` | `sum_stats_tbl_200.tex` |
| Table 2 | `a/table_town_subd_representativeness.do` | `town_subd_repres.tex` |
| Table 3 | `a/analyze_seg_changes.do` | `seg_time_01_11_pc01_secc.tex` |
| Table 4 | `a/analyze_correlates.do` | `seg_multivar_regs.tex` |
| Table 5 | `a/table_block_pg_share_educ_health.do` | `nbd_pg_share_urban_200.tex`, `nbd_pg_share_rural_200.tex` |
| Table 6 | `a/table_block_pg_share_educ_health.do` | `nbd_privg_share_urban_200.tex`, `nbd_privg_share_rural_200.tex` |
| Table 7 | `a/table_block_pg_share_educ_health.do` | `nbd_wash_mean_urban_200.tex` |
| Appendix Figure A.1 | `a/block_group_pop_histogram_density.do` | `block_pop_hist_200.pdf` |
| Appendix Figure A.2 | `a/city_share_muslim_pc_classify.do` | `city_share_muslim_pc_classify_urban_nofe.pdf` |
| Appendix Figure A.3 | `a/seg_maps.py` | `india_segregation_sc_urban.png`, `india_segregation_muslim_urban.png`, `india_segregation_sc_rural.png`, `india_segregation_muslim_rural.png` |
| Appendix Figure A.4 | `a/analyze_correlates.do` | `bin_dissim_muslim_ln_cons_pc.pdf`, `bin_dissim_sc_ln_cons_pc.pdf`, `bin_dissim_muslim_ln_city_pop.pdf`, `bin_dissim_sc_ln_city_pop.pdf`, `bin_dissim_muslim_p25.pdf`, `bin_dissim_sc_p25.pdf` |
| Appendix Figure A.5 | `a/graph_pe_functions.do` | `pe_priv_urban_muslim_primary_all.pdf`, `pe_priv_rural_muslim_primary_all.pdf`, `pe_priv_urban_muslim_secondary_all.pdf`, `pe_priv_rural_muslim_secondary_all.pdf`, `pe_priv_urban_muslim_hospital_all.pdf`, `pe_priv_rural_muslim_hospital_all.pdf` |
| Appendix Figure A.6 | `a/graph_pe_functions.do` | `pe_priv_urban_sc_primary_all.pdf`, `pe_priv_rural_sc_primary_all.pdf`, `pe_priv_urban_sc_secondary_all.pdf`, `pe_priv_rural_sc_secondary_all.pdf`, `pe_priv_urban_sc_hospital_all.pdf`, `pe_priv_rural_sc_hospital_all.pdf` |
| Appendix Figure A.7 | `a/pg_intersection.py` | `pg_interaction_coefplot_prim_muslim_share.pdf`, `pg_interaction_coefplot_prim_sc_share.pdf`, `pg_interaction_coefplot_sec_muslim_share.pdf`, `pg_interaction_coefplot_sec_sc_share.pdf`, `pg_interaction_coefplot_hosp_muslim_share.pdf`, `pg_interaction_coefplot_hosp_sc_share.pdf` |
| Appendix Figure A.8 | `a/graph_seg_vs_pg.py` | `quartiles_sc_dissim.pdf`, `quartiles_muslim_dissim.pdf` |
| Appendix Table A.1 | `a/reweight_town_subd_representativeness.do` | `reweighted_means.tex` |
| Appendix Table A.2 | `tex/exhibits/src_seg_compare.tex` | `tex/exhibits/src_seg_compare.tex` |
| Appendix Table A.3 | `a/analyze_correlates.do` | `seg_multivar_regs_app1.tex` |
| Appendix Table A.4 | `a/table_block_pg_share_educ_health_slum.do` | `nbd_pg_slum_200.tex` |
| Appendix Table A.5 | `a/pg_inequality_w_controls.do` | `pg_ineq_w_controls.tex` |
