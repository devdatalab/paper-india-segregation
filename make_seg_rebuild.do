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
global scode "/Users/f0018fb/Dropbox/research/ddl/paper-india-segregation"

/* Set base to the replication data folder */
global base "/Users/f0018fb/Dropbox/tmp/segdata"

/* Set python to your python executable. (Activate conda and run `which python` to find it) */
global python "/opt/homebrew/Caskroom/mambaforge/base/envs/py3/bin/python"
/* Example: global python /opt/homebrew/Caskroom/mambaforge/base/envs/py3/bin/python */

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

/* validate .env exists */
local env_file "$scode/.env"
if !fileexists("`env_file'") {
  di as error "Expected file '$scode/.env' does not exist. It should look something like this: "
  di as error ""
  di as error "SCODE=~/path/to/seg/repo/"
  di as error "BASE=~/path/to/data/"
  error 601
}

/* validate .env has the right content */
local found_scode = 0
local found_base = 0

file open fh using "`env_file'", read text
file read fh line

while r(eof)==0 {
    if strpos("`line'", "SCODE") local found_scode = 1
    if strpos("`line'", "BASE") local found_base = 1
    file read fh line
}

file close fh

assert `found_scode'
assert `found_base'

/**************************************************/
/* validation checks passed; load project configs */
/**************************************************/
do "$scode/set_paths.do"
do "$tools/stata-tex/stata-tex.do"
do "$tools/do/tools.do"

/* load shared helper programs before the build begins */
do "$scode/seg_programs.do"

/* verify the Stata-Python interface. An error here means the Python executable failed
   or could not find the paths specified in .env */
cap erase $out/test.txt
shell PYTHONPATH=$scode $python $scode/a/test.py
cap noi check_file_update_status "$out/test.txt"
cap erase "$out/test.txt"

/*******************/
/* Save Start Time */
/*******************/
global start_time "$S_DATE $S_TIME"

/***************/
/* Set Globals */
/***************/

/* Set rebuild on to make sure all code runs */
global rebuild 1

/*****************************/
/* run the segregation build */
/*****************************/

/***********************************/
/* create main segregation dataset */
/***********************************/
/* 1. aggregate blocks to groups of 200 people and 4000 people */
/* combine SECC and EC block-level data for collapse to block groups */
do $scode/b/merge_secc_ec.do 
  
/* 2. create SECC block group key, and collapse SECC and EC data to group */
do $scode/b/create_secc_block_groups.do

/* 3. compute muslim PC shares at the subdistrict (rural) and town level */
do $scode/b/gen_pc_muslim_share.do
  
/* 4. create public goods and consumption analysis variables */
do $scode/b/gen_pg_cons_variables.do

/* 5. generate segregation variables */
do $scode/b/gen_seg_variables.do

/* 6.  save secc data at the block and city level*/
do $scode/b/gen_segregation_city_block_data.do

/* 7. add variable labels and save labeled datasets in $tmp/secc */
do $scode/b/add_variable_labels.do

/* Prepare segregation correlates */
do $scode/b/prep_correlates.do

/*******************************/
/* miscellaneous/appendix data */
/*******************************/
/* 8. create the village level pc11 dataset independently*/
do $scode/b/create_census_village_pg_shares.do

/* 9. generate district-level analysis data for comparing nearby rural-urban */
do $scode/b/gen_district_correlates_urban_rural.do

/* 10. generate data for seg decreasing with increasing block size graph */
do $scode/b/gen_seg_block_groups.do

/* 11. generate us data */
do $scode/b/gen_us_seg_variables.do

/*****************/
/* Save End Time */
/*****************/
global end_time "$S_DATE $S_TIME"
di  "Build started at: $start_time"
di "Build ended at: $end_time"

/* run the analysis */
do $scode/a/make_seg_results.do
