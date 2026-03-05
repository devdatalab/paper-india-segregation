/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $raw/clean/shrug/shrug_pc11_pca.dta                            */
/*   - $raw/clean/shrug/shrug_pc11_td.dta                             */
/*   - $tmp/secc/segregation_citydata_urban_200.dta                  */
/*   - $tmp/pc11/pc11_muslims_urban.dta                         */
/* OUTPUTS:                                                            */
/*   - $tmp/entropy_weights.dta                                 */
/*   - $tmp/pc11_town_vars.dta                                          */
/*   - $tmp/seg_urban_repres_reweighted.dta                             */
/*   - $tmp/reweighting_means.csv                                      */
/* GOAL:                                                               */
/*   Reweight the urban sample to match population covariates.          */
/*                                                                     */
/* Reweight the urban sample data so it aligns more with the full      */
/* India population (Table 2). Use the new sampling weights to         */
/* regenerate segregation and isolation results (Figure 1).            */
/***********************************************************************/

/**********************************************************/
/* prog gen_comparison_vars:

This program generates all the comparison variables we will use, we regenerate them from
scratch since there are a lot of versions of them around we want to make sure we are using
the most correct versions.

*/
/**********************************************************/
cap prog drop gen_comparison_vars
prog def gen_comparison_vars

  syntax, loc(string)
  
  if "`loc'" == "urban" local d td
  if "`loc'" == "rural" local d vd

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
  gen hosp_pc = pc11_`d'_all_hospital * 100000 / pc11_pca_tot_p 

  /* require non-zero public services */
  foreach service in prim mid {
    replace `service'_pc = . if `service'_pc == 0
  }
  
  /* create city_origin_year variable */
  if "`loc'" == "urban" {
    gen city_origin_year = .
    forval y = 1901(10)2011 {
      replace city_origin_year = `y' if mi(city_origin_year) & !mi(pc11_td_tot_p_`y') & (pc11_td_tot_p_`y' != 0)
    }
  }
  
end
/* END Program */

/* ---------------------------- cell:  ---------------------------- */

 /*****************************************************************************************/
 /* make a shrid level town dataset with all the PC11 side comparison fields that we want */
 /*****************************************************************************************/

/* combine 2011 pca and td */
use $raw/clean/shrug/shrug_pc11_pca, clear
merge 1:1 shrid using $raw/clean/shrug/shrug_pc11_td, gen (ms)

/* keep only town data */
keep if pc11_sector != 2

/* keep only selected variables */
keep shrid pc11_pca_tot_p pc11_pca_p_sc pc11_td_tot_p_19* pc11_td_tot_p_20* pc11_td_p_sch ///
    pc11_td_m_sch pc11_td_s_sch pc11_td_all_hospital pc11_td_area

/* save the shrid town dataset */
save $tmp/pc11_town_vars, replace

/* ---------------------------- cell:  ---------------------------- */

/************************************************/
/* Create Urban SECC side of comparison dataset */
/************************************************/
use $tmp/secc/segregation_citydata_urban_200, clear

/* drop old town identifier, we want to make sure we are using the shrid here */
drop town

/* merge in shrid pca data */
merge 1:1 shrid using $tmp/pc11_town_vars, gen(m1)

/* define the sample used in the paper --- SECC only and SECC-PC11 matches */
gen seg_sample = (m1 == 3 | m1 == 1)
drop m1

/* get PC muslim shares, just to make sure we are using the straight PC11 version of these */
drop muslim_share*
merge 1:1 shrid using $tmp/pc11/pc11_muslims_urban, keepusing(muslim_share_pc11)

/* save a temp data file for easy access below */
save $tmp/seg_urban_repres_reweighted, replace

/* ---------------------------- cell:  ---------------------------- */


/*******************************************/
/* Calculate Propensity Weights for Sample */
/*******************************************/ 
use $tmp/seg_urban_repres_reweighted, clear

/* gen vars of interest */
gen_comparison_vars, loc(urban)

/* create list of target variables to reweight */ 
global vlist_reweight log_city_pop_pc11 log_area_pc11 sc_share muslim_share city_origin_year

/* create a binary indicator for the target (sample) group */ 
gen in_sample = (seg_sample == 1)

/* duplicate all the observations in the SECC sample group, this gives us two complete groups to compare:
- SECC (expanded set)
- PC11 (includes PC11 only and those in both datasets) */
expand 2 if in_sample == 1, gen(target_pop)
replace target_pop = 1 if in_sample == 0

/* now do the entropy balancing version */
gen control_wt = 1
gen treat = target_pop

/* for rebalancing only, set missing variables to their mean values */
foreach v in $vlist_reweight {
  sum `v'
  replace `v' = `r(mean)' if mi(`v')
}

ebalance treat $vlist_reweight, targets(2) maxiter(50) gen(ewt) wttreat basewt(control_wt)

/* combine the entropy weights with the subgroup population weights */
gen ewt_muslim = ewt * city_pop_muslim
gen ewt_sc     = ewt * city_pop_sc

/* save both sets of weights to use in rest of project */
savesome shrid ewt ewt_sc ewt_muslim using $tmp/entropy_weights if target_pop == 0, replace

/* show that the weighting improved the situation */
sum $vlist_reweight          if target_pop == 0
sum $vlist_reweight [aw=ewt] if target_pop == 0
sum $vlist_reweight          if target_pop == 1

/* store all means for the unadjusted, adjusted, and reference samples */
global f $tmp/reweighting_means.csv
cap erase $f

foreach v in $vlist_reweight {

  /* unweighted mean */
  sum `v' if  target_pop == 0
  local mean: di %5.2f `r(mean)'
  append_to_file using $f, s("`v'_nowt_mean,`mean'") format(string) 

  /* entropy-weighted mean */
  sum `v' [aw=ewt] if  target_pop == 0
  local mean: di %5.2f `r(mean)'
  append_to_file using $f, s("`v'_ewt_mean,`mean'") format(string) 

  /* target mean */
  sum `v' if  target_pop == 1
  local mean: di %5.2f `r(mean)'
  append_to_file using $f, s("`v'_ref_mean,`mean'") format(string) 

}

/* store sample sizes */
sum pc11_pca_tot_p if target_pop == 0
append_to_file using $f, s("nowt_n,`r(N)'") format(string)
sum pc11_pca_tot_p [aw=ewt] if target_pop == 0
append_to_file using $f, s("ewt_n,`r(N)'") format(string)
sum pc11_pca_tot_p if target_pop == 1
append_to_file using $f, s("ref_n,`r(N)'") format(string)

/* ---------------------------- cell:  ---------------------------- */

/* report segregation statistics before and after entropy reweighting   */

/* Put this in a program so it displays nicely to screen */
cap prog drop show_seg
prog def show_seg

  /* compare unweighted / weighted dissimilarity */
  qui {
    sum city_dissim_sc [aw=city_pop_sc] if target_pop == 0
    local dissim_sc_nowt: di %5.2f `r(mean)'
    sum city_dissim_muslim [aw=city_pop_muslim] if target_pop == 0
    local dissim_muslim_nowt: di %5.2f  `r(mean)'
    sum city_dissim_sc [aw=ewt_sc] if target_pop == 0
    local dissim_sc_ewt: di %5.2f  `r(mean)'
    sum city_dissim_muslim [aw=ewt_muslim] if target_pop == 0
    local dissim_muslim_ewt: di %5.2f  `r(mean)'
  }  
  di as txt "Average Dissimilarity Index by Group and Weighting:"
  di as txt "{hline 60}"
  di as txt "{col 25}Unweighted{col 45}Weighted"
  di as txt "{hline 60}"
  di as txt "Scheduled Castes   {col 25}" %5.2f `dissim_sc_nowt' "{col 45}" %5.2f `dissim_sc_ewt'
  di as txt "Muslims            {col 25}" %5.2f `dissim_muslim_nowt' "{col 45}" %5.2f `dissim_muslim_ewt'
  di as txt "{hline 60}"
  
  /* repeat for Isolation */
  qui {
    sum city_iso_sc [aw=city_pop_sc] if target_pop == 0
    local iso_sc_nowt: di %5.2f  `r(mean)'
    sum city_iso_muslim [aw=city_pop_muslim] if target_pop == 0
    local iso_muslim_nowt: di %5.2f  `r(mean)'
    sum city_iso_sc [aw=ewt_sc] if target_pop == 0
    local iso_sc_ewt: di %5.2f  `r(mean)'
    sum city_iso_muslim [aw=ewt_muslim] if target_pop == 0
    local iso_muslim_ewt: di %5.2f  `r(mean)'
  }  
  di as txt "Average Isolation Index by Group and Weighting:"
  di as txt "{hline 60}"
  di as txt "{col 25}Unweighted{col 45}Weighted"
  di as txt "{hline 60}"
  di as txt "Scheduled Castes   {col 25}" %5.2f `iso_sc_nowt' "{col 45}" %5.2f `iso_sc_ewt'
  di as txt "Muslims            {col 25}" %5.2f `iso_muslim_nowt' "{col 45}" %5.2f `iso_muslim_ewt'
  di as txt "{hline 60}"

  /* store all the estimates for the reweighting table */
  foreach m in iso dissim {
    foreach g in sc muslim {
      append_to_file using $f, s("`m'_`g'_ewt,``m'_`g'_ewt'") format(string)
      append_to_file using $f, s("`m'_`g'_nowt,``m'_`g'_nowt'") format(string)
    }
  }

end
/** END program show_seg ***********/
show_seg

global ofile $out/reweighted_means.tex
table_from_tpl, t($scode/a/tpl/app_table_reweighted_means_tpl.tex) r($f) o($ofile)
cat $ofile
