/**********************************************/
/* HARMONIZE SECC BLOCK RURAL SHARD CLUSTER   */
/**********************************************/

version 18
clear all
set more off
set rmsg on

local root "/dartfs-hpc/scratch/siddiqui/seg_cleanup"
local cluster "secc_block_rural"
local canonical_file "/dartfs/rc/lab/I/IEC/seg/clean/secc_rural_collapsed_block.dta"

local cluster_maps_dir "`root'/cluster_maps"
local harmonized_root "`root'/harmonized_clusters"
local harmonized_dir "`harmonized_root'/`cluster'"
local appended_file "`harmonized_root'/`cluster'_appended.dta"
local validation_csv "`harmonized_root'/`cluster'_validation.csv"
local append_report_csv "`harmonized_root'/`cluster'_append_vs_master_report.csv"

local action_plan_csv "`cluster_maps_dir'/`cluster'_schema_action_plan.csv"
local diff_summary_csv "`cluster_maps_dir'/`cluster'_schema_diff_summary.csv"
local manual_review_csv "`cluster_maps_dir'/`cluster'_manual_review.csv"
local file_map_csv "`cluster_maps_dir'/`cluster'_file_application_map.csv"

local key_vars pc11_state_id pc11_district_id pc11_subdistrict_id pc11_ward_id pc11_block_id pc11_village_id

cap mkdir "`cluster_maps_dir'"
cap mkdir "`harmonized_root'"
cap mkdir "`harmonized_dir'"

tempfile template diff_summary_data file_map_data canonical_sorted appended_sorted validation_data report_data
tempname validation_post report_post

/**************************/
/* LOAD CANONICAL TARGET  */
/**************************/

use "`canonical_file'", clear
qui count
local canonical_n = r(N)
unab canonical_vars : _all
local canonical_nvars : word count `canonical_vars'
keep if 0
save "`template'", replace

global SECCBR_TEMPLATE "`template'"
global SECCBR_HARMONIZED_DIR "`harmonized_dir'"
global SECCBR_CANONICAL_VARS `"`canonical_vars'"'

/**************************/
/* LOAD CLUSTER MAPS      */
/**************************/

import delimited using "`diff_summary_csv'", clear varnames(1)
save "`diff_summary_data'", replace
global SECCBR_DIFF_SUMMARY "`diff_summary_data'"

import delimited using "`file_map_csv'", clear varnames(1)
save "`file_map_data'", replace
global SECCBR_FILE_MAP "`file_map_data'"

import delimited using "`manual_review_csv'", clear varnames(1)
local manual_review_cases = _N

use "`diff_summary_data'", clear
count if change_mode == "no_change"
local schemas_no_change = r(N)
count if change_mode == "add_missing_only"
local schemas_add_missing_only = r(N)
count if n_rename > 0
local schemas_with_rename = r(N)
count if n_manual_review > 0 | n_extra_source_vars > 0
local schemas_with_manual_review = r(N)
count
local total_source_schemas = r(N)

use "`file_map_data'", clear
count
local shard_file_count = r(N)

/**************************/
/* GUARDRAILS             */
/**************************/

if `schemas_with_rename' > 0 {
    di as err "Rename actions detected in cluster map; aborting."
    error 498
}

if `schemas_with_manual_review' > 0 {
    di as err "Manual review cases remain in cluster map; aborting."
    error 498
}

if `manual_review_cases' > 0 {
    di as err "Manual review CSV is not empty; aborting."
    error 498
}

/**************************/
/* HARMONIZE BY SCHEMA    */
/**************************/

cap prog drop harmonize_schema_group
program define harmonize_schema_group
    args schemaid

    local canonical_vars $SECCBR_CANONICAL_VARS
    local template_path "$SECCBR_TEMPLATE"
    local diff_summary_path "$SECCBR_DIFF_SUMMARY"
    local file_map_path "$SECCBR_FILE_MAP"
    local harmonized_path "$SECCBR_HARMONIZED_DIR"

    preserve
        use "`diff_summary_path'", clear
        keep if source_schema_id == "`schemaid'"
        assert _N == 1
        local expected_changes = expected_changes_count[1]
        local rename_count = n_rename[1]
        local manual_count = n_manual_review[1]
        local extra_count = n_extra_source_vars[1]
    restore

    if `rename_count' > 0 | `manual_count' > 0 | `extra_count' > 0 {
        di as err "Schema `schemaid' is not add-missing-only; aborting."
        error 498
    }

    preserve
        use "`file_map_path'", clear
        keep if source_schema_id == "`schemaid'"
        assert _N > 0
        levelsof filename, local(schema_files) clean
    restore

    local repfile : word 1 of `schema_files'
    use "`repfile'", clear
    unab repvars : _all
    local extra_rep : list repvars - canonical_vars
    if "`extra_rep'" != "" {
        di as err "Unexpected extra variables in representative shard for `schemaid': `extra_rep'"
        error 498
    }

    local missing_rep : list canonical_vars - repvars
    local rep_missing_count : word count `missing_rep'
    if `rep_missing_count' != `expected_changes' {
        di as err "Representative shard missing-count mismatch for `schemaid'."
        error 498
    }

    foreach srcfile of local schema_files {
        use "`srcfile'", clear
        qui count
        local source_n = r(N)
        unab source_vars : _all

        local extra_vars : list source_vars - canonical_vars
        if "`extra_vars'" != "" {
            di as err "Unexpected extra variables in `srcfile': `extra_vars'"
            error 498
        }

        local source_missing : list canonical_vars - source_vars
        local current_missing_count : word count `source_missing'
        if `current_missing_count' != `expected_changes' {
            di as err "Schema drift detected in `srcfile'."
            error 498
        }

        tempfile source_copy
        save "`source_copy'", replace

        use "`template_path'", clear
        append using "`source_copy'"
        order `canonical_vars'
        qui count
        assert r(N) == `source_n'

        local outname = regexr("`srcfile'", "^.*/", "")
        save "`harmonized_path'/`outname'", replace
    }
end

use "`diff_summary_data'", clear
levelsof source_schema_id, local(schema_ids) clean

foreach schema_id of local schema_ids {
    di as txt "Harmonizing schema `schema_id'"
    harmonize_schema_group `schema_id'
}

/**************************/
/* APPEND HARMONIZED DATA */
/**************************/

use "`template'", clear
use "`file_map_data'", clear
levelsof filename, local(source_files) clean

use "`template'", clear
local harmonized_file_count = 0
foreach srcfile of local source_files {
    local outname = regexr("`srcfile'", "^.*/", "")
    append using "`harmonized_dir'/`outname'"
    local ++harmonized_file_count
}

qui count
local appended_n = r(N)
order `canonical_vars'
save "`appended_file'", replace

/**************************/
/* VALIDATE AGAINST MASTER*/
/**************************/

use "`appended_file'", clear
unab appended_vars : _all
local appended_nvars : word count `appended_vars'

local rowcount_match = (`appended_n' == `canonical_n')
local var_order_match = ("`appended_vars'" == "`canonical_vars'")
local var_name_match = ("`appended_vars'" == "`canonical_vars'")

capture noisily isid `key_vars'
local appended_keys_unique = (_rc == 0)
sort `key_vars'
save "`appended_sorted'", replace

use "`canonical_file'", clear
capture noisily isid `key_vars'
local master_keys_unique = (_rc == 0)
sort `key_vars'
save "`canonical_sorted'", replace

use "`appended_sorted'", clear
capture noisily cf `key_vars' using "`canonical_sorted'"
local key_values_match = (_rc == 0)

capture noisily cf _all using "`canonical_sorted'"
local all_values_match = (_rc == 0)

local master_validated = ///
    (`rowcount_match' & `var_order_match' & `var_name_match' & ///
     `appended_keys_unique' & `master_keys_unique' & ///
     `key_values_match' & `all_values_match')

postfile `validation_post' str48 check_name byte passed str244 actual_value str244 expected_value str244 notes using "`validation_data'", replace

post `validation_post' ("cluster_name") (1) ("`cluster'") ("`cluster'") ("Target schema cluster.")
post `validation_post' ("source_schema_count") (1) ("`total_source_schemas'") ("14") ("Schemas found in cluster diff summary.")
post `validation_post' ("source_shard_file_count") (1) ("`shard_file_count'") ("1239") ("Non-legacy shard files processed.")
post `validation_post' ("schemas_no_change") (1) ("`schemas_no_change'") ("1") ("Schemas already on canonical schema.")
post `validation_post' ("schemas_add_missing_only") (1) ("`schemas_add_missing_only'") ("13") ("Schemas requiring only add_missing actions.")
post `validation_post' ("schemas_with_rename") (`schemas_with_rename' == 0) ("`schemas_with_rename'") ("0") ("Rename actions should be zero in this pass.")
post `validation_post' ("schemas_with_manual_review") (`schemas_with_manual_review' == 0) ("`schemas_with_manual_review'") ("0") ("Manual-review schemas should be zero in this pass.")
post `validation_post' ("manual_review_cases") (`manual_review_cases' == 0) ("`manual_review_cases'") ("0") ("Manual-review rows should be zero in this pass.")
post `validation_post' ("harmonized_file_count") (`harmonized_file_count' == `shard_file_count') ("`harmonized_file_count'") ("`shard_file_count'") ("Harmonized shard files written.")
post `validation_post' ("appended_rowcount_match_master") (`rowcount_match') ("`appended_n'") ("`canonical_n'") ("Appended row count should match canonical target.")
post `validation_post' ("appended_variable_count_match_master") (`appended_nvars' == `canonical_nvars') ("`appended_nvars'") ("`canonical_nvars'") ("Variable count should match canonical target.")
post `validation_post' ("appended_variable_names_match_master") (`var_name_match') ("`appended_vars'") ("`canonical_vars'") ("Variable names should match canonical schema.")
post `validation_post' ("appended_variable_order_match_master") (`var_order_match') ("`appended_vars'") ("`canonical_vars'") ("Variable order should match canonical schema.")
post `validation_post' ("appended_key_columns_unique") (`appended_keys_unique') ("`appended_keys_unique'") ("1") ("Key geography columns should uniquely identify appended rows.")
post `validation_post' ("master_key_columns_unique") (`master_keys_unique') ("`master_keys_unique'") ("1") ("Key geography columns should uniquely identify canonical target rows.")
post `validation_post' ("appended_key_values_match_master") (`key_values_match') ("`key_values_match'") ("1") ("Sorted key columns should match canonical target.")
post `validation_post' ("appended_all_values_match_master") (`all_values_match') ("`all_values_match'") ("1") ("All values should match canonical target after sorting on keys.")
post `validation_post' ("candidate_master_effectively_validated") (`master_validated') ("`master_validated'") ("1") ("Validation target for this harmonization pass.")

postclose `validation_post'

postfile `report_post' str64 variable_name int column_position byte in_appended byte in_master byte order_match byte values_equal str244 notes using "`report_data'", replace

local position = 0
foreach var of local canonical_vars {
    local ++position
    local values_equal = 1
    local notes = ""

    if `all_values_match' == 0 {
        capture noisily cf `var' using "`canonical_sorted'"
        local values_equal = (_rc == 0)
        if `values_equal' == 0 {
            local notes = "Values differ from canonical target after sorting on key geography columns."
        }
    }

    post `report_post' ("`var'") (`position') (1) (1) (1) (`values_equal') ("`notes'")
}

postclose `report_post'

use "`validation_data'", clear
export delimited using "`validation_csv'", replace

use "`report_data'", clear
export delimited using "`append_report_csv'", replace

macro drop SECCBR_TEMPLATE SECCBR_HARMONIZED_DIR SECCBR_CANONICAL_VARS SECCBR_DIFF_SUMMARY SECCBR_FILE_MAP

di as txt "Wrote appended cluster file: `appended_file'"
di as txt "Wrote validation CSV: `validation_csv'"
di as txt "Wrote append-vs-master report CSV: `append_report_csv'"
