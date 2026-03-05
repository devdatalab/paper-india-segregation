/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_citydata_{urban,rural}_200.dta          */
/*   - $raw/clean/shrug/shrug_pc11_pca.dta                            */
/*   - $raw/clean/shrug/shrug_pc11_td.dta                             */
/*   - $raw/clean/shrug/shrug_pc11_vd.dta                             */
/* OUTPUTS:                                                            */
/*   - $out/table_repres.csv                                           */
/*   - $out/town_subd_repres.tex                                       */
/*   - $tmp/seg_{urban,rural}_repres.dta                                */
/*   - $tmp/shrid_town_key.dta                                          */
/*   - $tmp/shrug_rural_seg_key.dta                                     */
/* GOAL:                                                               */
/*   Tabulate representativeness of town/subdistrict samples.           */
/*                                                                     */
/* This dofile answers the question: how representative are our town   */
/* and subdistrict datasets?                                           */
/*                                                                     */
/* We are missing a bunch of data that was not in SECC. For variables  */
/* that we can observe in the missing and the non-missing data, we     */
/* want a 2-column table:                                              */
/* 1. Sample urban mean in our dataset (standard error in parentheses) */
/* 2. Sample urban mean in all-India dataset (s.e. in parentheses)     */
/* 3. Same thing for columns 3 and 4.                                  */
/*                                                                     */
/* The variables are:                                                  */
/* 1. Log town population                                              */
/* 2. Town area                                                        */
/* 3. SC Share                                                         */
/* 4. Muslim share                                                     */
/* 5. Town age (see below)                                             */
/* 6. # primary schools per 100,000 people (see below)                 */
/* 7. Same as #6 for secondary schools, hospitals                      */
/***********************************************************************/

/**********************************************************/
/* prog create_var_repres: Program to gen var of interest */
/**********************************************************/
cap prog drop create_var_repres
prog def create_var_repres

  qui describe

  local which = r(datalabel)
  
  if "`which'" == "urban" local d td
  if "`which'" == "rural" local d vd

  /* first test if they're created easily w same vars for both urban & rural */
  /* prep the comparison vars */
  capdrop sc_share log_city_pop_pc11 log_area_pc11 city_origin_year prim_pc mid_pc sec_pc hosp_pc
  gen log_city_pop_pc11 = ln(pc11_pca_tot_p)
  gen log_area_pc11 = ln(pc11_`d'_area)
  gen sc_share = pc11_pca_p_sc / pc11_pca_tot_p
  
  /* schools, clinics per 100k people */
  gen prim_pc = pc11_`d'_p_sch * 100000 / pc11_pca_tot_p 
  gen mid_pc = pc11_`d'_m_sch * 100000 / pc11_pca_tot_p 
  gen sec_pc = pc11_`d'_s_sch * 100000 / pc11_pca_tot_p 
  gen hosp_pc = pc11_`d'_all_hosp * 100000 / pc11_pca_tot_p 

  /* create city_origin_year variable */
  if "`which'" == "urban" {
    gen city_origin_year = .
    forval y = 1901(10)2011 {
      replace city_origin_year = `y' if mi(city_origin_year) & !mi(pc11_td_tot_p_`y') & (pc11_td_tot_p_`y' != 0)
    }
  }
  
end
/* END Program */

/************************/
/* Create Urban Dataset */
/************************/
use $tmp/secc/segregation_citydata_urban_200, clear

/* drop town var */
drop town

/* make a shrid key with all variables we want first and then merge to the dataset */
preserve

/* merge pca and td */
use $raw/clean/shrug/shrug_pc11_pca, clear
merge 1:1 shrid using $raw/clean/shrug/shrug_pc11_td, gen (ms)

/* keep only town data */
keep if pc11_sector != 2

/* keep only selected variables */
keep shrid pc11_pca_tot_p pc11_pca_p_sc pc11_td_tot_p_19* pc11_td_tot_p_20* pc11_td_p_sch pc11_td_m_sch pc11_td_s_sch pc11_td_all_hospital pc11_td_area
ren pc11_td_all_hospital pc11_td_all_hosp

/* save pc11_town key */
save $tmp/shrid_town_key, replace

restore

/* merge in shrid pca data */
merge 1:1 shrid using $tmp/shrid_town_key, gen(m1)

/* label dataset (so that prog create_var_repres) recognizes the local */
label data "urban"

/* gen seg_sample variable */
gen seg_sample = inlist(m1, 1, 3)
drop m1

/* generate town to be shrid for muslim match */
gen town = shrid

/* get PC muslim shares */
capdrop muslim_share*
merge 1:1 town using $tmp/pc11/pc11_muslims_urban, keep(match master)
ren muslim_share_pc11 muslim_share

/* save temp data */
save $tmp/seg_urban_repres, replace

/************************/
/* Create Rural Dataset */
/************************/
use $raw/clean/shrug/shrug_pc11_pca, clear
merge 1:1  shrid using $raw/clean/shrug/shrug_pc11_vd, keep(match) nogen
merge 1:1 shrid using $raw/clean/shrug/shrug_pc11_subdistrict_key.dta, keep(match) nogen

/* drop village and town shrids */
keep if pc11_sector == 2

/* collapse to subdistrict level */
collapse (sum) pc11_pca_tot_p pc11_vd_area pc11_pca_p_sc pc11_vd_p_sch pc11_vd_m_sch pc11_vd_s_sch pc11_vd_all_hosp, by(pc11_state_id pc11_district_id pc11_subdistrict_id)
save $tmp/shrug_rural_seg_key, replace

/* merge rural data to subdistrict key */
use $tmp/secc/segregation_citydata_rural_200, clear

/* kj: get these back from subdistrict at a later point */
drop if pc11_subdistrict_id == ""
merge 1:1 pc11_state_id pc11_district_id pc11_subdistrict_id using $tmp/shrug_rural_seg_key, gen(m2)

/* create a merge success variable */
gen seg_sample = (m2 == 3 | m2 == 1)
drop m2

/* redefine subdistrict to be concatenated id variables for all variables */
drop subdistrict
gen subdistrict = pc11_state_id + pc11_district_id + pc11_subdistrict_id

/* get PC muslim shares */
capdrop muslim_share*
merge 1:1 subdistrict using $tmp/pc11/pc11_muslims_rural, keep(match master)
ren muslim_share_pc11 muslim_share

/* label data */
label data "rural"

/* save rural separately */
save $tmp/seg_rural_repres, replace

/******************************/
/* Create Vars and Table them */
/******************************/
foreach loc in urban rural {

  use $tmp/seg_`loc'_repres, clear

  /* location-dependent merge identifiers  */
  if "`loc'" == "urban" local id town
  if "`loc'" == "rural" local id subdistrict

  /* gen vars of interest */
  create_var_repres

  /* drop very small towns */
  if "`loc'" == "urban" {
    drop if pc11_pca_tot_p  < 5000
  }
  
  /* define separate globals otherwise rural loop breaks with town age */
  global vlist_compare log_city_pop_pc11 log_area_pc11 sc_share muslim_share prim_pc mid_pc sec_pc hosp_pc 

  /* loop over variables and enter them into the table */
  foreach var in $vlist_compare {

    /* loop over seg sample and full sample */
    foreach sample in seg full {

      /* add local for seg or full sample */
      if "`sample'" == "seg" local sample_mod "if seg_sample == 1"
      if "`sample'" == "full" local sample_mod ""

      /* insert into csv, reference by var name */
      sum `var' `sample_mod', d
      insert_into_file using $out/table_repres.csv, key(`loc'_`sample'_`var'_mean) val(`r(mean)') format(%10.2f)
      sum `var' `sample_mod', d
      insert_into_file using $out/table_repres.csv, key(`loc'_`sample'_`var'_se) val(`r(sd)') format(%10.2f)
      sum `var' `sample_mod', d
      insert_into_file using $out/table_repres.csv, key(`loc'_`sample'_`var'_sum) val(`r(sum)') format(%12.0fc)

    }
  }

  /* store total population in census, and total population that we observe in our data */
  sum pc11_pca_tot_p
  insert_into_file using $out/table_repres.csv, key(`loc'_full_pc11_pca_tot_p_sum) val(`r(sum)') format(%12.0fc)
  
  /* note that even the subdistrict data are called "city_pop" */
  sum city_pop if seg_sample == 1
  insert_into_file using $out/table_repres.csv, key(`loc'_seg_secc_pop_sum) val(`r(sum)') format(%12.0fc)

  /* store muslim dissim */
  sum city_dissim_muslim [aw = city_pop_muslim] if seg_sample == 1, d
  insert_into_file using $out/table_repres.csv, key(`loc'_city_dissim_muslim_mean) val(`r(mean)') format(%10.2f)
  sum city_dissim_muslim [aw = city_pop_muslim] if seg_sample == 1, d
  insert_into_file using $out/table_repres.csv, key(`loc'_city_dissim_muslim_se) val(`r(sd)') format(%10.2f)
  
  /* store sc dissim */
  sum city_dissim_sc [aw = city_pop_sc] if seg_sample == 1, d
  insert_into_file using $out/table_repres.csv, key(`loc'_city_dissim_sc_mean) val(`r(mean)') format(%10.2f)
  sum city_dissim_sc [aw = city_pop_sc] if seg_sample == 1, d
  insert_into_file using $out/table_repres.csv, key(`loc'_city_dissim_sc_se) val(`r(sd)') format(%10.2f)
  
  /* repeat for isolation index */
  sum city_iso_muslim [aw = city_pop_muslim] if seg_sample == 1, d
  insert_into_file using $out/table_repres.csv, key(`loc'_city_iso_muslim_mean) val(`r(mean)') format(%10.2f)
  sum city_iso_muslim [aw = city_pop_muslim] if seg_sample == 1, d
  insert_into_file using $out/table_repres.csv, key(`loc'_city_iso_muslim_se) val(`r(sd)') format(%10.2f)
  sum city_iso_sc [aw = city_pop_sc] if seg_sample == 1, d
  insert_into_file using $out/table_repres.csv, key(`loc'_city_iso_sc_mean) val(`r(mean)') format(%10.2f)
  sum city_iso_sc [aw = city_pop_sc] if seg_sample == 1, d
  insert_into_file using $out/table_repres.csv, key(`loc'_city_iso_sc_se) val(`r(sd)') format(%10.2f)
  
  /* Calculate city_origin_year only for urban data */
  if "`loc'" == "urban" {
  
    /* loop over seg sample and full sample */
    foreach sample in seg full {
  
      /* add local for seg or full sample */
      if "`sample'" == "seg" local sample_mod "if seg_sample == 1"
      if "`sample'" == "full" local sample_mod ""
  
      /* insert into csv, reference by var name */
      sum city_origin_year `sample_mod', d
      insert_into_file using $out/table_repres.csv, key(urban_`sample'_city_origin_year_mean) val(`r(mean)') format(%10.0f)
      sum city_origin_year `sample_mod', d
      insert_into_file using $out/table_repres.csv, key(urban_`sample'_city_origin_year_se) val(`r(sd)') format(%10.0f)
    }
  }
  
  /* extract nr of observations */
  distinct `id'
  local `loc'_full = r(N)
  
  distinct `id' if seg_sample == 1
  local `loc'_seg = r(N)
  
  /* Store Results in csv */
  insert_into_file using $out/table_repres.csv, key(`loc'_full_n) val(``loc'_full') format(%10.0f)
  insert_into_file using $out/table_repres.csv, key(`loc'_seg_n) val(``loc'_seg') format(%10.0f)
}  

/* Transfer results to table */
table_from_tpl, t($scode/a/tpl/table_town_subd_repres_tpl.tex) r($out/table_repres.csv) o($out/town_subd_repres.tex) 
