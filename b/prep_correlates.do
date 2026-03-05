/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $raw/violence/violence_matched_except_jk.dta                   */
/*   - $raw/violence/violence_matched_jk.dta                          */
/*   - $mobility/secc/secc_mobility_town.dta                            */
/*   - $mobility/covars/secc_gini_rural_district.dta                    */
/*   - $mobility/covars/secc_gini_urban_town.dta                        */
/*   - $shrug/keys/shrug_pc91u_key.dta                                  */
/*   - $shrug/keys/shrug_pc01u_key.dta                                  */
/*   - $shrug/data/shrug_pc91_pca.dta                                   */
/*   - $tmp/secc/secc_ec_citydata_urban.dta                          */
/*   - $tmp/secc/segregation_citydata_urban_200.dta                  */
/* OUTPUTS:                                                            */
/*   - $tmp/seg_correlates.dta                                          */
/*   - $tmp/seg_city_data_1.dta                                         */
/*   - $tmp/seg_city_data_2.dta                                         */
/*   - $tmp/seg_violence.dta                                            */
/*   - $tmp/seg_mobility.dta                                            */
/*   - $tmp/seg_rural_district_gini.dta                                 */
/*   - $tmp/seg_town_gini.dta                                           */
/*   - $tmp/seg_growth.dta                                              */
/* GOAL:                                                               */
/*   Build shrid-level correlates for segregation analysis.             */
/*                                                                     */
/* Prepares shrid-level correlates to understand what is related to    */
/* segregation                                                         */
/* Target is shrid1 (looks like 11-01-000830)                           */
/***********************************************************************/

use $raw/violence/violence_matched_except_jk.dta, clear

/* get the shrid1 */
merge m:1 pc91_state_id pc91_district_id pc91_town_id using $shrug/keys/shrug_pc91u_key, keep(match) keepusing(shrid)

/* save the violence with shrid */
save $tmp/violence_shrid1, replace

/* repeat for jammu-kashmir data, which uses pc01 */
use $raw/violence/violence_matched_jk.dta, clear
merge m:1 pc01_state_id pc01_town_id using $shrug/keys/shrug_pc01u_key, keep(match) keepusing(shrid)

/* combine with the rest of the data */
append using $tmp/violence_shrid1

/* do some cleaning steps */
drop if mi(shrid)

/* blank = 0 */
replace killed =0 if killed ==.
replace injured=0 if injured==.

/* combine deaths and injuries */
gen violence_index = killed + 0.2*injured

/* tag religious causes */
replace reported_c = lower(reported_c)
gen religious = 0
replace religious = 1 if strpos(reported_c, "religious") | strpos(reported_c, "worship") | strpos(reported_c, "temple") | strpos(reported_c, "bjp") | strpos(reported_c, "nationalist")

/* collapse to one row per town */
gen event_count = 1
collapse (sum) violence_index killed injured event_count religious_event_count = religious, by(shrid)

/* create some more analysis variables */
gen ln_killed = ln(killed + 1)
gen ln_injured = ln(injured + 1)

gen any_event = event_count > 0
gen any_rel_event = religious_event_count > 0
gen any_killed = killed > 0
gen any_injured = injured > 0
gen non_rel_event_count = event_count - religious_event_count

/* save violence data ready to go */
save $tmp/seg_violence, replace

/* ---------------------------- cell:  ---------------------------- */

/***************************/
/* prepare upward mobility */
/***************************/
use $mobility/secc/secc_mobility_town, clear

egen p25 = rowmean(p25_lb p25_ub)

/* fix the broken info */
split type, gen(stub) parse(",")
ren stub4 n
replace n = substr(n, 1, strlen(n) - 1)

/* drop if we didn't get at least 6 monotonic ed groups */
destring stub3, replace
drop if stub3 < 6

/* get shrid */
merge m:1 pc11_state_id pc11_town_id using $shrug/keys/shrug_pc11u_key, keep(match) keepusing(shrid)

/* get pc11 population for weighted collapse */
merge m:1 shrid using $shrug/data/shrug_pc11_pca, nogen keep(match) keepusing(pc11_pca_tot_p )

/* collapse to shrids towns that cross district lines (since shrid key is state-town) */
collapse (mean) p25 [pw=pc11_pca_tot_p] , by(shrid)

/* save town-level p25 */
save $tmp/seg_mobility, replace

/*********************/
/* gini coefficients */
/*********************/
use $mobility/covars/secc_gini_rural_district.dta, clear
ren *gini rural_*gini
save $tmp/seg_rural_district_gini, replace

use $mobility/covars/secc_gini_urban_town.dta, clear
merge m:1 pc11_state_id pc11_town_id using $shrug/keys/shrug_pc11u_key, keep(match) keepusing(shrid)
keep shrid *gini
ren *gini town_*gini

/* collapse to shrid and save */
collapse (mean) *gini, by(shrid)
save $tmp/seg_town_gini, replace

/* ---------------------------- cell ---------------------------- */

/*********************/
/* town growth rates */
/*********************/
use shrid pc91_pca_tot_p using $shrug/data/shrug_pc91_pca.dta, clear
merge 1:1 shrid using $shrug/data/shrug_pc01_pca.dta, keep(match) nogen keepusing(pc01_pca_tot_p)
merge 1:1 shrid using $shrug/data/shrug_pc11_pca.dta, keep(match) nogen keepusing(pc11_pca_tot_p pc11_sector)
keep if inlist(pc11_sector, 1, 3)

/* calculate full period growth rate */
gen ln_growth = (ln(pc11_pca_tot_p ) - ln(pc91_pca_tot_p )) / 20

/* winsorize outliers */
winsorize ln_growth 1 99, replace centile

keep shrid ln_growth
save $tmp/seg_growth, replace

/* ---------------------------- cell ---------------------------- */
/****************************/
/* prep first citydata file */
/****************************/
use $tmp/secc/secc_ec_citydata_urban, clear

/* generate muslim and SC job share */
gen muslim_job_share = muslim_ec / (muslim_ec + nonmuslim_ec)
gen sc_job_share = sc_ec / (sc_ec + nonsc_ec)

/* gen log consumption per capita */
foreach v in "" _sc _muslim _nonscmuslim {
  gen ln_cons_pc`v' = ln(cons_pc`v')
}

/* generate some additional useful vars */
gen ln_city_pop = ln(city_pop)
gen muslim_ed_gap = ed_yrs - ed_yrs_muslim
gen sc_ed_gap = ed_yrs - ed_yrs_sc
gen muslim_ln_cons_gap = ln_cons_pc - ln_cons_pc_muslim
gen sc_ln_cons_gap = ln_cons_pc - ln_cons_pc_sc


global keeplist ed_yrs ed_yrs_muslim ed_yrs_sc ed_yrs_nonscmuslim muslim_ed_gap sc_ed_gap
global keeplist $keeplist city_pop ln_city_pop
global keeplist $keeplist cons_pc ln_cons_pc cons_pc_sc cons_pc_muslim cons_pc_nonscmuslim muslim_ln_cons_gap sc_ln_cons_gap ln_cons_pc_sc ln_cons_pc_muslim ln_cons_pc_nonscmuslim
global keeplist $keeplist slum
global keeplist $keeplist muslim_job_share sc_job_share


/* shrid is called "town" here */
ren town shrid

keep shrid $keeplist
save $tmp/seg_city_data_1, replace

/* ---------------------------- cell ---------------------------- */
/*****************************/
/* prep second citydata file */
/*****************************/
use $tmp/secc/segregation_citydata_urban_200, clear

ren muslim_share muslim_pop_share
ren sc_share sc_pop_share
ren nonscmuslim_share nonscmuslim_pop_share

global keeplist city_dissim_* city_iso_* city_pop_pc11 prim_pc mid_pc sec_pc hosp_pc city_origin_year log_area_pc11
global keeplist $keeplist muslim_pop_share sc_pop_share nonscmuslim_pop_share
keep shrid pc11_state_id pc11_district_id $keeplist 

save $tmp/seg_city_data_2, replace

/* ---------------------------- cell ---------------------------- */

/********************************************/
/* Bring all the analyzed datasets together */
/********************************************/
use $tmp/seg_city_data_1, clear
merge 1:1 shrid using $tmp/seg_city_data_2, nogen

/* bring in violence data.  */
merge 1:1 shrid using $tmp/seg_violence, gen(_m_violence) keep(match master)

/* For violent events, we assume "not in violence" data means no violence */
global violence_vars ln_killed ln_injured killed injured event_count religious_event_count  any_event any_rel_event any_killed any_injured non_rel_event_count
foreach v in $violence_vars {
  replace `v' = 0 if mi(`v')
}

/* bring in upward mobility */
merge 1:1 shrid using $tmp/seg_mobility, gen(_m_mobility) keep(match master)

/* bring in gini coefficients */
merge 1:1 shrid using $tmp/seg_town_gini, gen(_m_town_gini) keep(match master)
merge m:1 pc11_district_id using $tmp/seg_rural_district_gini, gen(_m_rural_gini) keep(match master)

/* town growth rate */
merge 1:1 shrid using $tmp/seg_growth, gen(_m_growth) keep(match master)

/* save the analysis dataset */
save $tmp/seg_correlates, replace
