/*======================================================================
Input files:
  - $pc01/pc01_hb_eb_pop.dta
  - $shrug/keys/shrug_pc01u_key.dta
  - $tmp/secc/segregation_citydata_urban_200.dta
  - $pc01/pc01u_pca_clean.dta

Output files:
  - $out/seg_time_01_11_pc01_secc.tex
======================================================================*/

/********************/
/* Setup + logging   */
/********************/

cap log close
log using "$tmp/seg_changes_pc01_to_secc.log", replace

/******************************************************/
/* 1) Load and collapse PC01 HB to shrid (town) */
/******************************************************/

use "$pc01/pc01_hb_eb_pop.dta", clear

/* normalize ids */
tostring pc01_state_id pc01_district_id pc01_town_id, replace
replace pc01_state_id = substr("00", 1, 2 - length(pc01_state_id)) + pc01_state_id
replace pc01_district_id = substr("00", 1, 2 - length(pc01_district_id)) + pc01_district_id
replace pc01_town_id = substr("00000000", 1, 8 - length(pc01_town_id)) + pc01_town_id

/* merge to shrid via shrug key */
merge m:1 pc01_state_id pc01_town_id using "$shrug/keys/shrug_pc01u_key.dta", keepusing(shrid)
keep if _merge == 3
drop _merge

/* collapse to shrid */
gen eb_one = 1
collapse (sum) eb_count_01 = eb_one eb_pop_total_01 = total_pop ///
         (first) d_sc_pc01 iso_sc_pc01 pc01_state_id pc01_district_id pc01_town_id, by(shrid)

/* keep a town-level HB dataset */
save $tmp/pc01_hb_town, replace

/************************************************************/
/* 2) Map PC01 HB towns to shrid and merge SECC city data */
/************************************************************/

use $tmp/pc01_hb_town, clear

/* merge SECC (2011/12) segregation */
merge m:1 shrid using "$tmp/secc/segregation_citydata_urban_200.dta", ///
    keepusing(city_dissim_sc city_iso_sc city_pop pc11_td_p_sc pc11_pca_tot_p)

keep if _merge == 3

drop _merge

/* rename SECC segregation vars to match style */
rename city_dissim_sc d_sc_pc11
rename city_iso_sc iso_sc_pc11

/************************************************************/
/* 3) Merge PCA totals for population match + SC weights */
/************************************************************/

/* PC01 PCA (collapse to town, sum) */
use "$pc01/pc01u_pca_clean.dta", clear

tostring pc01_state_id pc01_district_id pc01_town_id, replace
replace pc01_state_id = substr("00", 1, 2 - length(pc01_state_id)) + pc01_state_id
replace pc01_district_id = substr("00", 1, 2 - length(pc01_district_id)) + pc01_district_id
replace pc01_town_id = substr("00000000", 1, 8 - length(pc01_town_id)) + pc01_town_id

collapse (sum) pc01_pca_tot_p pc01_pca_p_sc pc01_pca_p_lit, by(pc01_state_id pc01_district_id pc01_town_id)

save $tmp/pc01_pca_town, replace

/* return to analysis dataset and merge PCA totals */
use $tmp/pc01_hb_town, clear
merge m:1 shrid using "$tmp/secc/segregation_citydata_urban_200.dta", ///
    keepusing(city_dissim_sc city_iso_sc city_pop pc11_td_p_sc pc11_pca_tot_p)

keep if _merge == 3

drop _merge

/* rename SECC segregation vars to match style */
rename city_dissim_sc d_sc_pc11
rename city_iso_sc iso_sc_pc11
merge m:1 pc01_state_id pc01_district_id pc01_town_id using $tmp/pc01_pca_town, ///
    keepusing(pc01_pca_tot_p pc01_pca_p_sc pc01_pca_p_lit)
keep if _merge == 3
drop _merge

/*************************************/
/* 4) Sample restrictions (SECC)   */
/*************************************/

/* (i) >=4 EBs in 2001 */
keep if eb_count_01 >= 4

/* (ii) population match within 50% for 2001 and 2011 */
gen ratio_pop_01 = eb_pop_total_01 / pc01_pca_tot_p
gen ratio_pop_11 = city_pop / pc11_pca_tot_p
keep if inrange(ratio_pop_01, 0.5, 2) & inrange(ratio_pop_11, 0.5, 2)

/* save analysis dataset */
save $tmp/seg_pc01_secc, replace

/**********************************************/
/* 5) IPW weights for representativeness    */
/**********************************************/

/* build PCA universe with predictors */
use $tmp/pc01_pca_town, clear

/* predictors */
gen ln_pop = ln(pc01_pca_tot_p)
gen lit_share = pc01_pca_p_lit / pc01_pca_tot_p

/* merge sample flag */
merge 1:1 pc01_state_id pc01_district_id pc01_town_id using $tmp/seg_pc01_secc, keepusing(pc01_state_id)
gen in_sample = _merge == 3
drop _merge

/* estimate a propensity model with city population and literacy rate */
logit in_sample ln_pop lit_share
predict p_hat

/* segregation weight is inverse propensity, scale up the ones most likely to represent the missing data */
gen seg_wt = 1 / p_hat if in_sample
winsorize seg_wt 0 99, centile replace

/* keep weights */
keep if in_sample
keep pc01_state_id pc01_district_id pc01_town_id seg_wt

save $tmp/seg_wt, replace

/**********************************************/
/* 6) Merge weights + generate estimates    */
/**********************************************/

use $tmp/seg_pc01_secc, clear
merge m:1 pc01_state_id pc01_district_id pc01_town_id using $tmp/seg_wt, assert(match)
keep if _merge == 3
drop _merge

/* SC weights */
gen wt_sc_01 = pc01_pca_p_sc
gen wt_sc_11 = pc11_td_p_sc

/* IPW x SC weights */
gen comb_wt_01 = seg_wt * wt_sc_01
la var comb_wt_01 "IPW * SC-pop (2001)"

gen comb_wt_11 = seg_wt * wt_sc_11
la var comb_wt_11 "IPW * SC-pop (2011)"

/* differences */
gen d_sc_change = d_sc_pc11 - d_sc_pc01
gen iso_sc_change = iso_sc_pc11 - iso_sc_pc01

/**********************************************/
/* 6b) Diagnostics: weight effects           */
/**********************************************/

/* summarize weights */
sum seg_wt
sum wt_sc_01 wt_sc_11
sum comb_wt_01 comb_wt_11

/* compare weighted vs unweighted means (more precision) */
mean d_sc_pc01 [pw = comb_wt_01]
mean d_sc_pc01
mean d_sc_pc11 [pw = comb_wt_11]
mean d_sc_pc11
mean d_sc_change [pw = comb_wt_01]
mean d_sc_change

mean iso_sc_pc01 [pw = comb_wt_01]
mean iso_sc_pc01
mean iso_sc_pc11 [pw = comb_wt_11]
mean iso_sc_pc11
mean iso_sc_change [pw = comb_wt_01]
mean iso_sc_change

/*************************************/
/* 7) Output estimates + table     */
/*************************************/

append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("name,value") format(string) erase

count
local sample_n = r(N)
append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("sample_n,`sample_n'") format(string)

/*********************/
/* Isolation results */
/*********************/

/* Weighted (IPW x SC) */
mean iso_sc_pc01 [pw = comb_wt_01]
local pc01_iso_wtd : display %6.3f _b[iso_sc_pc01]
local pc01_iso_wtd_se : display %6.3f _se[iso_sc_pc01]

mean iso_sc_pc11 [pw = comb_wt_11]
local pc11_iso_wtd : display %6.3f _b[iso_sc_pc11]
local pc11_iso_wtd_se : display %6.3f _se[iso_sc_pc11]

quietly mean iso_sc_change [pw = comb_wt_01]
local diff_iso_wtd : display %6.3f _b[iso_sc_change]
local diff_iso_wtd_se : display %6.3f _se[iso_sc_change]

append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("pc01_iso_wtd,`pc01_iso_wtd'") format(string)
append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("pc11_iso_wtd,`pc11_iso_wtd'") format(string)
append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("diff_iso_wtd,`diff_iso_wtd'") format(string)
append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("pc01_iso_wtd_se,`pc01_iso_wtd_se'") format(string)
append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("pc11_iso_wtd_se,`pc11_iso_wtd_se'") format(string)
append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("diff_iso_wtd_se,`diff_iso_wtd_se'") format(string)

/* Unweighted (SC-pop only) */
quietly mean iso_sc_pc01 [pw = wt_sc_01]
local pc01_iso_uwtd : display %6.3f _b[iso_sc_pc01]
local pc01_iso_uwtd_se : display %6.3f _se[iso_sc_pc01]

quietly mean iso_sc_pc11 [pw = wt_sc_11]
local pc11_iso_uwtd : display %6.3f _b[iso_sc_pc11]
local pc11_iso_uwtd_se : display %6.3f _se[iso_sc_pc11]

quietly mean iso_sc_change [pw = wt_sc_01]
local diff_iso_uwtd : display %6.3f _b[iso_sc_change]
local diff_iso_uwtd_se : display %6.3f _se[iso_sc_change]

append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("pc01_iso_uwtd,`pc01_iso_uwtd'") format(string)
append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("pc11_iso_uwtd,`pc11_iso_uwtd'") format(string)
append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("diff_iso_uwtd,`diff_iso_uwtd'") format(string)
append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("pc01_iso_uwtd_se,`pc01_iso_uwtd_se'") format(string)
append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("pc11_iso_uwtd_se,`pc11_iso_uwtd_se'") format(string)
append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("diff_iso_uwtd_se,`diff_iso_uwtd_se'") format(string)

/*************************/
/* Dissimilarity results */
/*************************/

/* Weighted (IPW x SC) */
mean d_sc_pc01 [pw = comb_wt_01]
local pc01_d_wtd : display %6.3f _b[d_sc_pc01]
local pc01_d_wtd_se : display %6.3f _se[d_sc_pc01]

mean d_sc_pc11 [pw = comb_wt_11]
local pc11_d_wtd : display %6.3f _b[d_sc_pc11]
local pc11_d_wtd_se : display %6.3f _se[d_sc_pc11]

mean d_sc_change [pw = comb_wt_01]
local diff_d_wtd : display %6.3f _b[d_sc_change]
local diff_d_wtd_se : display %6.3f _se[d_sc_change]

append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("pc01_d_wtd,`pc01_d_wtd'") format(string)
append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("pc11_d_wtd,`pc11_d_wtd'") format(string)
append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("diff_d_wtd,`diff_d_wtd'") format(string)
append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("pc01_d_wtd_se,`pc01_d_wtd_se'") format(string)
append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("pc11_d_wtd_se,`pc11_d_wtd_se'") format(string)
append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("diff_d_wtd_se,`diff_d_wtd_se'") format(string)

/* Unweighted (SC-pop only) */
quietly mean d_sc_pc01 [pw = wt_sc_01]
local pc01_d_uwtd : display %6.3f _b[d_sc_pc01]
local pc01_d_uwtd_se : display %6.3f _se[d_sc_pc01]

quietly mean d_sc_pc11 [pw = wt_sc_11]
local pc11_d_uwtd : display %6.3f _b[d_sc_pc11]
local pc11_d_uwtd_se : display %6.3f _se[d_sc_pc11]

quietly mean d_sc_change [pw = wt_sc_01]
local diff_d_uwtd : display %6.3f _b[d_sc_change]
local diff_d_uwtd_se : display %6.3f _se[d_sc_change]

append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("pc01_d_uwtd,`pc01_d_uwtd'") format(string)
append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("pc11_d_uwtd,`pc11_d_uwtd'") format(string)
append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("diff_d_uwtd,`diff_d_uwtd'") format(string)
append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("pc01_d_uwtd_se,`pc01_d_uwtd_se'") format(string)
append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("pc11_d_uwtd_se,`pc11_d_uwtd_se'") format(string)
append_to_file using "$tmp/seg_estimates_pc01_secc.csv", s("diff_d_uwtd_se,`diff_d_uwtd_se'") format(string)

/*************************************/
/* Build LaTeX table                 */
/*************************************/

table_from_tpl, t($scode/a/tpl/seg_time_tpl.tex) ///
               r($tmp/seg_estimates_pc01_secc.csv) ///
               o($out/seg_time_01_11_pc01_secc.tex)

di as txt "Wrote: " as res "$tmp/seg_estimates_pc01_secc.csv"
di as txt "Table: " as res "$out/seg_time_01_11_pc01_secc.tex"

log close
