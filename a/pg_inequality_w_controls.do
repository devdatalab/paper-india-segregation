/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_blockdata_urban_200.dta                 */
/* OUTPUTS:                                                            */
/*   - $out/pg_ineq_w_controls.csv                                      */
/*   - $out/pg_ineq_w_controls.tex                                      */
/* GOAL:                                                               */
/*   Estimate PG inequality regressions with consumption controls.      */
/***********************************************************************/

use $tmp/secc/segregation_blockdata_urban_200, clear

/* urban specification uses town fixed effects */
global upper town

gen c2 = cons_pcap ^ 2
gen c3 = cons_pcap ^ 3
gen ln_cons_pcap = log_cons_pcap
gen ln_c2 = ln_cons_pcap ^ 2
gen ln_c3 = ln_cons_pcap ^ 3

global f $out/pg_ineq_w_controls.csv
global output $out/pg_ineq_w_controls.tex
append_to_file using $f, s("b,se,n,p,group,yvar,spec") format(string) erase


/* rename the vars for a shorter latex template */
ren *primary* *prim*
ren *secondary* *sec*
ren *hospital* *hosp*
ren wat_source_home water
ren light_source_elec elec
ren closed_drain drain

disp_nice "Muslims"
foreach pg in prim sec hosp water elec drain {
  disp_nice "`pg'"
  if inlist("`pg'", "prim", "sec", "hosp") local yvar dum_`pg'_pub
  else local yvar `pg'
  reghdfe `yvar' muslim_share sc_share log_block_pop , absorb($upper) cluster($upper)
  store_est_tpl using $f, coef(muslim_share) name("muslim_`pg'_raw") all
  store_est_tpl using $f, coef(sc_share) name("sc_`pg'_raw") all

  reghdfe `yvar' muslim_share sc_share log_block_pop cons_pcap, absorb($upper) cluster($upper)
  store_est_tpl using $f, coef(muslim_share) name("muslim_`pg'_cons") all
  store_est_tpl using $f, coef(sc_share) name("sc_`pg'_cons") all

  /* store mean dependent variable */
  sum `yvar'
  local mean: di %5.2f `r(mean)'
  append_to_file using $f, s("mean_`pg',`mean'") format(string) 
}

table_from_tpl, t($scode/a/tpl/app_table_pg_ineq_w_controls_tpl.tex) r($f) o($output) 

