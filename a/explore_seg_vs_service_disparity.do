/* open the block-level dataset */
use $tmp/secc/segregation_blockdata_urban_200, clear

/* pull in the city segregation measures */
merge m:1 town using $tmp/secc/segregation_citydata_urban_200, keepusing(city_dissim_sc city_dissim_muslim city_iso_sc city_iso_muslim city_pop)
keep if _merge == 3
drop _merge

/* restrict to the sample where we observe all the group sizes */
drop if mi(muslim_share) | mi(sc_share)

/* shorten some varnames */
ren closed_drain sewer
drop closed_drain*

ren light_source_elec elec
drop light_source_elec*

ren wat_source_home water
drop wat_source_home*

ren dum_primary_pub prim
ren dum_secondary_pub sec
ren dum_hospital_pub hosp

global pgs prim sec hosp sewer elec water

/* count neighborhoods in each town */
bys town: egen nbd_count = count(muslim_share)

/* calculate each group's town population in this sample */
bys town: egen muslim_total_pop = total(block_pop_muslim)
bys town: egen sc_total_pop = total(block_pop_sc)
bys town: egen fwd_total_pop = total(block_pop_nonscmuslim)
bys town: egen total_pop = total(block_pop)

/* generate teh forward population share (we already have the other two) */
gen fwd_share = fwd_total_pop / total_pop

/* loop over each public service to calculate public service measures */
foreach pg in $pgs {

  /* calculate population of each group living in a neighborhood with this service */
  bys town: egen muslim_`pg'_pop = total(block_pop_muslim * `pg')
  bys town: egen sc_`pg'_pop = total(block_pop_sc * `pg')
  bys town: egen fwd_`pg'_pop = total(block_pop_nonscmuslim * `pg')

  /* turn it into a population share */
  gen muslim_`pg'_share = muslim_`pg'_pop / muslim_total_pop
  gen sc_`pg'_share = sc_`pg'_pop / sc_total_pop
  gen fwd_`pg'_share = fwd_`pg'_pop / fwd_total_pop

  /* calculate the gap measure, such that it has the same direction as the coef above */
  gen muslim_`pg'_gap = muslim_`pg'_share - fwd_`pg'_share
  gen sc_`pg'_gap = sc_`pg'_share - fwd_`pg'_share
}

/* count the share of neighborhoods where each minority group is isolated */
gen iso_muslim = block_pop_muslim * (block_pop_muslim / block_pop > .75)
bys town: egen iso_muslim_pop = total(iso_muslim)
gen iso_muslim_share = iso_muslim_pop / muslim_total_pop
gen iso_sc = block_pop_sc * (block_pop_sc / block_pop > .75)
bys town: egen iso_sc_pop = total(iso_sc)
gen iso_sc_share = iso_sc_pop / sc_total_pop

save $tmp/pre_collapse, replace

sum $pgs


/* ---------------------------- cell ---------------------------- */

use $tmp/pre_collapse, clear

/* replicate the secondary school service inequality result */
reg prim muslim_share sc_share block_pop, absorb(town)

tag town
global f $tmp/pg_by_seg_ests.csv
append_to_file using $f, s("pg,measure,group,quartile,beta,se") format(string) erase

/* loop over each social group */
foreach group in sc muslim {

  /* identify the other group in this loop iteration */
  if "`group'" == "sc"     local other_group muslim
  if "`group'" == "muslim" local other_group sc
  
  /* loop over each measure */
  foreach measure in iso dissim {
  
    /* calculate quartile bins for this segregation measure */
    sum city_`measure'_`group' if ttag, d
    local q1 "0, `r(p25)'"
    local q2 "`r(p25)', `r(p50)'"
    local q3 "`r(p50)', `r(p75)'"
    local q4 "`r(p75)', 1"
    
    /* loop over eaach public service */
    foreach pg in prim sec hosp water sewer elec {
    
      /* store the neighborhood disparity coef in this quartile of segregation */
      forval q = 1/4 {
        reg `pg' `group'_share `other_group'_share block_pop if inrange(city_`measure'_`group', `q`q''), absorb(town)
        local beta: di _b["`group'_share"]
        local se: di _se["`group'_share"]
        append_to_file using $f, s("`pg',`measure',`group',`q',`beta',`se'") format(string) 
      }
    }
  }
}

/* ---------------------------- cell ---------------------------- */

/* review the results */
import delimited using $f, clear varnames(1)

/* try rescaling by mean value of the public service */
replace beta = beta  /   .067027    if pg == "prim"
replace beta = beta  /  .0235854    if pg == "sec"
replace beta = beta  /  .0222585    if pg == "hosp"
replace beta = beta  /  .5580075    if pg == "sewer"
replace beta = beta  /  .9507189    if pg == "elec"
replace beta = beta  /  .7315732    if pg == "water"
replace se = se  /   .067027    if pg == "prim"
replace se = se  /  .0235854    if pg == "sec"
replace se = se  /  .0222585    if pg == "hosp"
replace se = se  /  .5580075    if pg == "sewer"
replace se = se  /  .9507189    if pg == "elec"
replace se = se  /  .7315732    if pg == "water"

gen b_low  = beta - 1.96 * se
gen b_high = beta + 1.96 * se

/* create vars to set public service ordering */
gen o = .
replace o = 1 if pg == "prim"
replace o = 2 if pg == "sec"
replace o = 3 if pg == "hosp"
replace o = 4 if pg == "sewer"
replace o = 5 if pg == "elec"
replace o = 6 if pg == "water"

/* create x index values for quick coefplot */
sort measure group o quartile
capdrop x_index
gen x_index = int((_n-1) / 4) * 10 + quartile

list in 1/20, sepby(pg)

/* make four coefplots */
foreach group in muslim sc {
  foreach seg in iso dissim {
    twoway ///
        (rcap b_low b_high x_index if group == "`group'" & measure == "`seg'") ///
        (scatter beta x_index  if group == "`group'" & measure == "`seg'"), ///
        xtitle("Public services by quartile: prim sec hosp water sewer elec") ///
        ytitle("`group' neighborhood coefficient") yline(0)
    graphout pg_seg_`group'_`seg', pdf
  }
}

/* save for python */
save $tmp/pg_by_seg, replace

/* generate the coefplot in python */
shell SCODE="$scode" SDATA="$base" TMP="$tmp" OUT="$out" PYTHONPATH="$scode" "$python" "$scode/a/graph_seg_vs_pg.py"
check_file_update_status "$out/quartiles_muslim_iso.pdf"
