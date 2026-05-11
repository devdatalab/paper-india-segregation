/*****************************************/
/* BUILD SEG CORRELATES HANDOFF DATASET  */
/*****************************************/

clear all
set more off
set rmsg on

/**********************/
/* IEC server paths   */
/**********************/

global scode "/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation"
global tools "$scode/tools"

global raw "/dartfs/rc/lab/I/IEC/seg"
global mobility "/dartfs/rc/lab/I/IEC/mobility"
global shrug "/dartfs/rc/lab/I/IEC/shrug"
global tmp "/dartfs-hpc/scratch/siddiqui/seg_correlates_handoff/tmp"
global handoff_iec "/dartfs/rc/lab/I/IEC/seg/harmonized"
global handoff_scratch "/dartfs-hpc/scratch/siddiqui/seg_correlates_handoff/harmonized"

cap mkdir "/dartfs-hpc/scratch/siddiqui/seg_correlates_handoff"
cap mkdir "$tmp"
cap mkdir "$tmp/secc"
cap mkdir "$handoff_iec"
cap mkdir "$handoff_scratch"

cap file close handoff_probe
cap file open handoff_probe using "$handoff_iec/.write_test", write replace
if _rc == 0 {
    file close handoff_probe
    cap erase "$handoff_iec/.write_test"
    global handoff "$handoff_iec"
}
else {
    global handoff "$handoff_scratch"
    di as error "IEC handoff directory is not writable from this account; using $handoff"
}

/**********************/
/* Validate inputs    */
/**********************/

local required_files ///
    $raw/violence/violence_matched_except_jk.dta ///
    $raw/violence/violence_matched_jk.dta ///
    $mobility/secc/secc_mobility_town.dta ///
    $mobility/covars/secc_gini_rural_district.dta ///
    $mobility/covars/secc_gini_urban_town.dta ///
    $shrug/keys/shrug_pc91u_key.dta ///
    $shrug/keys/shrug_pc01u_key.dta ///
    $shrug/keys/shrug_pc11u_key.dta ///
    $shrug/data/shrug_pc91_pca.dta ///
    $shrug/data/shrug_pc01_pca.dta ///
    $shrug/data/shrug_pc11_pca.dta ///
    $raw/clean/secc_ec_citydata_urban.dta ///
    $raw/clean/segregation_citydata_urban_200.dta

foreach path of local required_files {
    if !fileexists("`path'") {
        di as error "Missing required input: `path'"
        exit 601
    }
}

/****************************************************/
/* Stage stable clean inputs at expected TMP paths   */
/****************************************************/

copy "$raw/clean/secc_ec_citydata_urban.dta" ///
    "$tmp/secc/secc_ec_citydata_urban.dta", replace
copy "$raw/clean/segregation_citydata_urban_200.dta" ///
    "$tmp/secc/segregation_citydata_urban_200.dta", replace

/****************************/
/* Run existing producer    */
/****************************/

do "$tools/do/tools.do"
do "$scode/b/prep_correlates.do"

/****************************/
/* Save stable handoff      */
/****************************/

if !fileexists("$tmp/seg_correlates.dta") {
    di as error "Producer did not write expected file: $tmp/seg_correlates.dta"
    exit 601
}

copy "$tmp/seg_correlates.dta" "$handoff/seg_correlates.dta", replace

use "$handoff/seg_correlates.dta", clear
describe
count

di as result "Wrote stable handoff: $handoff/seg_correlates.dta"
