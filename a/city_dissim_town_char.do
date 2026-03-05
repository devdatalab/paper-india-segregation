/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_citydata_urban_200.dta                  */
/* OUTPUTS:                                                            */
/*   - $out/city_age_dissim.tex                                        */
/*   - $out/city_age_iso.tex                                           */
/* GOAL:                                                               */
/*   Regress city dissimilarity/isolation on city characteristics.      */
/*                                                                     */
/* This do file creates a table of city dissimilarity regressed on city */
/* characteristics. The appendix has a version of this without Jammu   */
/* and Kashmir                                                        */
/***********************************************************************/

/* load dataset */
use $tmp/secc/segregation_citydata_urban_200, clear

/* dvidide decade by 10 */
gen city_origin_decade = city_origin_year/10

/* younger vs. older cities: regressions */
/* Columns 1--2: SC dissimilarity */
eststo clear
eststo sc1: reg city_dissim_sc city_origin_decade
estadd ysumm
eststo sc2: reg city_dissim_sc sc_share muslim_share log_city_pop_pc11 city_origin_decade 
estadd ysumm

/* Columns 3--4: Muslim dissimilarity */
eststo muslim1: reg city_dissim_muslim city_origin_decade
estadd ysumm
eststo muslim2: reg city_dissim_muslim sc_share muslim_share log_city_pop_pc11 city_origin_decade 
estadd ysumm

/* add var labels */
label var city_origin_decade "City Origin Decade"
label var log_city_pop_pc11 "City Population"
label var sc_share "SC Share"
label var muslim_share "Muslim Share"

/* produce table with these results */
estout sc1 sc2  muslim1 muslim2  using $out/city_age_dissim.tex, ///
    cells(b(star fmt(%10.3f))  se(par("(" ")")) ) stats(N r2 ymean, fmt(%10.0f %10.2f %10.2f) label("Observations" "R2" "Mean of Dependent Variable")) style(tex) replace label ///
    keep( city_origin_decade sc_share muslim_share log_city_pop_pc11) order(city_origin_decade sc_share muslim_share log_city_pop_pc11) ///
    mlabel(, none) ///
    collabels(,none) prefoot("\hline") postfoot("\hline\hline" "\end{tabular}" "}") ///
    prehead("{" "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" ///
    "\begin{tabular}{l*{5}{c}}" "\hline" "\hline") posthead("&\multicolumn{2}{c}{SC Dissimilarity}&\multicolumn{2}{c}{Muslim Dissimilarity}\\" "\hline")  


/* repeat regressions for isolation index */
/* columns 1--2: SC isolation */
eststo clear
eststo sc1_iso: reg city_iso_sc city_origin_decade
estadd ysumm
eststo sc2_iso: reg city_iso_sc sc_share muslim_share log_city_pop_pc11 city_origin_decade 
estadd ysumm

/* Columns 3--4: Muslim isolation */
eststo muslim1_iso: reg city_iso_muslim city_origin_decade
estadd ysumm
eststo muslim2_iso: reg city_iso_muslim sc_share muslim_share log_city_pop_pc11 city_origin_decade 
estadd ysumm

/* generate output table */
estout sc1_iso sc2_iso  muslim1_iso muslim2_iso  using $out/city_age_iso.tex, ///
    cells(b(star fmt(%10.3f))  se(par("(" ")")) ) stats(N r2 ymean, fmt(%10.0f %10.2f %10.2f) label("Observations" "R2" "Mean of Dependent Variable")) style(tex) replace label ///
    keep( city_origin_decade sc_share muslim_share log_city_pop_pc11) order(city_origin_decade sc_share muslim_share log_city_pop_pc11) ///
    mlabel(, none) ///
    collabels(,none) prefoot("\hline") postfoot("\hline\hline" "\end{tabular}" "}") ///
    prehead("{" "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" ///
    "\begin{tabular}{l*{5}{c}}" "\hline" "\hline") posthead("&\multicolumn{2}{c}{SC Isolation}&\multicolumn{2}{c}{Muslim Isolation}\\" "\hline")  
