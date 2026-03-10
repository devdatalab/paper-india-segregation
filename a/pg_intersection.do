/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_blockdata_urban_200.dta                 */
/* OUTPUTS:                                                            */
/*   - $out/pg_intersection.csv                                         */
/*   - $out/pg_intersection.tex                                         */
/*   - $tmp/intersection_ests.csv                                       */
/* GOAL:                                                               */
/*   Estimate intersectional PG regressions for SC*Muslim shares.       */
/***********************************************************************/

use $tmp/secc/segregation_blockdata_urban_200, clear

/* urban specification uses town fixed effects */
global upper town

global f $out/pg_intersection.csv
global output $out/pg_intersection.tex
append_to_file using $f, s("b,se,n,p,group,yvar,spec") format(string) erase


/* rename the vars for a shorter latex template */
ren *primary* *prim*
ren *secondary* *sec*
ren *hospital* *hosp*
ren wat_source_home water
ren light_source_elec elec
ren closed_drain drain

/* generate interaction between SC and Muslim share */
gen both_share = sc_share * muslim_share

/* create bins of sc_share and muslim_share */
egen sc_cut = cut(sc_share), at(0(.1)1)
egen muslim_cut = cut(muslim_share), at(0(.1)1)
replace sc_cut = (10 * sc_cut) + 1
replace sc_cut = 10 if mi(sc_cut)
replace muslim_cut = (10 * muslim_cut) + 1
replace muslim_cut = 10 if mi(muslim_cut)

/* generate discrete cut variables for coefficient plot */
tab sc_cut, gen(sc_cut_)
tab muslim_cut, gen(muslim_cut_)

/* interact each cut with the other group's population share */
forval i = 1/10 {
  gen sc_share_m_cut_`i' = sc_share * muslim_cut_`i'
  gen muslim_share_sc_cut_`i' = muslim_share * sc_cut_`i'
}

/* prep an estimates file */
global f $tmp/intersection_ests.csv
append_to_file using $f, s("pg,group,index,b,se") format(string) erase


/* loop over all public services */
foreach pg in prim sec hosp water elec drain {

  if inlist("`pg'", "prim", "sec", "hosp") local yvar dum_`pg'_pub
  else local yvar `pg'
  
  /* does SC share get more negative as Muslim share goes up?  */
  reghdfe `pg' i.muslim_cut_* sc_share_m_cut_* log_block_pop, absorb(town) cluster(town)
  
  /* store the SC cuts */
  forval i = 1/8 {
    local b: di _b[sc_share_m_cut_`i']
    local se: di _se[sc_share_m_cut_`i']
    append_to_file using $f, s(`pg', sc_share, `i', `b', `se')
  }
  
  /* does Muslim share get more negative as SC share goes up?  */
  reghdfe `pg' i.sc_cut_* muslim_share_sc_cut_* log_block_pop, absorb(town) cluster(town)
  
  /* store the Muslims cuts up to 8. Don't do 9 and 10, because it doesn't leave meaningful SC share variation */
  forval i = 1/8 {
    local b: di _b[muslim_share_sc_cut_`i']
    local se: di _se[muslim_share_sc_cut_`i']
    append_to_file using $f, s(`pg', muslim_share, `i', `b', `se')
  }
}
cat $f

shell SCODE="$scode" SDATA="$base" TMP="$tmp" OUT="$out" RAW="$raw" PYTHONPATH="$scode" "$python" "$scode/a/pg_intersection.py"
check_file_update_status "$out/pg_interaction_coefplot_drain_sc_share.pdf"
