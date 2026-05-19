# Variable Rename Suggestions

## Scope

This note audits the current variable names in `inventory/variable_listing_csv/`, the CSV mirror of `inventory/variable_listing.xlsx`. It does not change any source data, Stata code, or generated datasets.

The workbook now has a `variable_rename` column for the proposed DDL-style replacement name. The existing `rename_suggestion` column is still present for manual notes; where this pass produced a concrete proposed name, the same value was mirrored there for compatibility.

## Review Rules

- Keep names lowercase snake_case.
- Prefix identifiers and names with source or geography when the same concept can appear in multiple datasets.
- Put `id` and `name` at the end of variable names.
- Do not preserve raw source names when they obscure meaning.
- Keep raw PC table-code fields, such as many `pc11_pca_*`, `pc11_td_*`, and `pc11_vd_*` variables, unless there is a specific analysis-facing reason to rename them. Those names are terse, but they preserve source dictionary traceability.

## Thematic Changes

### Identifiers Should End In `id`

| Current pattern | rename_variable_name | Datasets | Rationale |
| --- | --- | --- | --- |
| `shrid` | `shrug_id` | SHRUG keys, spatial files, city/block data, correlates | Expands the source prefix and puts `id` at the end. |
| `shrid2` | `shrug_alt_id` | `pc01_hb_eb_pop.dta` | Marks this as an alternate SHRUG id; confirm exact meaning before applying. |
| `town` | `shrug_town_id` | Urban Muslim-share, block, and city datasets | Current `town` is an id-like fixed-effect key and can be confused with a name or `pc11_town_id`. |
| `subdistrict` | `pc11_subdistrict_composite_id` | Rural Muslim-share, block, and city datasets | Current name is a concatenated id-like control, not a name. |
| `block_no` | `seg_block_group_id` | Segregation block datasets | Generated neighborhood/block-group key; `no` is less clear than `id`. |
| `pc11_block_id_num` | `pc11_block_numeric_id` | Segregation block datasets | Keeps the PC11 source prefix and puts `id` at the end. |
| `eb_no`, `eb_number` | `pc01_eb_id` or `pc11_eb_id` | PC01/PC11 handbook EB files | EB identifier should be source-prefixed and use `_id`. |
| `location_code`, `location_code_tmp` | `pc01_location_id`, `pc11_location_id`, `pc01_temp_location_id`, `pc11_temp_location_id` | PC01/PC11 handbook EB files | Source-specific code fields are ids and should be prefixed. |
| `fips_code` | `county_fips_id` | US MSA/tract files | This is a county FIPS identifier, not a generic code. |
| `tdist_*_shrid` | `nearest_*_pop_shrug_id` | `shrug_spatial.dta` | Names nearest-location SHRUG ids by population threshold. |

### Name Fields Should End In `name`

| Current pattern | rename_variable_name | Datasets | Rationale |
| --- | --- | --- | --- |
| `cbsatitle` | `cbsa_name` | US MSA files | Lower snake_case and uses the standard `_name` suffix. |
| `statename` | `us_state_name` | `msa_keys.dta` | Lower snake_case, source-prefixed, and name suffix. |
| `filename` | `pc01_hb_file_name` | `pc01_hb_eb_pop.dta` | Treats filename as a name field and source-prefixes it. |
| `town_name_no_par` | `town_without_parentheses_name` | PC01/PC11 PDF EB files | Avoids `no_par` and keeps `_name` last. |
| `town_name_tmp` | `temp_town_name` | `pc01_pdf_eb_clean.dta` | If retained, make the temporary status explicit. |
| `town_name_pc01_pdf`, `town_name_pc11_pdf` | `pc01_pdf_town_name`, `pc11_pdf_town_name` | PC01/PC11 PDF SHRUG key files | Source words should precede the object; `_name` stays last. |
| `pc11_td_middle_near` | `pc11_td_middle_nearest_place_name` | `shrug_pc11_td.dta` | Label says this is a nearest village/town name. |

### Ambiguous `pc` Suffixes

The suffix `pc` is ambiguous in this repo because `pc01` and `pc11` mean Population Census, while several analysis variables use `_pc` for per capita or per 100k population.

| Current pattern | rename_variable_name | Datasets | Rationale |
| --- | --- | --- | --- |
| `cons_pc`, `cons_pc_sc`, `cons_pc_muslim`, `cons_pc_nonscmuslim` | `cons_per_capita`, `cons_per_capita_sc`, `cons_per_capita_muslim`, `cons_per_capita_nonscmuslim` | `seg_correlates.dta` | Expands per capita. |
| `ln_cons_pc*` | `log_cons_per_capita*` | `seg_correlates.dta` | Use `log`, not `ln`, and expand per capita. |
| `town_cons_pc_gini`, `rural_cons_pc_gini` | `town_cons_per_capita_gini`, `rural_cons_per_capita_gini` | `seg_correlates.dta` | Makes the statistic interpretable without labels. |
| `prim_pc`, `mid_pc`, `sec_pc`, `hosp_pc` | `primary_school_per_100k`, `middle_school_per_100k`, `secondary_school_per_100k`, `hospital_per_100k` | City datasets and `seg_correlates.dta` | These are per-100k public-good measures, not Population Census variables. |

### Invalid/Missing Classification Flags

| Current pattern | rename_variable_name | Datasets | Rationale |
| --- | --- | --- | --- |
| `bad_ed` | `invalid_education_flag` | Segregation block/city datasets | The label indicates missing education classification. |
| `bad_sc` | `invalid_sc_flag` | Segregation block/city datasets | The label indicates missing SC/ST classification. |
| `bad_muslim` | `invalid_muslim_flag` | Segregation block/city datasets | The label indicates missing Muslim classification. |
| `block_pop_with_invalid` | `block_pop_including_unclassified` | Segregation block datasets | `invalid` is vague; label says unclassified people are included. |
| `city_pop_with_invalid` | `city_pop_including_unclassified` | Segregation city datasets | Same issue as block-level population. |

### Binary Public-Goods Variables

The `dum_*` variables are valid snake_case, but `dum` is less clear than a boolean prefix. If these variables are renamed, do it as a family:

| Current pattern | Suggested pattern | Example |
| --- | --- | --- |
| `dum_<service>_pub` | `has_public_<service>` | `dum_primary_pub` -> `has_public_primary_school` |
| `dum_<service>_priv` | `has_private_<service>` | `dum_hospital_priv` -> `has_private_hospital` |
| `dum_<service>_emp_pub` | `has_public_<service>_employment` | `dum_secondary_emp_pub` -> `has_public_secondary_school_employment` |
| `dum_<service>_emp_priv` | `has_private_<service>_employment` | `dum_primary_emp_priv` -> `has_private_primary_school_employment` |

Do not rename only a subset of this family; these names are used together in analysis scripts.

## Dataset Queue

The workbook column is the complete row-level queue. The list below captures the main high-confidence dataset families from the first narrative pass.

### `msa_keys.dta`

- `cbsatitle` -> `cbsa_name`
- `fips_code` -> `county_fips_id`
- `statename` -> `us_state_name`

### `msa_tract_race_pop.dta`

- `cbsatitle` -> `cbsa_name`
- `fips_code` -> `county_fips_id`

### `us_tract_pop.dta`

- `fips_code` -> `county_fips_id`

### `pc01_hb_eb_pop.dta`

- `eb_no` -> `pc01_eb_id`
- `eb_units_shrid` -> `pc01_shrug_eb_count`
- `filename` -> `pc01_hb_file_name`
- `idm` -> `pc01_hb_match_id`
- `location_code` -> `pc01_location_id`
- `sc_pop_shrid_pc01` -> `pc01_shrug_sc_pop`
- `shrid2` -> `shrug_alt_id`
- `tot_pop_shrid_pc01` -> `pc01_shrug_total_pop`

### `pc01_pdf_eb_clean.dta`

- `eb_number` -> `pc01_eb_id`
- `location_code` -> `pc01_location_id`
- `location_code_tmp` -> `pc01_temp_location_id`
- `page_no` -> `pc01_pdf_page_number`
- `town_name_no_par` -> `town_without_parentheses_name`
- `town_name_tmp` -> `temp_town_name`

### `pc11_pdf_eb_clean.dta`

- `eb_number` -> `pc11_eb_id`
- `location_code` -> `pc11_location_id`
- `location_code_tmp` -> `pc11_temp_location_id`
- `page_no` -> `pc11_pdf_page_number`
- `town_name_no_par` -> `town_without_parentheses_name`

### `pc01_pdf_shrid_key.dta`

- `shrid` -> `shrug_id`
- `town_name_pc01_pdf` -> `pc01_pdf_town_name`

### `pc11_pdf_shrid_key.dta`

- `shrid` -> `shrug_id`
- `town_name_pc11_pdf` -> `pc11_pdf_town_name`

### `pc11_muslims_rural.dta`

- `subdistrict` -> `pc11_subdistrict_composite_id`

### `pc11_muslims_urban.dta`

- `shrid` -> `shrug_id`
- `town` -> `shrug_town_id`

### `seg_correlates.dta`

- `cons_pc` -> `cons_per_capita`
- `cons_pc_muslim` -> `cons_per_capita_muslim`
- `cons_pc_nonscmuslim` -> `cons_per_capita_nonscmuslim`
- `cons_pc_sc` -> `cons_per_capita_sc`
- `hosp_pc` -> `hospital_per_100k`
- `ln_cons_pc` -> `log_cons_per_capita`
- `ln_cons_pc_muslim` -> `log_cons_per_capita_muslim`
- `ln_cons_pc_nonscmuslim` -> `log_cons_per_capita_nonscmuslim`
- `ln_cons_pc_sc` -> `log_cons_per_capita_sc`
- `mid_pc` -> `middle_school_per_100k`
- `prim_pc` -> `primary_school_per_100k`
- `rural_cons_pc_gini` -> `rural_cons_per_capita_gini`
- `sec_pc` -> `secondary_school_per_100k`
- `shrid` -> `shrug_id`
- `town_cons_pc_gini` -> `town_cons_per_capita_gini`

### `segregation_blockdata_rural_200.dta` and `segregation_blockdata_rural_4000.dta`

- `bad_ed` -> `invalid_education_flag`
- `bad_muslim` -> `invalid_muslim_flag`
- `bad_sc` -> `invalid_sc_flag`
- `block_no` -> `seg_block_group_id`
- `block_pop_with_invalid` -> `block_pop_including_unclassified`
- `pc11_block_id_num` -> `pc11_block_numeric_id`
- `shrid` -> `shrug_id`
- `subdistrict` -> `pc11_subdistrict_composite_id`

### `segregation_blockdata_urban_200.dta` and `segregation_blockdata_urban_4000.dta`

- `bad_ed` -> `invalid_education_flag`
- `bad_muslim` -> `invalid_muslim_flag`
- `bad_sc` -> `invalid_sc_flag`
- `block_no` -> `seg_block_group_id`
- `block_pop_with_invalid` -> `block_pop_including_unclassified`
- `pc11_block_id_num` -> `pc11_block_numeric_id`
- `shrid` -> `shrug_id`
- `town` -> `shrug_town_id`

### `segregation_citydata_rural_200.dta`

- `bad_ed` -> `invalid_education_flag`
- `bad_muslim` -> `invalid_muslim_flag`
- `bad_sc` -> `invalid_sc_flag`
- `city_pop_with_invalid` -> `city_pop_including_unclassified`
- `hosp_pc` -> `hospital_per_100k`
- `mid_pc` -> `middle_school_per_100k`
- `prim_pc` -> `primary_school_per_100k`
- `sec_pc` -> `secondary_school_per_100k`
- `subdistrict` -> `pc11_subdistrict_composite_id`

### `segregation_citydata_urban_200.dta` and `segregation_citydata_urban_4000.dta`

- `bad_ed` -> `invalid_education_flag`
- `bad_muslim` -> `invalid_muslim_flag`
- `bad_sc` -> `invalid_sc_flag`
- `city_pop_with_invalid` -> `city_pop_including_unclassified`
- `hosp_pc` -> `hospital_per_100k`
- `mid_pc` -> `middle_school_per_100k`
- `prim_pc` -> `primary_school_per_100k`
- `sec_pc` -> `secondary_school_per_100k`
- `shrid` -> `shrug_id`
- `town` -> `shrug_town_id`

### SHRUG key and spatial datasets

Applies to `shrug_names.dta`, `shrug_pc01u_key.dta`, `shrug_pc11_pca.dta`, `shrug_pc11_state_key.dta`, `shrug_pc11_subdistrict_key.dta`, `shrug_pc11_td.dta`, `shrug_pc11_vd.dta`, and `shrug_spatial.dta`.

- `shrid` -> `shrug_id`
- `pc11_td_middle_near` -> `pc11_td_middle_nearest_place_name`
- `tdist_10_shrid` -> `nearest_10k_pop_shrug_id`
- `tdist_50_shrid` -> `nearest_50k_pop_shrug_id`
- `tdist_100_shrid` -> `nearest_100k_pop_shrug_id`
- `tdist_500_shrid` -> `nearest_500k_pop_shrug_id`

## Apply Notes

- Treat these as workbook review proposals first. Applying them to real `.dta` outputs requires a coordinated Stata/Python refactor of producer scripts, consumer scripts, table templates, and merge keys.
- The highest-confidence entries are the `id` and `name` suffix fixes. The most code-sensitive entries are `shrid`, `town`, and `subdistrict`, because analysis scripts use them heavily as merge keys and fixed effects.
- `idm`, `shrid2`, and temporary fields should be confirmed against source-code intent before changing final datasets.

## Completion Log

- Audited 52 dataset sheets and 2,581 variable rows from `inventory/variable_listing_csv/`.
- Found no uppercase or invalid-character variable names; several lower-case concatenated source fields still needed snake_case proposals.
- Wrote this thematic rename queue for manual review and workbook entry.
- Added `variable_rename` to the workbook and CSV mirrors, with 359 filled proposal rows.
