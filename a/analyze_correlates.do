************************/
/* run some regressions */
/************************/
/* set this to 1 to skip binscatters and go faster */
global skip_bins 0

use $tmp/seg_correlates, replace

/* variable list for binscatters (just make all of the bivariates!) */
global vlist ln_cons_pc city_pop_pc11 ln_city_pop ln_growth log_area_pc11 city_origin_year muslim_pop_share sc_pop_share muslim_job_share sc_job_share ed_yrs ed_yrs_muslim ed_yrs_sc muslim_ed_gap sc_ed_gap p25 cons_pc cons_pc_sc cons_pc_muslim muslim_ln_cons_gap sc_ln_cons_gap slum event_count religious_event_count non_rel_event_count town_cons_gini rural_land_gini rural_cons_gini 

/* primary regression table (avoiding multicollinear variables) */
global reg_varlist ln_city_pop ln_growth muslim_pop_share sc_pop_share city_origin_year ln_cons_pc ln_cons_pc_muslim ln_cons_pc_sc p25 any_event town_cons_gini rural_land_gini
global reg_varlist ln_city_pop ln_growth muslim_pop_share sc_pop_share city_origin_year ln_cons_pc p25 any_event town_cons_gini rural_land_gini

/* short varlist for max sample: i.e. take out p25 and town gini, which restrict the sample a lot */
global short_reg_varlist ln_city_pop ln_growth muslim_pop_share sc_pop_share city_origin_year ln_cons_pc any_event rural_land_gini

/* mitigate role of outliers */
foreach v in $vlist {
  flag_outliers `v', range(1 99) pct badvar(`v'_outlier)
  replace `v' = . if `v'_outlier
  drop `v'_outlier
}

/* create standardized versions of regression variables, and create the standardized variable list */
global std_varlist
foreach v in $reg_varlist {
  sum `v'
  gen `v'_std = (`v' - `r(mean)') / `r(sd)'
  global std_varlist $std_varlist `v'_std
}

/* rescale city origin year so coef is interpretable (and not 0.000) */
replace city_origin_year = city_origin_year / 100

save $tmp/seg_correlates_analysis, replace
/* ---------------------------- cell: binscatters ---------------------------- */
if "$skip_bins" != "1" {
  use $tmp/seg_correlates_analysis, clear
  
  /* binscatter everything against everything */
  graph drop _all
  
  /* label variables */
  la var city_pop_pc11 "City Population"
  la var ln_city_pop "(Log) City Population"
  la var ln_growth "City Population Growth Rate"
  la var muslim_pop_share "City Muslim Population Share"
  la var sc_pop_share "City Scheduled Caste Population Share"
  la var city_origin_year "City Origin Year"
  la var p25 "City Upward Mobility"
  la var any_event "Any Violent Event"
  la var event_count "Number of Hindu-Muslim Riots 1950-1995"
  la var town_cons_gini "City Consumption Gini"
  la var rural_land_gini "District Rural Land Gini"
  la var ed_yrs "City Mean Years of Education"
  la var ln_cons_pc "Log City Mean Per Capita Consumption"
  la var cons_pc "City Per Capita Consumption"
  la var sc_ed_gap "SC Education Gap"
  la var muslim_ed_gap "Muslim Education Gap"
  la var muslim_job_share "City Muslim Job Share"
  la var sc_job_share "City Scheduled Caste Job Share"
  la var log_area_pc11 "City Surface Area"

  la var city_dissim_muslim "Muslim Dissimilarity"
  la var city_iso_muslim "Muslim Isolation"
  la var city_dissim_sc "SC Dissimilarity"
  la var city_iso_sc "SC Isolation"
  /* CORRELATES TABLE 2: bivariate binscatters of ed_yrs, ln_city_pop, muslim/sc_pop_share, p25 */
  foreach v in $vlist {
    foreach group in sc muslim {
      foreach measure in iso dissim {
  
        /* make the binscatter with explicit axis labels */
        binscatter city_`measure'_`group' `v', linetype(none) xtitle("`: var label `v''", size(large)) ytitle("`: var label city_`measure'_`group''", size(large))
        graphout bin_`measure'_`group'_`v', pdf
        
      }
    }
  }
}

/* ---------------------------- cell: regressions ---------------------------- */
global f $tmp/seg_corr_estimates.csv
cap erase $f
append_to_file using $f, s("beta,se,p,n,spec,measure,group,varname") format(string) erase

use $tmp/seg_correlates_analysis, clear

/* CORRELATES TABLE 1: Multivariate correlates of segregation */
/* run a single joint regression with the best version of each concept */
foreach group in muslim sc {
  foreach measure in dissim iso {
    disp_nice "`group'-`measure'"

    /* run the joint regression */
    reg city_`measure'_`group' $reg_varlist, r
    
    /* store the joint regression estimates for a coefplot */
    foreach v in $reg_varlist {
      append_est_to_file using $f, b(`v') suffix("raw_joint,`measure',`group',`v'")
    }
    
    /* store the estimates for table generation below */
    eststo city_`measure'_`group'

    /* bivariate standardized regressions */
    foreach v in $reg_varlist {
      reg city_`measure'_`group' `v', r
      append_est_to_file using $f, b(`v') suffix("raw_bivar,`measure',`group',`v'")
    }
  }
}

/* re-scale city origin year */
replace city_origin_year = city_origin_year/ 100

/* label variables */
la var ln_city_pop "(Log) City Population"
la var ln_growth "City Growth Rate"
la var muslim_pop_share "Muslim (Share)"
la var sc_pop_share "Scheduled Castes (Share)"
la var city_origin_year "City Origin Year ('00s)"
la var ln_cons_pc "(Log) Per-capita Consumption"
la var p25 "City Upward Mobility"
la var any_event "Any Violent Event"
la var town_cons_gini "City Consumption Gini"
la var rural_land_gini "Rural Land Gini"
la var city_dissim_muslim "Muslim Dissimilarity"
la var city_iso_muslim "Muslim Isolation"
la var city_dissim_sc "SC Dissimilarity"
la var city_iso_sc "SC Isolation"
la var ed_yrs "Mean Neighborhood Education"

esttab city_dissim_muslim city_iso_muslim city_dissim_sc city_iso_sc  ///
    using $out/seg_multivar_regs.tex, replace ///
    label star(* 0.10 ** 0.05 *** 0.01) drop(_cons) ///
    scalars("N Observations") b(%9.3f) se(%9.3f) 

est clear

/* CORRELATES APP TABLE A.3: same as above but without 25 and town_cons_gini */
foreach group in muslim sc {
  foreach measure in dissim iso {
    disp_nice "`group'-`measure'"
    reg city_`measure'_`group' $short_reg_varlist, r
    eststo city_`measure'_`group'
  }
}

esttab city_dissim_muslim city_iso_muslim city_dissim_sc city_iso_sc  ///
    using $out/seg_multivar_regs_app1.tex, replace ///
    label star(* 0.10 ** 0.05 *** 0.01) drop(_cons) ///
    scalars("N Observations") b(%9.3f) se(%9.3f) 

est clear

/* standardized version of the regression to understand relative magnitudes */
/* CORRELATES APP TABLE 2: Multivariate correlates, standardized coefs */

la var ln_city_pop_std "(Log) City Population"
la var ln_growth_std "City Growth Rate"
la var muslim_pop_share_std "Muslim (Share)"
la var sc_pop_share_std "Scheduled Castes (Share)"
la var city_origin_year_std "City Origin Year"
la var ln_cons_pc_std "(Log) Per-capita Consumption"
la var p25_std "City Upward Mobility"
la var any_event_std "Any Violent Event"
la var town_cons_gini_std "City Consumption Gini"
la var rural_land_gini_std "Rural Land Gini"

foreach group in sc muslim {
  foreach measure in dissim iso {
    disp_nice "`group'-`measure'"

    /* run the joint regression */
    reg city_`measure'_`group' $std_varlist, r

    /* store the joint regression estimates */
    foreach v in $std_varlist {
      append_est_to_file using $f, b(`v') suffix("std_joint,`measure',`group',`v'")
    }
    
    /* store the joint regression for a table */
    eststo city_`measure'_`group'

    /* bivariate standardized regressions */
    foreach v in $std_varlist {
      reg city_`measure'_`group' `v', r
      append_est_to_file using $f, b(`v') suffix("std_bivar,`measure',`group',`v'")
    }
  }
}

esttab city_dissim_muslim city_iso_muslim city_dissim_sc city_iso_sc  ///
    using $out/seg_multivar_regs_app2.tex, replace ///
    label star(* 0.10 ** 0.05 *** 0.01) drop(_cons) ///
    scalars("N Observations") b(%9.3f) se(%9.3f) 

est clear

/* remove the isolation / group size estimates from the file, since they're not informative */
import delimited using $f, clear 
drop if measure == "iso" & inlist(varname, "muslim_pop_share", "sc_pop_share", "muslim_pop_share_std", "sc_pop_share_std")
export delimited using $f, replace

/* ---------------------------- cell ---------------------------- */
/* CELL: COEFPLOTS OF ESTIMATES */
shell SCODE="$scode" SDATA="$base" TMP="$tmp" OUT="$out" RAW="$raw" PYTHONPATH="$scode" "$python" "$scode/a/correlate_coefplots.py"
check_file_update_status "$out/coefplot_std_bivar.pdf"



/* ---------------------------- cell:  ---------------------------- */

/* review estimates */
import delimited using $f, clear varnames(1)

/* count the number of statistically significant entries by var */
gen vgroup = varname + "::" + group

gen direction = 1 if beta > 0
replace direction = -1 if beta < 0
gen sig = (p < 0.10) * direction

collapse (sum) sig (mean) beta, by(varname group)

sort varname group
order varname group
list, sepby(varname)

/* ---------------------------- cell ---------------------------- */


/* the most consistent correlates are:

 - origin year: younger cities are less segregated
 - population: bigger cities more segregated (esp for muslims). Survives
   - muslim pop share big effect on muslim segregation
   - SC pop share not much of an effect.
 - consumption: richer cities are less segregated (and same for education)
 - subgroup consumption:
   - richer muslims = MORE muslim segregation. Same finding for consumption gap ---
                      when muslims are further behind, they are less segregated.
   - no relationship for SCs.
   - 
 - education: more education = less segregation
 - subgroup education:
   - more educated muslims and SCs == less segregation
   - bigger muslim education gap == more muslim segregation
   - unclear effect for SCs education gap
 - violence:
   - yes, especially for Muslims. SC positive but maybe not with fixed effects.
   - remarkably, non-religious event count is barely significant.

  - high upward mobility, less segregation
  - faster growing, more segregated

**************************
One concept at a time:

Population: big cities are more segregated
Pop growth: Positive for Muslims, negative for SCs.
City age: Younger cities are less segregated for both groups.
Group shares: More SCs, weakly less dissimilarity. Non-linear for Muslims, most dissimilarity in cities with very few or very many. The latter is more important b/c of weights.
Consumption / Education: Majorly inverse with segregation. Weird if they go in together, but they shouldn't
Violence: highly correlated with Muslim, not with SC segregation.
Rural land gini: positive for SCs, no effect for Muslims.
City consumption gini: neg for SCs. More dissimilar cities have less urban inequality
P25: lowest when Muslims are segregated, a little higher when SCs are segregated.


*/
/* ---------------------------- cell ---------------------------- */

/* bivariate binscatter of group consumption vs. segregation */
use $tmp/seg_correlates_analysis, clear

foreach measure in dissim iso {
  local xtitle_dissim Dissimilarity
  local xtitle_iso Isolation
  binscatter ln_cons_pc_sc ln_cons_pc_muslim ln_cons_pc_nonscmuslim city_`measure'_muslim, linetype(none) ylabel(9.5(.2)10.8) ///
      ytitle(Log Consumption) xtitle(Muslim `xtitle_`measure'') ///
      legend(lab(1 "SC Consumption") lab(2 "Muslim Consumption") lab(3 "Non-MG Consumption") pos(5) ring(0) region(lpattern(solid) lcolor(black)))
  graphout `measure'_muslim, pdf
  
  binscatter ln_cons_pc_sc ln_cons_pc_muslim ln_cons_pc_nonscmuslim city_`measure'_sc, linetype(none) ylabel(9.5(.2)10.8) ///
      ytitle(Log Consumption) xtitle(SC `xtitle_`measure'') ///
      legend(lab(1 "SC Consumption") lab(2 "Muslim Consumption") lab(3 "Non-MG Consumption") pos(5) ring(0) region(lpattern(solid) lcolor(black)))
  graphout `measure'_sc, pdf

}
