/* ---------------------------- cell:  ---------------------------- */

import delimited using $seg/comparisons/seg_comparisons_d.csv, clear varnames(1)

/* keep the entries marked to keep in the sheet */
keep if include == 1

/* rename variables to match the india segregation data */
ren neighborhoodblocksize mean_pop
ren value dissim
keep year mean_pop dissim graph_desc
save $tmp/seg_compare_dissim, replace

/* ---------------------------- cell:  ---------------------------- */

import delimited using $seg/comparisons/seg_comparisons_i_raw.csv, clear varnames(1)

/* keep the entries marked to keep in the sheet */
keep if include == 1

/* rename variables to match the india segregation data */
ren neighborhoodblocksize mean_pop
ren value iso
keep year mean_pop iso graph_desc
save $tmp/seg_compare_iso, replace

/****************************/
/* DISSIMILARITY COMPARISON */
/****************************/

/* open india dataset with Muslim and SC dissimilarity measures at different agg levels */
use $tmp/dissim_iso_block_groups, clear

/* use non-rescaled isolation measures */
drop *_rescaled

drop if block_group == 0
ren mean_sc_dissim dissimsc
ren mean_muslim_dissim dissimmuslim
ren mean_sc_iso isosc
ren mean_muslim_iso isomuslim

/* reshape it so Muslim and SCs segregation are in different rows */
reshape long dissim iso, j(group) i(mean_pop sector) string

/* add classification fields to match the international data */
gen year = 2012
gen india = 1

/* append the international data */
append using $tmp/seg_compare_dissim
replace india = 0 if mi(india)

/* manually nudge some marker labels */
gen vpos = 3
replace vpos = 9 if strpos(graph_desc, "Brazil") | strpos(graph_desc, "Spain")
replace vpos = 5 if strpos(graph_desc, "4137")

/* clean up the US label */
/* plot the results */
twoway ///
    (connected dissim mean_pop if india == 1 & group == "muslim", msymbol(X) msize(medium) color(red)) ///
    (connected dissim mean_pop if india == 1 & group == "sc",     lpattern(-) msymbol(Oh) msize(medium) color(blue)) ///    
    (scatter dissim mean_pop if india == 0, mlabvpos(vpos)    mlabel(graph_desc) mlabcolor(black) msize(small) color(black)) ///
    , legend(region(style(none) lcolor(black) lwidth(medium)) lcolor(black) lwidth(medium) ring(0) pos(11) lab(1 "Muslim") lab(2 "SC") order(1 2)) xtitle("Block Size (population)") ytitle("Dissimilarity Index")
graphout seg_compare_dissim, pdf

/************************/
/* ISOLATION COMPARISON */
/************************/

/* append the international data */
append using $tmp/seg_compare_iso
replace india = 0 if mi(india)

/* manually nudge overlapping marker labels */
gen vpos_iso = 3
replace vpos_iso = 2 if strpos(graph_desc, "4137 cities")
replace vpos_iso = 4 if strpos(graph_desc, "384 cities")

/* plot the results */
twoway ///
    (connected iso mean_pop if india == 1 & group == "muslim", msymbol(X) msize(medium) color(red)) ///
    (connected iso mean_pop if india == 1 & group == "sc",     lpattern(-) msymbol(Oh) msize(medium) color(blue)) ///    
    (scatter iso mean_pop if india == 0,   mlabel(graph_desc) mlabvpos(vpos_iso) mlabgap(2) mlabcolor(black) msize(small) color(black)) ///
    , legend(region(style(none) lcolor(black) lwidth(medium)) lcolor(black) lwidth(medium) ring(0) pos(11) lab(1 "Muslim") lab(2 "SC") order(1 2)) xtitle("Block Size (population)") ytitle("Isolation Index")
graphout seg_compare_iso, pdf
