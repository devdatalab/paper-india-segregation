/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_blockdata_`loc'_200.dta                 */
/*   - $raw/clean/pc11/pc11{r_subdistrict,u_town}_social_group.dta    */
/* OUTPUTS:                                                            */
/*   - $out/group_share_density_`loc'.pdf                               */
/*   - $out/group_shares_density_`loc'.pdf                              */
/* GOAL:                                                               */
/*   Plot distributions of group shares across neighborhoods.           */
/*                                                                     */
/* This do file graphs the share of each group living in same-group     */
/* neighborhoods arranged by neighborhood share. Figure 1 uses the      */
/* main density outputs from this file.                                 */
/***********************************************************************/

/********************************************************************************************/
/* program calc_mean_median_nbd_shares: Calculate the mean and median neighborhood shares   */
/********************************************************************************************/
cap prog drop calc_mean_median_nbd_shares
prog def calc_mean_median_nbd_shares, rclass
  
  syntax, loc(string) group(string)

  use $tmp/secc/segregation_blockdata_`loc'_200, clear

  /* calculate the average neighborhood share of the average person in the social group */
  sum `group'_share [aw=`group'_share]
  local mean_group_share: di %5.2f `r(mean)' * 100
  return local mean_group_share = `mean_group_share'
  
  /* generate a cumulative count of social group members */
  sort `group'_share
  gen `group'_count_cum = sum(block_pop_`group')
  
  /* identify the median person in the social group */
  sum `group'_count_cum
  local group_count = `r(max)'
  local median_group = round(`group_count') / 2
  
  /* find the neighborhood closest to the median person in the social group */
  gen dist = abs(`median_group' - `group'_count_cum)
  sum dist
  gen median_nbd = dist == `r(min)'
  sum `group'_share if median_nbd == 1
  local median_group_share: di %5.2f `r(mean)' * 100
  return local median_group_share = `median_group_share'

end
/** END program calc_mean_median_nbd_shares *************************************************/

/*********************************************/
/* Save Locals for Displaying on Graph Later */
/*********************************************/
/* Get national muslim & sc share */
foreach d in r_subdistrict u_town {
  
  use $raw/clean/pc11/pc11`d'_social_group, clear

  collapse (sum) pc11_tot_p pc11_p_muslim 
  if "`d'" == "r_subdistrict" local s rural
  if "`d'" == "u_town" local s urban

  /* store value for national muslim share in local to use in scatter plot */
  local `s'_share_m = (pc11_p_muslim/pc11_tot_p)*100

  /* sanity check  values */
  di ``s'_share_m'
  
}

foreach d in u r {
  use $raw/clean/pc11/pc11`d'_pca_clean, clear
  collapse (sum) pc11_pca_tot_p pc11_pca_p_sc
  if "`d'" == "r" local s rural
  if "`d'" == "u" local s urban
  local `s'_share_sc = (pc11_pca_p_sc/pc11_pca_tot_p)*100

  di ``s'_share_sc'
}

/* ---------------------------- cell:  ---------------------------- */

/* get national black share in US */
use $tmp/us/us_tract_pop, clear

/* collapse to get national level population estimates */
collapse (sum) tract_blackonly_pop tract_total_pop_bw

/* calc. national level black pop share*/
local b_share = (tract_blackonly_pop / tract_total_pop_bw)*100

/************************************/
/* Create the graphs across locs */
/************************************/

/* Graph The % of muslim/sc's living in binned 5% muslim/sc neighborhoods */
/* loop over loc */
foreach loc in urban rural {

  /* create a fast-loading dataset with the stuff we want */
  use $tmp/secc/segregation_blockdata_`loc'_200, clear

  /* keep only variables needed for binned population graph */
  keep *id block_no block_pop sc muslim non* bad* hh* *pop_* muslim_share sc_share 

  save $tmp/`loc'_short, replace

  /* drop if muslim/sc shares > 1 */
  drop if muslim_share > 1 | sc_share > 1
  
  /**********************************************************************************/
  /* calculate muslim population living in each 5 percentage point muslim share bin */
  /**********************************************************************************/
  /* generate 5% cuts on muslim_share in neighborhoods */
  egen mcut = cut(muslim_share), at(0(.05)1)

  /* cap muslim share at 95% (because the top bin is 95-100, not 100-100)  */
  replace mcut = .95 if muslim_share == 1

  /* get absolute/total population within each 5% cut of muslim share in neighborhoods  */
  bys mcut: egen tpop_m = total(muslim)

  /* get % of total muslim population living within 5% cuts of muslim share */
  sum muslim
  replace tpop_m = tpop_m / (`r(mean)' * `r(N)')

  /* round cuts of muslim share */
  replace mcut = round(mcut * 100)

  /**********************************************************************************/
  /* calculate sc population living in each 5 percentage point sc share bin */
  /**********************************************************************************/

  /* generate 5% cuts on sc_share in neighborhoods */
  egen sccut = cut(sc_share), at(0(.05)1)

  /* cap sc share at 95% */
  replace sccut = .95 if sc_share == 1

  /* get absolute/total population within each 5% cut of sc share in neighborhoods  */
  bys sccut: egen tpop_sc = total(sc)

  /* get % of total sc population living within 5% cuts of sc share */
  sum sc
  replace tpop_sc = tpop_sc / (`r(mean)' * `r(N)')

  /* round cuts of sc share */
  replace sccut = round(sccut * 100)

  /* separately collapse and remerge these datasets, so we can merge
  them on shares (which represent different places for low/high Muslim
  and SC shares */
  save $tmp/foo_`loc', replace
  
  /* collapse muslim population and shares */
  preserve
  collapse (firstnm) tpop_m, by(mcut)
  ren mcut share
  save $tmp/tpop_m_`loc', replace
  restore

  /* collapse sc population and shares */
  preserve
  collapse (firstnm) tpop_sc, by(sccut)
  ren sccut share
  save $tmp/tpop_sc_`loc', replace
  restore

  /* combine the Muslim and SC share dataset and rescale Y to go from 0 to 100 */
  use $tmp/tpop_m_`loc', clear
  merge 1:1 share using $tmp/tpop_sc_`loc', nogen
  merge 1:1 share using $tmp/us/us_tpop_b, nogen
  drop if mi(share)
  replace tpop_m = tpop_m * 100
  replace tpop_sc = tpop_sc * 100

  /* reformat population to look good in graphs */
  format tpop* %2.0f
  
  /* nudge share so points appear in middle of bin */
  replace share = share + 2.5

  /* loc dependent positions for urban graph labels */
  if "`loc'" == "urban" local ym 11.5
  if "`loc'" == "urban" local xm 20
  if "`loc'" == "urban" local ysc 11.5
  if "`loc'" == "urban" local xsc 10
  if "`loc'" == "urban" local mgeom east
  if "`loc'" == "urban" local scgeom west
  
  if "`loc'" == "rural" local ym 11.5
  if "`loc'" == "rural" local xm 12
  if "`loc'" == "rural" local ysc 11.5
  if "`loc'" == "rural" local xsc 20
  if "`loc'" == "rural" local mgeom west
  if "`loc'" == "rural" local scgeom east    

  /* create the figure showing the share distribution */
  scatter tpop_sc tpop_m share, xline(0(5)100, lcolor(gs13)) msymbol(O T) ///
      xline(``loc'_share_m', lcolor(cranberry) lwidth(thin)) ///
      text(`ym' `xm' "National" ///
      "Muslim" ///
      "Share", size(small)  color(cranberry) placement(`mgeom')) ///
      xline(``loc'_share_sc', lcolor(navy) lwidth(thin)) ///
      text(`ysc' `xsc' "National" ///
      "SC Share", size(small) color(navy)  placement(`scgeom')) ///
      xtitle("Neighborhood marginalized group share", size(large)) ytitle("Percentage of group" "living in this neighborhood bin", size(large)) ///
      legend(lab(1 "SC") lab(2 "Muslim") ring(0) pos(2) region(lwidth(thin)) region(lcolor(black)) size(large))  ///
      mcolor(navy cranberry) msize(medsmall medsmall)   ///
      ylab(0(2)12)

  graphout group_share_density_`loc', pdf

  /****************************/
  /* Add US Black group share */
  /****************************/

  /* create the figure showing the share distribution for all 3 groups */
  scatter tpop_sc tpop_m tpop_b share, xline(0(5)100, lcolor(gs13)) msymbol(O T s) ///
      xline(``loc'_share_m', lcolor(cranberry) lwidth(thin)) ///
      text(`ym' `xm' "National" ///
      "Muslim" ///
      "Share", size(small)  color(cranberry) placement(`mgeom')) ///
      xline(``loc'_share_sc', lcolor(navy) lwidth(thin)) ///
      text(`ysc' `xsc' "National" ///
      "SC Share", size(small) color(navy)  placement(`scgeom')) ///
      xline(`b_share', lcolor(black) lwidth(thin)) ///
      text(9 20 "Black or African American Share", size(small) color(black)  placement(east)) ///
      xtitle("Neighborhood marginalized group share") ytitle("Percentage of group" "living in this neighborhood bin") ///
      legend(lab(1 "SC") lab(2 "Muslim") lab(3 "Black or African American") ring(0) pos(2) region(lwidth(thin)) region(lcolor(black)))  ///
      mcolor(navy cranberry black) msize(medsmall medsmall medsmall)   ///
      ylab(0(2)12)

  graphout group_shares_density_`loc', pdf
}

/*****************************************************************************/
/* calculate number of muslims and scs living in >80% minority neighborhoods */
/*****************************************************************************/
/* muslims */
use $tmp/tpop_m_urban, clear
sum tpop_m if share >= 80
di `r(mean)' * `r(N)'

/* SCs */
use $tmp/tpop_sc_urban, clear
sum tpop_sc if share >= 80
di `r(mean)' * `r(N)'

/****************************************************************************************/
/* order neighborhoods by muslim share, calculate the muslim_share of the median muslim */
/****************************************************************************************/
foreach loc in rural urban {
  foreach group in sc muslim {
    qui calc_mean_median_nbd_shares, loc(`loc') group(`group')
    disp_nice "`loc'-`group'"
    return list
  }
}
