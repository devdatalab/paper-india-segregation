# Variable Listing Rename Harmonization

Source workbook: `/dartfs-hpc/scratch/siddiqui/variable_listing.xlsx`

This pass adds structured suggestions for rows marked `used_analysis = 1` without changing source `.dta` files or audited review columns. The only label override is the known `bad_ed` conflict.

## PC11-Derived Names

PC11 fields now use explicit lineage and readable concepts. For example, `pc11_pca_tot_p` is suggested as `pc11_pca_total_population`, while generated area controls such as `log_area_pc11` are suggested as `pc11_log_city_area`.

The producer logic in `b/gen_segregation_city_block_data.do` shows that urban city controls come from `shrug_pc11_td`, rural controls come from collapsed `shrug_pc11_vd`, and PCA population enters separately from `shrug_pc11_pca`.

## Per-100k Correction

The public-good rate variables with `_pc` suffixes are not per capita in the usual unit sense. The producer script computes them as service counts times `100000 / pc11_pca_tot_p`, so the suggestions use per-100k names:

| Current | Suggested |
| --- | --- |
| `prim_pc` | `pc11_primary_schools_per_100k` |
| `mid_pc` | `pc11_middle_schools_per_100k` |
| `sec_pc` | `pc11_secondary_schools_per_100k` |
| `hosp_pc` | `pc11_hospitals_per_100k` |

## `bad_ed` Label Cleanup

The active workbook marks `bad_ed` as `used_analysis = 0`, so this pass does not fill a used-variable rename for it. It does normalize `renamed_variable_label` to `Population count with missing education` in every data sheet where the variable appears, resolving the prior urban label text `(nansum) (nansum) bad_ed`.

## Storage Harmonization

`harmonized_storage_type` is grouped by the proposed name. The main storage rules are:

| Example group | Source storage types | Harmonized storage |
| --- | --- | --- |
| `us_census_cbsa_name` | `str46`, `str57` | `str57` |
| `shrug_id` | `str12`, `str14`, `str16` | `str16` |
| `pc11_pca_total_population` | `long`, `float`, `double` | `long` |
| `pc11_secondary_schools_per_100k` | `float` | `float` |

The integer rule treats identifiers, counts, and population totals as integer concepts, using `long` when numeric widths conflict or source data accidentally store counts as `float`.

## ID And Name Suffix Cleanup

Identifier and name suggestions put the object suffix last and keep source lineage up front:

| Current | Suggested |
| --- | --- |
| `shrid` | `shrug_id` |
| `town` | `shrug_town_id` |
| `subdistrict` | `pc11_subdistrict_composite_id` |
| `town_name_pc11_pdf` | `pc11_pdf_town_name` |
| `cbsatitle` | `us_census_cbsa_name` |

The `town` suggestion intentionally avoids `pc11_town_id`, because several urban sheets also contain the official `pc11_town_id`; `town` is the generated SHRUG-level upper key in the segregation pipeline.

## Label-Aware Review Pass

A second pass adds `label_aware_renamed_variable_name` and `label_aware_harmonized_storage_type`. These columns preserve the original `renamed_variable_name` suggestions while staging a stricter review that uses `renamed_variable_label`, fallback source labels, sheet context, and producer lineage.

The second pass covers every `used_analysis = 1` row plus all `bad_*` rows. The `bad_*` rows remain non-used, but receive explicit name suggestions:

| Current | Label-aware suggestion |
| --- | --- |
| `bad_ed` | `secc_missing_education_population` |
| `bad_sc` | `secc_missing_sc_classification_population` |
| `bad_muslim` | `secc_missing_muslim_classification_population` |

The pass also tightens several names where labels clarify geography or concept:

| Current | Earlier suggestion | Label-aware suggestion |
| --- | --- | --- |
| `city_dissim_sc` in rural city sheets | `seg_city_sc_dissimilarity` | `secc_subdistrict_sc_dissimilarity` |
| `city_iso_muslim` in urban city sheets | `seg_city_muslim_isolation` | `secc_town_muslim_isolation` |
| `mean_pop` | `seg_block_group_mean_population` | `seg_block_group_mean_population_estimate` |
| `hh` in city sheets | `secc_household_count` | `secc_city_household_count` |
| `closed_drain` in block sheets | `secc_closed_drain_share` | `secc_block_closed_drain_share` |
