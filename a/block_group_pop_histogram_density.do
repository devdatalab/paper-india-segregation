/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_blockdata_{urban,rural}_200.dta         */
/* OUTPUTS:                                                            */
/*   - $out/block_pop_hist_200.pdf                                     */
/* GOAL:                                                               */
/*   Plot urban/rural neighborhood population histograms.               */
/*                                                                     */
/* Generate overlapping Kdensities across different block groups for   */
/* rural and urban                                                     */
/***********************************************************************/

/* merge urban and rural data for binscatters and density graphs */
/* Use Urban Rural Data */
use $tmp/secc/segregation_blockdata_urban_200.dta, clear

/* Mark Dataset */
gen urban = 1

/* Save data */
save $tmp/urban_temp, replace

/* Use Urban Rural Data */
use $tmp/secc/segregation_blockdata_rural_200.dta, clear

/* Mark Dataset */
gen rural = 1

/* Append urban data */
append using $tmp/urban_temp

/* drop missing shrids. These lead to large EB groupings */
cap drop if mi(shrid)

/* create xlabel based on eb size */
if "200" == "200" {
  local xlab "0(500)2000"
  local xsc "0 2000"
  /* none of these options seem to work, just set anything above 2000 to be missing */
  replace block_pop = . if block_pop > 2000
}

if "200" == "4000" local xlab "0(1000)6000"

/* Graph histogram percentage */
twoway (hist block_pop if urban == 1, width(50) fcolor(navy%30) lcolor(none)  percent) ///
    (hist block_pop if rural == 1,  width(50) fcolor(none) lcolor(cranberry)  percent), ///
    ytitle("Percentage Of Neighborhoods", size(medlarge)) ///
    legend(order( 1 "urban" 2 "rural"  ) pos(1) ring(0) region(lpattern(solid) lwidth(thin) lcolor(black))) ///
    xlabel(`xlab') xtitle("Neighborhood Population", size(medlarge) ) 

graphout block_pop_hist_200, pdf

