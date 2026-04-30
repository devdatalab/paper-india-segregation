# Standalone Dataset Inventory Review

## Definition Used
A final standalone dataset is a complete dataset that captures a distinct conceptual object and is not a raw input, support key, partition, threshold variant, subsample, deterministic derivative, intermediate output, or duplicate archive copy.

Complete external comparison/source datasets are retained as `standalone_source` only when code evidence does not show them being collapsed into a cleaner final dataset. Complete archive datasets are retained as `legacy_standalone` only when they are distinct family representatives.

## Final Counts
- Final standalone datasets: 39
- Class counts: {'canonical_standalone': 24, 'standalone_source': 12, 'legacy_standalone': 3}
- Manual review queue rows: 18
- Decision change rows: 40423

## Major Rows Removed From Old Standalone
- `/dartfs/rc/lab/I/IEC/seg/clean/secc_ec_blockdata_rural_pooled_200.dta` -> `derived_complete`: writer=ddl/paper-india-segregation/b/create_secc_block_groups.do:54; parent=/dartfs/rc/lab/I/IEC/seg/clean/secc_ec_blockdata_rural.dta; duplicate basename present
- `/dartfs/rc/lab/I/IEC/seg/clean/secc_ec_blockdata_rural_pooled_4000.dta` -> `derived_complete`: writer=ddl/paper-india-segregation/b/create_secc_block_groups.do:54; parent=/dartfs/rc/lab/I/IEC/seg/clean/secc_ec_blockdata_rural.dta; duplicate basename present
- `/dartfs/rc/lab/I/IEC/seg/clean/secc_ec_blockdata_urban_pooled_200.dta` -> `derived_complete`: writer=ddl/paper-india-segregation/b/create_secc_block_groups.do:54; parent=/dartfs/rc/lab/I/IEC/seg/clean/secc_ec_blockdata_urban.dta; duplicate basename present
- `/dartfs/rc/lab/I/IEC/seg/clean/secc_ec_blockdata_urban_pooled_4000.dta` -> `derived_complete`: writer=ddl/paper-india-segregation/b/create_secc_block_groups.do:54; parent=/dartfs/rc/lab/I/IEC/seg/clean/secc_ec_blockdata_urban.dta; duplicate basename present
- `/dartfs/rc/lab/I/IEC/seg/clean/segregation_blockdata_rural_200.dta` -> `derived_complete`: writer=ddl/paper-india-segregation/b/gen_seg_variables.do:149; parent=/dartfs/rc/lab/I/IEC/seg/clean/secc_ec_blockdata_rural_pooled_200.dta
- `/dartfs/rc/lab/I/IEC/seg/clean/segregation_blockdata_rural_4000.dta` -> `derived_complete`: writer=ddl/paper-india-segregation/b/gen_seg_variables.do:149; parent=/dartfs/rc/lab/I/IEC/seg/clean/secc_ec_blockdata_rural_pooled_4000.dta
- `/dartfs/rc/lab/I/IEC/seg/clean/segregation_blockdata_urban_200.dta` -> `derived_complete`: writer=ddl/paper-india-segregation/b/gen_seg_variables.do:149; parent=/dartfs/rc/lab/I/IEC/seg/clean/secc_ec_blockdata_urban_pooled_200.dta
- `/dartfs/rc/lab/I/IEC/seg/clean/segregation_blockdata_urban_4000.dta` -> `derived_complete`: writer=ddl/paper-india-segregation/b/gen_seg_variables.do:149; parent=/dartfs/rc/lab/I/IEC/seg/clean/secc_ec_blockdata_urban_pooled_4000.dta
- `/dartfs/rc/lab/I/IEC/seg/clean/segregation_citydata_urban_200.dta` -> `derived_complete`: writer=ddl/paper-india-segregation/b/gen_segregation_city_block_data.do:163; parent=/dartfs/rc/lab/I/IEC/seg/clean/segregation_blockdata_urban_200.dta
- `/dartfs/rc/lab/I/IEC/seg/clean/segregation_citydata_urban_4000.dta` -> `derived_complete`: writer=ddl/paper-india-segregation/b/gen_segregation_city_block_data.do:163; parent=/dartfs/rc/lab/I/IEC/seg/clean/segregation_blockdata_urban_4000.dta
- `/dartfs/rc/lab/I/IEC/seg/clean/segregation_pc0111.dta` -> `derived_complete`: writer=paper-india-segregation/a/gen_dissim_pc0111.do:12; read by 6 script(s); feeds 12 downstream file(s); parent=/dartfs/rc/lab/I/IEC/seg/clean/segregation_citydata_urban_200.dta
- `/dartfs/rc/lab/I/IEC/seg/clean/ec/old/ec05_kerala_ed_health.dta` -> `derived_complete`: parent=/dartfs/rc/lab/I/IEC/seg/clean/ec/ec05_ed_health.dta
- `/dartfs/rc/lab/I/IEC/seg/clean/ec/old/ec13_kerala_ed_health.dta` -> `derived_complete`: parent=/dartfs/rc/lab/I/IEC/seg/clean/ec/ec13_ed_health.dta
- `/dartfs/rc/lab/I/IEC/seg/clean/ec/old/ec90_kerala_ed_health.dta` -> `derived_complete`: parent=/dartfs/rc/lab/I/IEC/seg/clean/ec/ec90_ed_health.dta
- `/dartfs/rc/lab/I/IEC/seg/clean/ec/old/ec98_kerala_ed_health.dta` -> `derived_complete`: parent=/dartfs/rc/lab/I/IEC/seg/clean/ec/ec98_ed_health.dta
- `/dartfs/rc/lab/I/IEC/seg/clean/us/us_tract_pop.dta` -> `derived_complete`: writer=paper-india-segregation/b/gen_us_seg_variables.do:8; read by 6 script(s); feeds 38 downstream file(s); parent=/dartfs/rc/lab/I/IEC/seg/clean/us/us_census_msa_dissim.dta
- `/dartfs/rc/lab/I/IEC/seg/old-2020/pg_discrimination_counts_rural_200.dta` -> `derived_complete`: classification based on workbook metadata
- `/dartfs/rc/lab/I/IEC/seg/old-2020/pg_discrimination_counts_urban_200.dta` -> `derived_complete`: classification based on workbook metadata
- `/dartfs/rc/lab/I/IEC/seg/old-2020/pg_discrimination_rural_200.dta` -> `derived_complete`: classification based on workbook metadata
- `/dartfs/rc/lab/I/IEC/seg/clean/handbooks/append_hb_test.csv` -> `excluded_bad_artifact`: classification based on workbook metadata

## Ambiguous Rows Needing Review
- `/dartfs/rc/lab/I/IEC/seg/old-2020/raw/us/US_cityleveldata.dta` -> `excluded_bad_artifact`: Duplicate archive copy; canonical legacy representative is raw/us/old/US_cityleveldata.dta.
- `/dartfs/rc/lab/I/IEC/seg/clean/segregation_villagedata_rural.dta` -> `manual_review`: Previously marked derived, but no parent was found in inventory or code lineage.
- `/dartfs/rc/lab/I/IEC/seg/clean/segregation_villagedata_urban.dta` -> `manual_review`: Previously marked derived, but no parent was found in inventory or code lineage.
- `/dartfs/rc/lab/I/IEC/seg/data_audit/seg_data_audit_example.csv` -> `manual_review`: classification based on workbook metadata
- `/dartfs/rc/lab/I/IEC/seg/violence/AV_Data.xls` -> `manual_review`: parent=/dartfs/rc/lab/I/IEC/seg/violence/violence_seg_analysis.dta
- `/dartfs/rc/lab/I/IEC/seg/violence/AV_Data_matched.dta` -> `manual_review`: parent=/dartfs/rc/lab/I/IEC/seg/violence/violence_seg_analysis.dta
- `/dartfs/rc/lab/I/IEC/seg/violence/violence_matched_except_jk.dta` -> `manual_review`: writer=ddl/paper-india-segregation/b/prep_correlates.do:31; read by 4 script(s); feeds 52 downstream file(s); parent=/dartfs/rc/lab/I/IEC/seg/violence/violence_seg_analysis.dta
- `/dartfs/rc/lab/I/IEC/seg/violence/violence_matched_jk.dta` -> `manual_review`: writer=ddl/paper-india-segregation/b/prep_correlates.do:40; read by 4 script(s); feeds 50 downstream file(s); parent=/dartfs/rc/lab/I/IEC/seg/violence/violence_seg_analysis.dta
- `/dartfs/rc/lab/I/IEC/seg/raw/delhi_eb.geojson` -> `raw_input`: Raw file with no downstream output found by scanner.
- `/dartfs/rc/lab/I/IEC/seg/raw/us/brown/cc20d20.xlsx` -> `raw_input`: Raw file with no downstream output found by scanner.
- `/dartfs/rc/lab/I/IEC/seg/raw/us/brown/cc20p20.xlsx` -> `raw_input`: Raw file with no downstream output found by scanner.
- `/dartfs/rc/lab/I/IEC/seg/raw/us/brown/city20d20.xlsx` -> `raw_input`: Raw file with no downstream output found by scanner.
- `/dartfs/rc/lab/I/IEC/seg/raw/us/brown/city20p20.xlsx` -> `raw_input`: Raw file with no downstream output found by scanner.
- `/dartfs/rc/lab/I/IEC/seg/raw/us/brown/cityallp20.xlsx` -> `raw_input`: Raw file with no downstream output found by scanner.
- `/dartfs/rc/lab/I/IEC/seg/raw/us/brown/msa20d20.xlsx` -> `raw_input`: Raw file with no downstream output found by scanner.
- `/dartfs/rc/lab/I/IEC/seg/raw/us/brown/msa20p20.xlsx` -> `raw_input`: Raw file with no downstream output found by scanner.
- `/dartfs/rc/lab/I/IEC/seg/raw/us/brown/sb20d20.xlsx` -> `raw_input`: Raw file with no downstream output found by scanner.
- `/dartfs/rc/lab/I/IEC/seg/raw/us/brown/sb20p20.xlsx` -> `raw_input`: Raw file with no downstream output found by scanner.

## Immediate Row Decisions
- `pc11_pdf_shrid_dissim.dta` and `pc01_pdf_shrid_dissim.dta`: `derived_complete`, produced by `gen_dissim_pc0111.do` from handbook inputs.
- `msa-level-pop-2020.csv`: `raw_input`, used in the US census MSA build.
- `msa_keys.dta`: `support_or_key`, a clean MSA key used for merges.
- `us_tract_pop.dta`: `derived_complete`, an intermediate tract-population clean file feeding later US MSA outputs.
- `append_hb_test.csv`: `excluded_bad_artifact`, a test artifact.
- `raw/us/old/US_cityleveldata.dta`: `legacy_standalone`, retained as the old US city-level family representative.
- `clean/pc11/pc11_muslims_rural.dta` and `clean/pc11/pc11_muslims_urban.dta`: `canonical_standalone`, retained as primary PC11 Muslim-share masters.

## Code-Lineage Limitations
- Stata local macro interpolation such as `` `loc' `` is not fully expanded; those lines are supplemented by existing inventory creator metadata and AI-summary comments when present.
- The lineage graph is script-level and conservative: it links reads before writes within a script, so some complex do-files may contain broad upstream edges.
- Path aliases are resolved for the common segdata macros `$seg`, `$sdata`, `$tmp`, `$raw`, `$out`, and `$shrug`; unusual project-specific aliases remain unresolved and can enter the manual review queue.

## Validation
- Passed all requested validation checks.

Reviewed inventory rows classified: 40613.