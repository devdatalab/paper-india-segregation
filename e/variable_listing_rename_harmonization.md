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
- Apply readable abbreviations for recurring long concepts, including `district -> dist`, `subdistrict -> subd`, `rural -> r`, `urban -> u`, `dissimilarity -> dissim`, `isolation -> iso`, `muslim -> m`, `population -> pop`, and `weighted -> wtd`.
- Keep substantive group markers such as `sc` and `m` instead of adding opaque hash suffixes.
- Leave blanks unchanged for rows without an active label-aware rename suggestion.

Workbook verification after this pass: 149 over-limit values updated; all nonblank `label_aware_renamed_variable_name` values are <=32 characters, Stata-name safe, unique within sheet, and free of hash suffixes.

| Sheet | Row | Previous label-aware suggestion | Stata-compatible label-aware suggestion | Length |
| --- | ---: | --- | --- | ---: |
| `city_seg_district_rural_urban_2` | 3 | `secc_district_mean_rural_subdistrict_sc_dissimilarity` | `secc_dist_mean_r_subd_sc_dissim` | 31 |
| `city_seg_district_rural_urban_2` | 4 | `secc_district_mean_rural_subdistrict_muslim_dissimilarity` | `secc_dist_mean_r_subd_m_dissim` | 30 |
| `city_seg_district_rural_urban_2` | 5 | `secc_district_mean_rural_subdistrict_sc_isolation` | `secc_dist_mean_r_subd_sc_iso` | 28 |
| `city_seg_district_rural_urban_2` | 6 | `secc_district_mean_rural_subdistrict_muslim_isolation` | `secc_dist_mean_r_subd_m_iso` | 27 |
| `city_seg_district_rural_urban_2` | 7 | `secc_district_mean_urban_town_sc_dissimilarity` | `secc_dist_mean_u_town_sc_dissim` | 31 |
| `city_seg_district_rural_urban_2` | 8 | `secc_district_mean_urban_town_muslim_dissimilarity` | `secc_dist_mean_u_town_m_dissim` | 30 |
| `city_seg_district_rural_urban_2` | 9 | `secc_district_mean_urban_town_sc_isolation` | `secc_dist_mean_u_town_sc_iso` | 28 |
| `city_seg_district_rural_urban_2` | 10 | `secc_district_mean_urban_town_muslim_isolation` | `secc_dist_mean_u_town_m_iso` | 27 |
| `city_seg_district_rural_urban_4` | 3 | `secc_district_mean_rural_subdistrict_sc_dissimilarity` | `secc_dist_mean_r_subd_sc_dissim` | 31 |
| `city_seg_district_rural_urban_4` | 4 | `secc_district_mean_rural_subdistrict_muslim_dissimilarity` | `secc_dist_mean_r_subd_m_dissim` | 30 |
| `city_seg_district_rural_urban_4` | 5 | `secc_district_mean_rural_subdistrict_sc_isolation` | `secc_dist_mean_r_subd_sc_iso` | 28 |
| `city_seg_district_rural_urban_4` | 6 | `secc_district_mean_rural_subdistrict_muslim_isolation` | `secc_dist_mean_r_subd_m_iso` | 27 |
| `city_seg_district_rural_urban_4` | 7 | `secc_district_mean_urban_town_sc_dissimilarity` | `secc_dist_mean_u_town_sc_dissim` | 31 |
| `city_seg_district_rural_urban_4` | 8 | `secc_district_mean_urban_town_muslim_dissimilarity` | `secc_dist_mean_u_town_m_dissim` | 30 |
| `city_seg_district_rural_urban_4` | 9 | `secc_district_mean_urban_town_sc_isolation` | `secc_dist_mean_u_town_sc_iso` | 28 |
| `city_seg_district_rural_urban_4` | 10 | `secc_district_mean_urban_town_muslim_isolation` | `secc_dist_mean_u_town_m_iso` | 27 |
| `dissim_iso_block_groups.dta` | 2 | `seg_block_group_min_population_threshold` | `seg_block_grp_min_pop_thr` | 25 |
| `dissim_iso_block_groups.dta` | 3 | `seg_block_group_mean_population_estimate` | `seg_block_grp_mean_pop_est` | 26 |
| `dissim_iso_block_groups.dta` | 5 | `secc_sc_weighted_mean_urban_town_dissimilarity` | `secc_sc_wtd_mean_u_town_dissim` | 30 |
| `dissim_iso_block_groups.dta` | 6 | `secc_muslim_weighted_mean_urban_town_dissimilarity` | `secc_m_wtd_mean_u_town_dissim` | 29 |
| `dissim_iso_block_groups.dta` | 7 | `secc_sc_weighted_mean_urban_town_isolation` | `secc_sc_wtd_mean_u_town_iso` | 27 |
| `dissim_iso_block_groups.dta` | 8 | `secc_muslim_weighted_mean_urban_town_isolation` | `secc_m_wtd_mean_u_town_iso` | 26 |
| `msa_tract_race_pop.dta` | 15 | `us_census_tract_nonblack_population` | `us_cen_tr_nonblk_pop` | 20 |
| `msa_tract_race_pop.dta` | 20 | `us_census_msa_black_dissimilarity` | `us_cen_msa_blk_dissim` | 21 |
| `pc11-district.prj` | 2 | `pc11_district_prj_projection_file` | `pc11_dist_prj_proj_file` | 23 |
| `pc11-district.shx` | 2 | `pc11_district_shx_shape_index_file` | `pc11_dist_shx_shp_idx_file` | 26 |
| `pc11-subdistrict.prj` | 2 | `pc11_subdistrict_prj_projection_file` | `pc11_subd_prj_proj_file` | 23 |
| `pc11-subdistrict.shx` | 2 | `pc11_subdistrict_shx_shape_index_file` | `pc11_subd_shx_shp_idx_file` | 26 |
| `pc11_pdf_shrid_key.dta` | 18 | `pc11_pdf_pca_total_population_difference` | `pc11_pdf_pca_tot_pop_diff` | 25 |
| `seg_comparisons_d.csv` | 2 | `seg_comparisons_d_csv_missing_file` | `seg_comp_d_csv_miss_file` | 24 |
| `seg_comparisons_i_raw.csv` | 2 | `seg_comparisons_i_raw_csv_missing_file` | `seg_comp_i_raw_csv_miss_file` | 28 |
| `seg_correlates.dta` | 5 | `secc_city_sc_consumption_per_capita` | `secc_city_sc_cons_per_cap` | 25 |
| `seg_correlates.dta` | 6 | `secc_city_muslim_consumption_per_capita` | `secc_city_m_cons_per_cap` | 24 |
| `seg_correlates.dta` | 9 | `secc_city_sc_mean_education_years` | `secc_city_sc_mean_educ_years` | 28 |
| `seg_correlates.dta` | 10 | `secc_city_muslim_mean_education_years` | `secc_city_m_mean_educ_years` | 27 |
| `seg_correlates.dta` | 12 | `secc_city_slum_share_or_indicator` | `secc_city_slum_shr_or_ind` | 25 |
| `seg_correlates.dta` | 15 | `secc_log_city_consumption_per_capita` | `secc_log_city_cons_per_cap` | 26 |
| `seg_correlates.dta` | 16 | `secc_log_city_sc_consumption_per_capita` | `secc_log_city_sc_cons_per_cap` | 29 |
| `seg_correlates.dta` | 17 | `secc_log_city_muslim_consumption_per_capita` | `secc_log_city_m_cons_per_cap` | 28 |
| `seg_correlates.dta` | 18 | `secc_log_city_non_sc_non_muslim_consumption_per_capita` | `secc_log_city_non_sc_non_m_cons` | 31 |
| `seg_correlates.dta` | 31 | `secc_city_muslim_population_share` | `secc_city_m_pop_shr` | 19 |
| `seg_correlates.dta` | 53 | `violence_non_religious_event_count` | `viol_non_rel_event_cnt` | 22 |
| `seg_correlates.dta` | 64 | `pc91_pc11_log_population_growth_rate` | `pc91_pc11_log_pop_grw_rate` | 26 |
| `segregation_blockdata_rural_200` | 12 | `secc_block_muslim_population_count` | `secc_block_m_pop_cnt` | 20 |
| `segregation_blockdata_rural_200` | 15 | `secc_block_non_sc_non_muslim_population_count` | `secc_block_non_sc_non_m_pop_cnt` | 31 |
| `segregation_blockdata_rural_200` | 16 | `secc_missing_sc_classification_population` | `secc_miss_sc_class_pop` | 22 |
| `segregation_blockdata_rural_200` | 17 | `secc_missing_muslim_classification_population` | `secc_miss_m_class_pop` | 21 |
| `segregation_blockdata_rural_200` | 18 | `secc_missing_education_population` | `secc_miss_educ_pop` | 18 |
| `segregation_blockdata_rural_200` | 25 | `secc_block_non_sc_non_muslim_population` | `secc_block_non_sc_non_m_pop` | 27 |
| `segregation_blockdata_rural_200` | 31 | `secc_block_sc_consumption_per_capita` | `secc_block_sc_cons_per_cap` | 26 |
| `segregation_blockdata_rural_200` | 33 | `secc_block_muslim_consumption_per_capita` | `secc_block_m_cons_per_cap` | 25 |
| `segregation_blockdata_rural_200` | 35 | `secc_block_non_sc_non_muslim_consumption_per_capita` | `secc_block_non_sc_non_m_cons_per` | 32 |
| `segregation_blockdata_rural_200` | 39 | `secc_block_muslim_population_share` | `secc_block_m_pop_shr` | 20 |
| `segregation_blockdata_rural_200` | 44 | `ec13_block_secondary_school_count` | `ec13_block_sec_sch_cnt` | 22 |
| `segregation_blockdata_rural_200` | 67 | `ec13_log_public_primary_school_employment` | `ec13_log_pub_prim_sch_emp` | 25 |
| `segregation_blockdata_rural_200` | 70 | `ec13_log_public_secondary_school_employment` | `ec13_log_pub_sec_sch_emp` | 24 |
| `segregation_blockdata_rural_200` | 76 | `ec13_log_public_hospital_employment` | `ec13_log_pub_hosp_emp` | 21 |
| `segregation_blockdata_rural_200` | 81 | `ec13_has_private_secondary_school` | `ec13_has_priv_sec_sch` | 21 |
| `segregation_blockdata_rural_200` | 91 | `ec13_log_private_primary_school_employment` | `ec13_log_priv_prim_sch_emp` | 26 |
| `segregation_blockdata_rural_200` | 94 | `ec13_log_private_secondary_school_employment` | `ec13_log_priv_sec_sch_emp` | 25 |
| `segregation_blockdata_rural_200` | 100 | `ec13_log_private_hospital_employment` | `ec13_log_priv_hosp_emp` | 22 |
| `segregation_blockdata_rural_400` | 12 | `secc_block_muslim_population_count` | `secc_block_m_pop_cnt` | 20 |
| `segregation_blockdata_rural_400` | 16 | `secc_missing_sc_classification_population` | `secc_miss_sc_class_pop` | 22 |
| `segregation_blockdata_rural_400` | 17 | `secc_missing_muslim_classification_population` | `secc_miss_m_class_pop` | 21 |
| `segregation_blockdata_rural_400` | 18 | `secc_missing_education_population` | `secc_miss_educ_pop` | 18 |
| `segregation_blockdata_rural_400` | 39 | `secc_block_muslim_population_share` | `secc_block_m_pop_shr` | 20 |
| `segregation_blockdata_rural_400` | 44 | `ec13_block_secondary_school_count` | `ec13_block_sec_sch_cnt` | 22 |
| `segregation_blockdata_rural_400` | 67 | `ec13_log_public_primary_school_employment` | `ec13_log_pub_prim_sch_emp` | 25 |
| `segregation_blockdata_rural_400` | 70 | `ec13_log_public_secondary_school_employment` | `ec13_log_pub_sec_sch_emp` | 24 |
| `segregation_blockdata_rural_400` | 76 | `ec13_log_public_hospital_employment` | `ec13_log_pub_hosp_emp` | 21 |
| `segregation_blockdata_rural_400` | 81 | `ec13_has_private_secondary_school` | `ec13_has_priv_sec_sch` | 21 |
| `segregation_blockdata_rural_400` | 91 | `ec13_log_private_primary_school_employment` | `ec13_log_priv_prim_sch_emp` | 26 |
| `segregation_blockdata_rural_400` | 94 | `ec13_log_private_secondary_school_employment` | `ec13_log_priv_sec_sch_emp` | 25 |
| `segregation_blockdata_rural_400` | 100 | `ec13_log_private_hospital_employment` | `ec13_log_priv_hosp_emp` | 22 |
| `segregation_blockdata_urban_200` | 12 | `secc_block_muslim_population_count` | `secc_block_m_pop_cnt` | 20 |
| `segregation_blockdata_urban_200` | 15 | `secc_block_non_sc_non_muslim_population_count` | `secc_block_non_sc_non_m_pop_cnt` | 31 |
| `segregation_blockdata_urban_200` | 16 | `secc_missing_sc_classification_population` | `secc_miss_sc_class_pop` | 22 |
| `segregation_blockdata_urban_200` | 17 | `secc_missing_muslim_classification_population` | `secc_miss_m_class_pop` | 21 |
| `segregation_blockdata_urban_200` | 18 | `secc_missing_education_population` | `secc_miss_educ_pop` | 18 |
| `segregation_blockdata_urban_200` | 25 | `secc_block_non_sc_non_muslim_population` | `secc_block_non_sc_non_m_pop` | 27 |
| `segregation_blockdata_urban_200` | 34 | `secc_block_water_source_at_home_share` | `secc_block_wtr_src_at_home_shr` | 30 |
| `segregation_blockdata_urban_200` | 46 | `secc_block_electric_lighting_share` | `secc_block_elec_light_shr` | 25 |
| `segregation_blockdata_urban_200` | 52 | `secc_block_slum_share_or_indicator` | `secc_block_slum_shr_or_ind` | 26 |
| `segregation_blockdata_urban_200` | 54 | `secc_block_consumption_per_capita` | `secc_block_cons_per_cap` | 23 |
| `segregation_blockdata_urban_200` | 55 | `secc_log_block_consumption_per_capita` | `secc_log_block_cons_per_cap` | 27 |
| `segregation_blockdata_urban_200` | 56 | `secc_block_sc_consumption_per_capita` | `secc_block_sc_cons_per_cap` | 26 |
| `segregation_blockdata_urban_200` | 58 | `secc_block_muslim_consumption_per_capita` | `secc_block_m_cons_per_cap` | 25 |
| `segregation_blockdata_urban_200` | 60 | `secc_block_non_sc_non_muslim_consumption_per_capita` | `secc_block_non_sc_non_m_cons_per` | 32 |
| `segregation_blockdata_urban_200` | 64 | `secc_block_muslim_population_share` | `secc_block_m_pop_shr` | 20 |
| `segregation_blockdata_urban_200` | 69 | `ec13_block_secondary_school_count` | `ec13_block_sec_sch_cnt` | 22 |
| `segregation_blockdata_urban_200` | 92 | `ec13_log_public_primary_school_employment` | `ec13_log_pub_prim_sch_emp` | 25 |
| `segregation_blockdata_urban_200` | 95 | `ec13_log_public_secondary_school_employment` | `ec13_log_pub_sec_sch_emp` | 24 |
| `segregation_blockdata_urban_200` | 101 | `ec13_log_public_hospital_employment` | `ec13_log_pub_hosp_emp` | 21 |
| `segregation_blockdata_urban_200` | 106 | `ec13_has_private_secondary_school` | `ec13_has_priv_sec_sch` | 21 |
| `segregation_blockdata_urban_200` | 116 | `ec13_log_private_primary_school_employment` | `ec13_log_priv_prim_sch_emp` | 26 |
| `segregation_blockdata_urban_200` | 119 | `ec13_log_private_secondary_school_employment` | `ec13_log_priv_sec_sch_emp` | 25 |
| `segregation_blockdata_urban_200` | 125 | `ec13_log_private_hospital_employment` | `ec13_log_priv_hosp_emp` | 22 |
| `segregation_blockdata_urban_400` | 12 | `secc_block_muslim_population_count` | `secc_block_m_pop_cnt` | 20 |
| `segregation_blockdata_urban_400` | 16 | `secc_missing_sc_classification_population` | `secc_miss_sc_class_pop` | 22 |
| `segregation_blockdata_urban_400` | 17 | `secc_missing_muslim_classification_population` | `secc_miss_m_class_pop` | 21 |
| `segregation_blockdata_urban_400` | 18 | `secc_missing_education_population` | `secc_miss_educ_pop` | 18 |
| `segregation_blockdata_urban_400` | 34 | `secc_block_water_source_at_home_share` | `secc_block_wtr_src_at_home_shr` | 30 |
| `segregation_blockdata_urban_400` | 46 | `secc_block_electric_lighting_share` | `secc_block_elec_light_shr` | 25 |
| `segregation_blockdata_urban_400` | 64 | `secc_block_muslim_population_share` | `secc_block_m_pop_shr` | 20 |
| `segregation_blockdata_urban_400` | 69 | `ec13_block_secondary_school_count` | `ec13_block_sec_sch_cnt` | 22 |
| `segregation_blockdata_urban_400` | 92 | `ec13_log_public_primary_school_employment` | `ec13_log_pub_prim_sch_emp` | 25 |
| `segregation_blockdata_urban_400` | 95 | `ec13_log_public_secondary_school_employment` | `ec13_log_pub_sec_sch_emp` | 24 |
| `segregation_blockdata_urban_400` | 101 | `ec13_log_public_hospital_employment` | `ec13_log_pub_hosp_emp` | 21 |
| `segregation_blockdata_urban_400` | 106 | `ec13_has_private_secondary_school` | `ec13_has_priv_sec_sch` | 21 |
| `segregation_blockdata_urban_400` | 116 | `ec13_log_private_primary_school_employment` | `ec13_log_priv_prim_sch_emp` | 26 |
| `segregation_blockdata_urban_400` | 119 | `ec13_log_private_secondary_school_employment` | `ec13_log_priv_sec_sch_emp` | 25 |
| `segregation_blockdata_urban_400` | 125 | `ec13_log_private_hospital_employment` | `ec13_log_priv_hosp_emp` | 22 |
| `segregation_citydata_rural_200.` | 4 | `secc_subdistrict_sc_dissimilarity` | `secc_subd_sc_dissim` | 19 |
| `segregation_citydata_rural_200.` | 11 | `secc_subdistrict_muslim_dissimilarity` | `secc_subd_m_dissim` | 18 |
| `segregation_citydata_rural_200.` | 14 | `secc_subdistrict_muslim_isolation` | `secc_subd_m_iso` | 15 |
| `segregation_citydata_rural_200.` | 26 | `secc_missing_sc_classification_population` | `secc_miss_sc_class_pop` | 22 |
| `segregation_citydata_rural_200.` | 27 | `secc_missing_muslim_classification_population` | `secc_miss_m_class_pop` | 21 |
| `segregation_citydata_rural_200.` | 35 | `secc_missing_education_population` | `secc_miss_educ_pop` | 18 |
| `segregation_citydata_rural_200.` | 47 | `secc_city_muslim_population_share` | `secc_city_m_pop_shr` | 19 |
| `segregation_citydata_rural_200.` | 116 | `pc11_vd_subdistrict_allopathic_hospital_count` | `pc11_vd_subd_allop_hosp_cnt` | 27 |
| `segregation_citydata_rural_200.` | 119 | `pc11_vd_subdistrict_primary_school_count` | `pc11_vd_subd_prim_sch_cnt` | 25 |
| `segregation_citydata_rural_200.` | 120 | `pc11_vd_subdistrict_middle_school_count` | `pc11_vd_subd_mid_sch_cnt` | 24 |
| `segregation_citydata_rural_200.` | 121 | `pc11_vd_subdistrict_secondary_school_count` | `pc11_vd_subd_sec_sch_cnt` | 24 |
| `segregation_citydata_rural_200.` | 132 | `pc11_log_vd_subdistrict_population` | `pc11_log_vd_subd_pop` | 20 |
| `segregation_citydata_urban_200.` | 21 | `secc_city_muslim_population_count` | `secc_city_m_pop_cnt` | 19 |
| `segregation_citydata_urban_200.` | 25 | `secc_missing_sc_classification_population` | `secc_miss_sc_class_pop` | 22 |
| `segregation_citydata_urban_200.` | 26 | `secc_missing_muslim_classification_population` | `secc_miss_m_class_pop` | 21 |
| `segregation_citydata_urban_200.` | 34 | `secc_missing_education_population` | `secc_miss_educ_pop` | 18 |
| `segregation_citydata_urban_200.` | 41 | `secc_city_water_source_at_home_share` | `secc_city_wtr_src_at_home_shr` | 29 |
| `segregation_citydata_urban_200.` | 53 | `secc_city_electric_lighting_share` | `secc_city_elec_light_shr` | 24 |
| `segregation_citydata_urban_200.` | 71 | `secc_city_muslim_population_share` | `secc_city_m_pop_shr` | 19 |
| `segregation_citydata_urban_200.` | 139 | `pc11_td_allopathic_hospital_count` | `pc11_td_allop_hosp_cnt` | 22 |
| `segregation_citydata_urban_4000` | 21 | `secc_city_muslim_population_count` | `secc_city_m_pop_cnt` | 19 |
| `segregation_citydata_urban_4000` | 25 | `secc_missing_sc_classification_population` | `secc_miss_sc_class_pop` | 22 |
| `segregation_citydata_urban_4000` | 26 | `secc_missing_muslim_classification_population` | `secc_miss_m_class_pop` | 21 |
| `segregation_citydata_urban_4000` | 34 | `secc_missing_education_population` | `secc_miss_educ_pop` | 18 |
| `segregation_citydata_urban_4000` | 71 | `secc_city_muslim_population_share` | `secc_city_m_pop_shr` | 19 |
| `shrug_pc11_td.dta` | 100 | `pc11_td_allopathic_hospital_count` | `pc11_td_allop_hosp_cnt` | 22 |
| `shrug_pc11_vd.dta` | 77 | `pc11_vd_village_allopathic_hospital_count` | `pc11_vd_vill_allop_hosp_cnt` | 27 |
| `shrug_pc11_vd.dta` | 385 | `pc11_vd_village_primary_school_count` | `pc11_vd_vill_prim_sch_cnt` | 25 |
| `shrug_pc11_vd.dta` | 386 | `pc11_vd_village_middle_school_count` | `pc11_vd_vill_mid_sch_cnt` | 24 |
| `shrug_pc11_vd.dta` | 387 | `pc11_vd_village_secondary_school_count` | `pc11_vd_vill_sec_sch_cnt` | 24 |
| `us_census_msa_dissim.dta` | 9 | `us_census_msa_black_dissimilarity` | `us_cen_msa_blk_dissim` | 21 |
| `us_tpop_b.dta` | 2 | `us_census_tract_black_share_bin_midpoint` | `us_cen_tr_blk_shr_bin_midpt` | 27 |
| `us_tpop_b.dta` | 3 | `us_census_black_only_population_share_in_tract_bin` | `us_cen_blk_only_pop_shr_in_tr_bi` | 32 |
| `us_tract_pop.dta` | 5 | `us_census_tract_black_only_population` | `us_cen_tr_blk_only_pop` | 22 |
| `us_tract_pop.dta` | 7 | `us_census_tract_nonblack_population` | `us_cen_tr_nonblk_pop` | 20 |
| `us_tract_pop.dta` | 8 | `us_census_tract_black_white_population` | `us_cen_tr_blk_wht_pop` | 21 |
| `us_tract_pop.dta` | 12 | `us_census_black_only_population_share_in_tract_bin` | `us_cen_blk_only_pop_shr_in_tr_bi` | 32 |
