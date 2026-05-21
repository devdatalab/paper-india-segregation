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

## Stata Variable-Name Length Compatibility

Stata limits variable names to 32 characters. The latest workbook pass shortens every over-limit `label_aware_renamed_variable_name` while preserving the audited label-aware intent.

Shortening rules used in this pass:

- Keep existing names unchanged when they are already valid Stata names and unique within their sheet.
- Apply readable abbreviations for recurring long concepts, including `district -> dist`, `subdistrict -> subd`, `segregation -> seg`, `dissimilarity -> dissim`, `isolation -> iso`, `population -> pop`, `weighted -> wtd`, `urban -> urb`, and `rural -> rur`.
- Add a short deterministic hash suffix only when abbreviation alone would still exceed 32 characters or collide within the same sheet.
- Leave blanks unchanged for rows without an active label-aware rename suggestion.

Workbook verification after this pass: 149 over-limit values updated; all nonblank `label_aware_renamed_variable_name` values are <=32 characters, Stata-name safe, and unique within sheet.

| Sheet | Row | Previous label-aware suggestion | Stata-compatible label-aware suggestion | Length |
| --- | ---: | --- | --- | ---: |
| `city_seg_district_rural_urban_2` | 3 | `secc_district_mean_rural_subdistrict_sc_dissimilarity` | `secc_dist_mean_rur_subd_s_01871d` | 32 |
| `city_seg_district_rural_urban_2` | 4 | `secc_district_mean_rural_subdistrict_muslim_dissimilarity` | `secc_dist_mean_rur_subd_m_ddc347` | 32 |
| `city_seg_district_rural_urban_2` | 5 | `secc_district_mean_rural_subdistrict_sc_isolation` | `secc_dist_mean_rur_subd_sc_iso` | 30 |
| `city_seg_district_rural_urban_2` | 6 | `secc_district_mean_rural_subdistrict_muslim_isolation` | `secc_dist_mean_rur_subd_m_b09eef` | 32 |
| `city_seg_district_rural_urban_2` | 7 | `secc_district_mean_urban_town_sc_dissimilarity` | `secc_dist_mean_urb_town_s_149bb1` | 32 |
| `city_seg_district_rural_urban_2` | 8 | `secc_district_mean_urban_town_muslim_dissimilarity` | `secc_dist_mean_urb_town_m_c16f38` | 32 |
| `city_seg_district_rural_urban_2` | 9 | `secc_district_mean_urban_town_sc_isolation` | `secc_dist_mean_urb_town_sc_iso` | 30 |
| `city_seg_district_rural_urban_2` | 10 | `secc_district_mean_urban_town_muslim_isolation` | `secc_dist_mean_urb_town_m_d981e1` | 32 |
| `city_seg_district_rural_urban_4` | 3 | `secc_district_mean_rural_subdistrict_sc_dissimilarity` | `secc_dist_mean_rur_subd_s_01871d` | 32 |
| `city_seg_district_rural_urban_4` | 4 | `secc_district_mean_rural_subdistrict_muslim_dissimilarity` | `secc_dist_mean_rur_subd_m_ddc347` | 32 |
| `city_seg_district_rural_urban_4` | 5 | `secc_district_mean_rural_subdistrict_sc_isolation` | `secc_dist_mean_rur_subd_sc_iso` | 30 |
| `city_seg_district_rural_urban_4` | 6 | `secc_district_mean_rural_subdistrict_muslim_isolation` | `secc_dist_mean_rur_subd_m_b09eef` | 32 |
| `city_seg_district_rural_urban_4` | 7 | `secc_district_mean_urban_town_sc_dissimilarity` | `secc_dist_mean_urb_town_s_149bb1` | 32 |
| `city_seg_district_rural_urban_4` | 8 | `secc_district_mean_urban_town_muslim_dissimilarity` | `secc_dist_mean_urb_town_m_c16f38` | 32 |
| `city_seg_district_rural_urban_4` | 9 | `secc_district_mean_urban_town_sc_isolation` | `secc_dist_mean_urb_town_sc_iso` | 30 |
| `city_seg_district_rural_urban_4` | 10 | `secc_district_mean_urban_town_muslim_isolation` | `secc_dist_mean_urb_town_m_d981e1` | 32 |
| `dissim_iso_block_groups.dta` | 2 | `seg_block_group_min_population_threshold` | `seg_blk_grp_min_pop_thresh` | 26 |
| `dissim_iso_block_groups.dta` | 3 | `seg_block_group_mean_population_estimate` | `seg_blk_grp_mean_pop_est` | 24 |
| `dissim_iso_block_groups.dta` | 5 | `secc_sc_weighted_mean_urban_town_dissimilarity` | `secc_sc_wtd_mean_urb_town_dissim` | 32 |
| `dissim_iso_block_groups.dta` | 6 | `secc_muslim_weighted_mean_urban_town_dissimilarity` | `secc_muslim_wtd_mean_urb_032b94` | 31 |
| `dissim_iso_block_groups.dta` | 7 | `secc_sc_weighted_mean_urban_town_isolation` | `secc_sc_wtd_mean_urb_town_iso` | 29 |
| `dissim_iso_block_groups.dta` | 8 | `secc_muslim_weighted_mean_urban_town_isolation` | `secc_muslim_wtd_mean_urb_1b194b` | 31 |
| `msa_tract_race_pop.dta` | 15 | `us_census_tract_nonblack_population` | `us_cen_tr_nonblack_pop` | 22 |
| `msa_tract_race_pop.dta` | 20 | `us_census_msa_black_dissimilarity` | `us_cen_msa_blk_dissim` | 21 |
| `pc11-district.prj` | 2 | `pc11_district_prj_projection_file` | `pc11_dist_prj_proj_file` | 23 |
| `pc11-district.shx` | 2 | `pc11_district_shx_shape_index_file` | `pc11_dist_shx_shp_idx_file` | 26 |
| `pc11-subdistrict.prj` | 2 | `pc11_subdistrict_prj_projection_file` | `pc11_subd_prj_proj_file` | 23 |
| `pc11-subdistrict.shx` | 2 | `pc11_subdistrict_shx_shape_index_file` | `pc11_subd_shx_shp_idx_file` | 26 |
| `pc11_pdf_shrid_key.dta` | 18 | `pc11_pdf_pca_total_population_difference` | `pc11_pdf_pca_tot_pop_difference` | 31 |
| `seg_comparisons_d.csv` | 2 | `seg_comparisons_d_csv_missing_file` | `seg_comparisons_d_csv_miss_file` | 31 |
| `seg_comparisons_i_raw.csv` | 2 | `seg_comparisons_i_raw_csv_missing_file` | `seg_comprsns_i_raw_csv_miss_file` | 32 |
| `seg_correlates.dta` | 5 | `secc_city_sc_consumption_per_capita` | `secc_city_sc_consmptn_per_capita` | 32 |
| `seg_correlates.dta` | 6 | `secc_city_muslim_consumption_per_capita` | `secc_city_muslim_consmptn_f1ca55` | 32 |
| `seg_correlates.dta` | 9 | `secc_city_sc_mean_education_years` | `secc_city_sc_mean_eductn_years` | 30 |
| `seg_correlates.dta` | 10 | `secc_city_muslim_mean_education_years` | `secc_city_muslim_mean_edu_6ce9cc` | 32 |
| `seg_correlates.dta` | 12 | `secc_city_slum_share_or_indicator` | `secc_city_slum_shr_or_indicator` | 31 |
| `seg_correlates.dta` | 15 | `secc_log_city_consumption_per_capita` | `secc_log_city_consmptn_pe_64512b` | 32 |
| `seg_correlates.dta` | 16 | `secc_log_city_sc_consumption_per_capita` | `secc_log_city_sc_consmptn_12dea3` | 32 |
| `seg_correlates.dta` | 17 | `secc_log_city_muslim_consumption_per_capita` | `secc_log_city_muslim_cons_7561a7` | 32 |
| `seg_correlates.dta` | 18 | `secc_log_city_non_sc_non_muslim_consumption_per_capita` | `secc_log_city_non_sc_non_21a827` | 31 |
| `seg_correlates.dta` | 31 | `secc_city_muslim_population_share` | `secc_city_muslim_pop_shr` | 24 |
| `seg_correlates.dta` | 53 | `violence_non_religious_event_count` | `violence_non_rel_event_count` | 28 |
| `seg_correlates.dta` | 64 | `pc91_pc11_log_population_growth_rate` | `pc91_pc11_log_pop_growth_rate` | 29 |
| `segregation_blockdata_rural_200` | 12 | `secc_block_muslim_population_count` | `secc_blk_muslim_pop_count` | 25 |
| `segregation_blockdata_rural_200` | 15 | `secc_block_non_sc_non_muslim_population_count` | `secc_blk_non_sc_non_musli_caa4ef` | 32 |
| `segregation_blockdata_rural_200` | 16 | `secc_missing_sc_classification_population` | `secc_miss_sc_classification_pop` | 31 |
| `segregation_blockdata_rural_200` | 17 | `secc_missing_muslim_classification_population` | `secc_miss_muslim_classfct_pop` | 29 |
| `segregation_blockdata_rural_200` | 18 | `secc_missing_education_population` | `secc_miss_education_pop` | 23 |
| `segregation_blockdata_rural_200` | 25 | `secc_block_non_sc_non_muslim_population` | `secc_blk_non_sc_non_muslim_pop` | 30 |
| `segregation_blockdata_rural_200` | 31 | `secc_block_sc_consumption_per_capita` | `secc_blk_sc_consmptn_per_capita` | 31 |
| `segregation_blockdata_rural_200` | 33 | `secc_block_muslim_consumption_per_capita` | `secc_blk_muslim_consmptn_9b2b3e` | 31 |
| `segregation_blockdata_rural_200` | 35 | `secc_block_non_sc_non_muslim_consumption_per_capita` | `secc_blk_non_sc_non_musli_28682c` | 32 |
| `segregation_blockdata_rural_200` | 39 | `secc_block_muslim_population_share` | `secc_blk_muslim_pop_shr` | 23 |
| `segregation_blockdata_rural_200` | 44 | `ec13_block_secondary_school_count` | `ec13_blk_secondary_school_count` | 31 |
| `segregation_blockdata_rural_200` | 67 | `ec13_log_public_primary_school_employment` | `ec13_log_public_primry_sc_89ba24` | 32 |
| `segregation_blockdata_rural_200` | 70 | `ec13_log_public_secondary_school_employment` | `ec13_log_public_secondry_16144a` | 31 |
| `segregation_blockdata_rural_200` | 76 | `ec13_log_public_hospital_employment` | `ec13_log_public_hosptl_emplymnt` | 31 |
| `segregation_blockdata_rural_200` | 81 | `ec13_has_private_secondary_school` | `ec13_has_privt_secondry_school` | 30 |
| `segregation_blockdata_rural_200` | 91 | `ec13_log_private_primary_school_employment` | `ec13_log_privt_primry_sch_4bc0b4` | 32 |
| `segregation_blockdata_rural_200` | 94 | `ec13_log_private_secondary_school_employment` | `ec13_log_privt_secondry_s_0aaf15` | 32 |
| `segregation_blockdata_rural_200` | 100 | `ec13_log_private_hospital_employment` | `ec13_log_privt_hosptl_emplymnt` | 30 |
| `segregation_blockdata_rural_400` | 12 | `secc_block_muslim_population_count` | `secc_blk_muslim_pop_count` | 25 |
| `segregation_blockdata_rural_400` | 16 | `secc_missing_sc_classification_population` | `secc_miss_sc_classification_pop` | 31 |
| `segregation_blockdata_rural_400` | 17 | `secc_missing_muslim_classification_population` | `secc_miss_muslim_classfct_pop` | 29 |
| `segregation_blockdata_rural_400` | 18 | `secc_missing_education_population` | `secc_miss_education_pop` | 23 |
| `segregation_blockdata_rural_400` | 39 | `secc_block_muslim_population_share` | `secc_blk_muslim_pop_shr` | 23 |
| `segregation_blockdata_rural_400` | 44 | `ec13_block_secondary_school_count` | `ec13_blk_secondary_school_count` | 31 |
| `segregation_blockdata_rural_400` | 67 | `ec13_log_public_primary_school_employment` | `ec13_log_public_primry_sc_89ba24` | 32 |
| `segregation_blockdata_rural_400` | 70 | `ec13_log_public_secondary_school_employment` | `ec13_log_public_secondry_16144a` | 31 |
| `segregation_blockdata_rural_400` | 76 | `ec13_log_public_hospital_employment` | `ec13_log_public_hosptl_emplymnt` | 31 |
| `segregation_blockdata_rural_400` | 81 | `ec13_has_private_secondary_school` | `ec13_has_privt_secondry_school` | 30 |
| `segregation_blockdata_rural_400` | 91 | `ec13_log_private_primary_school_employment` | `ec13_log_privt_primry_sch_4bc0b4` | 32 |
| `segregation_blockdata_rural_400` | 94 | `ec13_log_private_secondary_school_employment` | `ec13_log_privt_secondry_s_0aaf15` | 32 |
| `segregation_blockdata_rural_400` | 100 | `ec13_log_private_hospital_employment` | `ec13_log_privt_hosptl_emplymnt` | 30 |
| `segregation_blockdata_urban_200` | 12 | `secc_block_muslim_population_count` | `secc_blk_muslim_pop_count` | 25 |
| `segregation_blockdata_urban_200` | 15 | `secc_block_non_sc_non_muslim_population_count` | `secc_blk_non_sc_non_musli_caa4ef` | 32 |
| `segregation_blockdata_urban_200` | 16 | `secc_missing_sc_classification_population` | `secc_miss_sc_classification_pop` | 31 |
| `segregation_blockdata_urban_200` | 17 | `secc_missing_muslim_classification_population` | `secc_miss_muslim_classfct_pop` | 29 |
| `segregation_blockdata_urban_200` | 18 | `secc_missing_education_population` | `secc_miss_education_pop` | 23 |
| `segregation_blockdata_urban_200` | 25 | `secc_block_non_sc_non_muslim_population` | `secc_blk_non_sc_non_muslim_pop` | 30 |
| `segregation_blockdata_urban_200` | 34 | `secc_block_water_source_at_home_share` | `secc_blk_wtr_source_at_home_shr` | 31 |
| `segregation_blockdata_urban_200` | 46 | `secc_block_electric_lighting_share` | `secc_blk_electric_lighting_shr` | 30 |
| `segregation_blockdata_urban_200` | 52 | `secc_block_slum_share_or_indicator` | `secc_blk_slum_shr_or_indicator` | 30 |
| `segregation_blockdata_urban_200` | 54 | `secc_block_consumption_per_capita` | `secc_blk_consumption_per_capita` | 31 |
| `segregation_blockdata_urban_200` | 55 | `secc_log_block_consumption_per_capita` | `secc_log_blk_consmptn_per_capita` | 32 |
| `segregation_blockdata_urban_200` | 56 | `secc_block_sc_consumption_per_capita` | `secc_blk_sc_consmptn_per_capita` | 31 |
| `segregation_blockdata_urban_200` | 58 | `secc_block_muslim_consumption_per_capita` | `secc_blk_muslim_consmptn_9b2b3e` | 31 |
| `segregation_blockdata_urban_200` | 60 | `secc_block_non_sc_non_muslim_consumption_per_capita` | `secc_blk_non_sc_non_musli_28682c` | 32 |
| `segregation_blockdata_urban_200` | 64 | `secc_block_muslim_population_share` | `secc_blk_muslim_pop_shr` | 23 |
| `segregation_blockdata_urban_200` | 69 | `ec13_block_secondary_school_count` | `ec13_blk_secondary_school_count` | 31 |
| `segregation_blockdata_urban_200` | 92 | `ec13_log_public_primary_school_employment` | `ec13_log_public_primry_sc_89ba24` | 32 |
| `segregation_blockdata_urban_200` | 95 | `ec13_log_public_secondary_school_employment` | `ec13_log_public_secondry_16144a` | 31 |
| `segregation_blockdata_urban_200` | 101 | `ec13_log_public_hospital_employment` | `ec13_log_public_hosptl_emplymnt` | 31 |
| `segregation_blockdata_urban_200` | 106 | `ec13_has_private_secondary_school` | `ec13_has_privt_secondry_school` | 30 |
| `segregation_blockdata_urban_200` | 116 | `ec13_log_private_primary_school_employment` | `ec13_log_privt_primry_sch_4bc0b4` | 32 |
| `segregation_blockdata_urban_200` | 119 | `ec13_log_private_secondary_school_employment` | `ec13_log_privt_secondry_s_0aaf15` | 32 |
| `segregation_blockdata_urban_200` | 125 | `ec13_log_private_hospital_employment` | `ec13_log_privt_hosptl_emplymnt` | 30 |
| `segregation_blockdata_urban_400` | 12 | `secc_block_muslim_population_count` | `secc_blk_muslim_pop_count` | 25 |
| `segregation_blockdata_urban_400` | 16 | `secc_missing_sc_classification_population` | `secc_miss_sc_classification_pop` | 31 |
| `segregation_blockdata_urban_400` | 17 | `secc_missing_muslim_classification_population` | `secc_miss_muslim_classfct_pop` | 29 |
| `segregation_blockdata_urban_400` | 18 | `secc_missing_education_population` | `secc_miss_education_pop` | 23 |
| `segregation_blockdata_urban_400` | 34 | `secc_block_water_source_at_home_share` | `secc_blk_wtr_source_at_home_shr` | 31 |
| `segregation_blockdata_urban_400` | 46 | `secc_block_electric_lighting_share` | `secc_blk_electric_lighting_shr` | 30 |
| `segregation_blockdata_urban_400` | 64 | `secc_block_muslim_population_share` | `secc_blk_muslim_pop_shr` | 23 |
| `segregation_blockdata_urban_400` | 69 | `ec13_block_secondary_school_count` | `ec13_blk_secondary_school_count` | 31 |
| `segregation_blockdata_urban_400` | 92 | `ec13_log_public_primary_school_employment` | `ec13_log_public_primry_sc_89ba24` | 32 |
| `segregation_blockdata_urban_400` | 95 | `ec13_log_public_secondary_school_employment` | `ec13_log_public_secondry_16144a` | 31 |
| `segregation_blockdata_urban_400` | 101 | `ec13_log_public_hospital_employment` | `ec13_log_public_hosptl_emplymnt` | 31 |
| `segregation_blockdata_urban_400` | 106 | `ec13_has_private_secondary_school` | `ec13_has_privt_secondry_school` | 30 |
| `segregation_blockdata_urban_400` | 116 | `ec13_log_private_primary_school_employment` | `ec13_log_privt_primry_sch_4bc0b4` | 32 |
| `segregation_blockdata_urban_400` | 119 | `ec13_log_private_secondary_school_employment` | `ec13_log_privt_secondry_s_0aaf15` | 32 |
| `segregation_blockdata_urban_400` | 125 | `ec13_log_private_hospital_employment` | `ec13_log_privt_hosptl_emplymnt` | 30 |
| `segregation_citydata_rural_200.` | 4 | `secc_subdistrict_sc_dissimilarity` | `secc_subd_sc_dissim` | 19 |
| `segregation_citydata_rural_200.` | 11 | `secc_subdistrict_muslim_dissimilarity` | `secc_subd_muslim_dissim` | 23 |
| `segregation_citydata_rural_200.` | 14 | `secc_subdistrict_muslim_isolation` | `secc_subd_muslim_iso` | 20 |
| `segregation_citydata_rural_200.` | 26 | `secc_missing_sc_classification_population` | `secc_miss_sc_classification_pop` | 31 |
| `segregation_citydata_rural_200.` | 27 | `secc_missing_muslim_classification_population` | `secc_miss_muslim_classfct_pop` | 29 |
| `segregation_citydata_rural_200.` | 35 | `secc_missing_education_population` | `secc_miss_education_pop` | 23 |
| `segregation_citydata_rural_200.` | 47 | `secc_city_muslim_population_share` | `secc_city_muslim_pop_shr` | 24 |
| `segregation_citydata_rural_200.` | 116 | `pc11_vd_subdistrict_allopathic_hospital_count` | `pc11_vd_subd_allopthc_hos_eab824` | 32 |
| `segregation_citydata_rural_200.` | 119 | `pc11_vd_subdistrict_primary_school_count` | `pc11_vd_subd_primry_school_count` | 32 |
| `segregation_citydata_rural_200.` | 120 | `pc11_vd_subdistrict_middle_school_count` | `pc11_vd_subd_middle_school_count` | 32 |
| `segregation_citydata_rural_200.` | 121 | `pc11_vd_subdistrict_secondary_school_count` | `pc11_vd_subd_secondry_sch_4539aa` | 32 |
| `segregation_citydata_rural_200.` | 132 | `pc11_log_vd_subdistrict_population` | `pc11_log_vd_subd_pop` | 20 |
| `segregation_citydata_urban_200.` | 21 | `secc_city_muslim_population_count` | `secc_city_muslim_pop_count` | 26 |
| `segregation_citydata_urban_200.` | 25 | `secc_missing_sc_classification_population` | `secc_miss_sc_classification_pop` | 31 |
| `segregation_citydata_urban_200.` | 26 | `secc_missing_muslim_classification_population` | `secc_miss_muslim_classfct_pop` | 29 |
| `segregation_citydata_urban_200.` | 34 | `secc_missing_education_population` | `secc_miss_education_pop` | 23 |
| `segregation_citydata_urban_200.` | 41 | `secc_city_water_source_at_home_share` | `secc_city_wtr_source_at_home_shr` | 32 |
| `segregation_citydata_urban_200.` | 53 | `secc_city_electric_lighting_share` | `secc_city_electric_lighting_shr` | 31 |
| `segregation_citydata_urban_200.` | 71 | `secc_city_muslim_population_share` | `secc_city_muslim_pop_shr` | 24 |
| `segregation_citydata_urban_200.` | 139 | `pc11_td_allopathic_hospital_count` | `pc11_td_allopthc_hosptl_count` | 29 |
| `segregation_citydata_urban_4000` | 21 | `secc_city_muslim_population_count` | `secc_city_muslim_pop_count` | 26 |
| `segregation_citydata_urban_4000` | 25 | `secc_missing_sc_classification_population` | `secc_miss_sc_classification_pop` | 31 |
| `segregation_citydata_urban_4000` | 26 | `secc_missing_muslim_classification_population` | `secc_miss_muslim_classfct_pop` | 29 |
| `segregation_citydata_urban_4000` | 34 | `secc_missing_education_population` | `secc_miss_education_pop` | 23 |
| `segregation_citydata_urban_4000` | 71 | `secc_city_muslim_population_share` | `secc_city_muslim_pop_shr` | 24 |
| `shrug_pc11_td.dta` | 100 | `pc11_td_allopathic_hospital_count` | `pc11_td_allopthc_hosptl_count` | 29 |
| `shrug_pc11_vd.dta` | 77 | `pc11_vd_village_allopathic_hospital_count` | `pc11_vd_vill_allopthc_hos_0ba046` | 32 |
| `shrug_pc11_vd.dta` | 385 | `pc11_vd_village_primary_school_count` | `pc11_vd_vill_primry_school_count` | 32 |
| `shrug_pc11_vd.dta` | 386 | `pc11_vd_village_middle_school_count` | `pc11_vd_vill_middle_school_count` | 32 |
| `shrug_pc11_vd.dta` | 387 | `pc11_vd_village_secondary_school_count` | `pc11_vd_vill_secondry_sch_0a430b` | 32 |
| `us_census_msa_dissim.dta` | 9 | `us_census_msa_black_dissimilarity` | `us_cen_msa_blk_dissim` | 21 |
| `us_tpop_b.dta` | 2 | `us_census_tract_black_share_bin_midpoint` | `us_cen_tr_blk_shr_bin_midpoint` | 30 |
| `us_tpop_b.dta` | 3 | `us_census_black_only_population_share_in_tract_bin` | `us_cen_blk_only_pop_shr_i_5ea55e` | 32 |
| `us_tract_pop.dta` | 5 | `us_census_tract_black_only_population` | `us_cen_tr_blk_only_pop` | 22 |
| `us_tract_pop.dta` | 7 | `us_census_tract_nonblack_population` | `us_cen_tr_nonblack_pop` | 22 |
| `us_tract_pop.dta` | 8 | `us_census_tract_black_white_population` | `us_cen_tr_blk_white_pop` | 23 |
| `us_tract_pop.dta` | 12 | `us_census_black_only_population_share_in_tract_bin` | `us_cen_blk_only_pop_shr_i_5ea55e` | 32 |
