/* install prerequisites */
ssc install binscatter, replace
ssc install _gwtmean, replace
ssc install rangestat, replace
ssc install ebalance, replace
ssc install labutil, replace
ssc install distinct, replace
ssc install gtools, replace
ssc install savesome, replace
ssc install reghdfe, replace
ssc install estout, replace
ssc install ftools, replace
ssc install require, replace

/**********************/
/* Initialize Paths   */
/**********************/

/* Set scode to the base repo path (where this file lives) */
global scode "~/ddl/segregation"

/* Set base to the replication data folder */
global base "~/Dropbox/tmp/segdata/"

/* Set python to your python executable. (Activate conda and run `which python` to find it) */
global python "/opt/homebrew/Caskroom/mambaforge/base/envs/segregation/bin/python"

/****************************/
/* Validate root globals    */
/****************************/
local scode_probe "$scode/set_paths.do"
if !fileexists("`scode_probe'") {
  di as error "Repo code not found in scode. Fix scode global."
  di as error "Expected file not found: `scode_probe'"
  exit 601
}

local base_probe "$base/raw/clean/secc_urban_collapsed.dta"
if !fileexists("`base_probe'") {
  di as error "Expected raw data file not found: `base_probe'"
  di as error "Ensure global base points to the data root containing raw/, tmp/, and out/."
  exit 601
}

local python_probe "$python"
if !fileexists("`python_probe'") {
  di as error "Expected python executable not found: `python_probe'"
  exit 601
}

do "$scode/set_paths.do"
do "$tools/stata-tex/stata-tex.do"
do "$tools/do/tools.do"

/*******************/
/* Save Start Time */
/*******************/
global start_time "$S_DATE $S_TIME"

/***************/
/* Set Globals */
/***************/

/* In replication make, this flag controls block-group thresholds in create_secc_block_groups.do */
global rebuild 1

/*****************************/
/* run the segregation build */
/*****************************/

/***********************************/
/* create main segregation dataset */
/***********************************/
/* 4. aggregate blocks to groups of 200 people and 4000 people */
/* combine SECC and EC block-level data for collapse to block groups */
do $scode/b/merge_secc_ec.do 
  
/* 5. create SECC block group key, and collapse SECC and EC data to group */
do $scode/b/create_secc_block_groups.do

/* 6. compute muslim PC shares at the subdistrict (rural) and town level */
do $scode/b/gen_pc_muslim_share.do
  
/* 7. create public goods and consumption analysis variables */
do $scode/b/gen_pg_cons_variables.do

/* 8. generate segregation variables */
do $scode/b/gen_seg_variables.do

/* 9.  save secc data at the block and city level*/
do $scode/b/gen_segregation_city_block_data.do

/* 10. add variable labels and save labeled datasets in $tmp/secc */
do $scode/b/add_variable_labels.do

/* Prepare segregation correlates */
do $scode/b/prep_correlates.do

/*******************************/
/* miscellaneous/appendix data */
/*******************************/
/* 11. create the village level pc11 dataset independently*/
do $scode/b/create_census_village_pg_shares.do

/* 12. generate district-level analysis data for comparing nearby rural-urban */
do $scode/b/gen_district_correlates_urban_rural.do

/* 13. generate data for seg decreasing with increasing block size graph */
do $scode/b/gen_seg_block_groups.do

/* 14. skipped in replication run: confirmatory EC village build not used downstream */
// do $scode/b/gen_ec_all_village.do

/* 15. generate us data */
do $scode/b/gen_us_seg_variables.do

/* 17. analysis effect of reweighting the town sample  */
do $scode/a/reweight_town_subd_representativeness.do

/*****************/
/* Save End Time */
/*****************/
global end_time "$S_DATE $S_TIME"
di  "Build started at: $start_time"
di "Build ended at: $end_time"

/* run the analysis */
/* note, individual 1%/education results take a day or so
to run and have been commented out. If there's a need to re-run those results 
change **global fast 1** to **global fast 0** in make_seg_results.do  */
do $scode/a/make_seg_results.do

/* create time series of segregation from pc0111 district handbooks */
// do $scode/b/handbooks/make_handbooks.do
