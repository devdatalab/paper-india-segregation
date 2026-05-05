# Segregation dataset lineage and retention notes

## Datasets in scope

- `segregation_blockdata_rural_200.dta`
- `segregation_blockdata_rural_4000.dta`
- `segregation_blockdata_urban_200.dta`
- `segregation_blockdata_urban_4000.dta`
- `segregation_citydata_rural_200.dta`
- `segregation_citydata_urban_200.dta`
- `segregation_citydata_urban_4000.dta`

## Bottom line

These are not simple subsets. They are analysis-ready derived datasets created through multiple transformation steps:

1. merge SECC and EC data
2. pool blocks into 200/4000-population neighborhoods
3. create consumption/share/public-goods variables
4. compute segregation indices
5. merge in SHRUG/PC11 amenities and Muslim-share data for city-level outputs

Because of that, the upstream pooled SECC-EC masters alone are not enough if the goal is to preserve the exact analysis-ready inputs used by the `a/*.do` scripts.

## Producer chain

### 1. Base merged SECC-EC masters

Created by `b/merge_secc_ec.do`:

- block-level merged masters:
  - `$tmp/secc/secc_ec_blockdata_rural.dta`
  - `$tmp/secc/secc_ec_blockdata_urban.dta`
- city-level merged masters:
  - `$tmp/secc/secc_ec_citydata_rural.dta`
  - `$tmp/secc/secc_ec_citydata_urban.dta`

Inputs:

- `$raw/clean/secc_{rural,urban}_collapsed.dta`
- `$raw/clean/secc_{rural,urban}_collapsed_block.dta`
- `$raw/clean/ec13_{rural,urban}_{city,block}.dta`

Key logic:

- merges SECC and EC at city level and block level
- keeps SECC geography as the master side
- renames `*own1` to `*pub`

References:

- [b/merge_secc_ec.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/merge_secc_ec.do:41)
- [b/merge_secc_ec.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/merge_secc_ec.do:59)
- [b/merge_secc_ec.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/merge_secc_ec.do:76)
- [b/merge_secc_ec.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/merge_secc_ec.do:88)

### 2. Pooled block-group masters

Created by `b/create_secc_block_groups.do`:

- `$tmp/secc/secc_ec_blockdata_{rural,urban}_pooled_200.dta`
- `$tmp/secc/secc_ec_blockdata_{rural,urban}_pooled_4000.dta`

Key logic:

- pools geographically adjacent SECC blocks into minimum-population neighborhoods
- only within the same town/village and ward
- creates the 200 and 4000 neighborhood versions used downstream

References:

- [b/create_secc_block_groups.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/create_secc_block_groups.do:41)
- [b/create_secc_block_groups.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/create_secc_block_groups.do:54)
- [b/create_secc_block_groups.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/create_secc_block_groups.do:55)

### 3. Additional analysis variables

Created by `b/gen_pg_cons_variables.do`:

- `$tmp/secc/seg_all_block_data_{rural,urban}_{200,4000}.dta`
- `$tmp/secc/seg_all_city_data_{rural,urban}_{200,4000}.dta`

Inputs:

- pooled block masters for block outputs
- merged city masters for city outputs

Key logic:

- removes outlier and low-population blocks
- creates `cons_pcap`, log consumption, group-specific consumption variables
- creates group shares
- creates education/public-good count, dummy, and log variables
- drops many raw input columns after feature construction

References:

- [b/gen_pg_cons_variables.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_pg_cons_variables.do:52)
- [b/gen_pg_cons_variables.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_pg_cons_variables.do:64)
- [b/gen_pg_cons_variables.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_pg_cons_variables.do:81)
- [b/gen_pg_cons_variables.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_pg_cons_variables.do:94)
- [b/gen_pg_cons_variables.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_pg_cons_variables.do:136)
- [b/gen_pg_cons_variables.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_pg_cons_variables.do:149)
- [b/gen_pg_cons_variables.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_pg_cons_variables.do:181)
- [b/gen_pg_cons_variables.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_pg_cons_variables.do:203)

### 4. Segregation blockdata outputs

Created by `b/gen_seg_variables.do`:

- `$tmp/secc/segregation_blockdata_{rural,urban}_{200,4000}.dta`

Direct input:

- `$tmp/secc/seg_all_block_data_{rural,urban}_{200,4000}.dta`

Key logic:

- computes `block_units` by town/subdistrict
- computes dissimilarity, interaction, isolation, correlation, and gini indices for SC and Muslim populations
- blanks city-level indices when fewer than 4 blocks are observed
- computes entropy index and ELF/fractionalisation

References:

- [b/gen_seg_variables.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_variables.do:33)
- [b/gen_seg_variables.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_variables.do:55)
- [b/gen_seg_variables.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_variables.do:62)
- [b/gen_seg_variables.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_variables.do:69)
- [b/gen_seg_variables.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_variables.do:72)
- [b/gen_seg_variables.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_variables.do:83)
- [b/gen_seg_variables.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_variables.do:114)
- [b/gen_seg_variables.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_variables.do:141)
- [b/gen_seg_variables.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_variables.do:149)

### 5. Segregation citydata outputs

Created by `b/gen_segregation_city_block_data.do`:

- `$tmp/secc/segregation_citydata_{rural,urban}_{200,4000}.dta`

Direct inputs:

- `$tmp/secc/segregation_blockdata_{rural,urban}_{200,4000}.dta`
- `$tmp/secc/seg_all_city_data_{rural,urban}_{200,4000}.dta`
- `$shrug/data/shrug_pc11_td.dta`
- `$shrug/data/shrug_pc11_vd.dta`
- `$shrug/data/shrug_pc11_pca.dta`
- `$shrug/keys/shrug_pc11_subdistrict_key.dta`
- `$tmp/pc11/pc11_muslims_{rural,urban}.dta`

Key logic:

- deduplicates blockdata to one row per town/subdistrict for segregation measures
- merges in city-level SECC-EC covariates from `seg_all_city_data_*`
- for urban: merges SHRUG town directory and PCA data, then creates city-level population, school, hospital, and origin-year variables
- for rural: collapses village directory data to subdistrict, merges those totals, and creates analogous PC11 covariates
- merges Muslim-share PC11 data
- writes final city-level analysis-ready datasets

References:

- [b/gen_segregation_city_block_data.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_segregation_city_block_data.do:48)
- [b/gen_segregation_city_block_data.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_segregation_city_block_data.do:55)
- [b/gen_segregation_city_block_data.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_segregation_city_block_data.do:65)
- [b/gen_segregation_city_block_data.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_segregation_city_block_data.do:77)
- [b/gen_segregation_city_block_data.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_segregation_city_block_data.do:118)
- [b/gen_segregation_city_block_data.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_segregation_city_block_data.do:128)
- [b/gen_segregation_city_block_data.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_segregation_city_block_data.do:160)
- [b/gen_segregation_city_block_data.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_segregation_city_block_data.do:163)

## Retention recommendation

### Keep as analysis-ready derived datasets

Keep these:

- `segregation_blockdata_{rural,urban}_{200,4000}.dta`
- `segregation_citydata_{rural,urban}_{200,4000}.dta`

Reason:

- they are not simple subsets
- they embed substantial feature engineering and index construction
- downstream `a/*.do` analysis scripts read them directly as ready-made inputs

### Also keep the upstream pooled master if you want rebuild flexibility

Useful upstream retained master:

- `secc_ec_blockdata_{rural,urban}_pooled_{200,4000}.dta`

Reason:

- this is the nearest reusable master before segregation-index construction
- but it is not a substitute for the final segregation datasets, because later steps add nontrivial derived variables and external merges

### Optional intermediates

Consider retaining these only if you want auditability of transformations:

- `seg_all_block_data_{rural,urban}_{200,4000}.dta`
- `seg_all_city_data_{rural,urban}_{200,4000}.dta`

Reason:

- they are intermediate feature-engineered datasets between pooled masters and final segregation outputs
- useful for debugging or partial rebuilds
- not necessary if storage discipline is strict and you already keep both the pooled masters and the final segregation outputs
