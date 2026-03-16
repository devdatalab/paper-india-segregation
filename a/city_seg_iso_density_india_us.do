/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_citydata_urban_`nbd'.dta                */
/*   - $tmp/us/us_census_msa_dissim.dta                         */
/* OUTPUTS:                                                            */
/*   - $out/city_pop_weighted_seg_density_urban_robust_`nbd'_4000.pdf   */
/*   - $out/city_pop_weighted_iso_density_urban_robust_`nbd'_4000.pdf   */
/*   - $out/group_share_density_urban_robust_`nbd'.pdf                  */
/*   - $out/group_shares_density_urban_robust_`nbd'.pdf                 */
/* SUBCALLS:                                                           */
/*   - $scode/b/gen_us_seg_variables.do                                   */
/* GOAL:                                                               */
/*   Compare India vs US segregation/isolation densities.               */
/*                                                                     */
/* This do file creates segregation density graphs for the appendix    */
/* figures comparing US and India segregation and isolation measures.  */
/* These support the India-vs-US comparison appendix graphs.           */
/*                                                                     */
/* Data for the US Census is created $scode/b/gen_us_seg_variables.do.     */
/* All the datasets are stored in $raw/clean/us. Run this file here   */
/* before generating graphs below.                                     */
/***********************************************************************/

/**************************/
/* Create US Seg Measures */
/**************************/
qui do $scode/b/gen_us_seg_variables.do

/********************************************************************/
/* Dissimilarity India (Urban) (nbd = 200/4000) vs. US (nbd = 4000) */
/********************************************************************/
/* loop over different neighborhood sizes in India */
foreach nbd in 200 4000 {

  /* open India data */
  use $tmp/secc/segregation_citydata_urban_`nbd', clear

  /* Append US Data */
  append using  $tmp/us/us_census_msa_dissim.dta, force

  /* constrain data to be cities that have more than 100,000 people*/
  drop if city_pop_pc11 < 100000 | msa_total_pop < 100000

  /* create density plots */
  kdensity city_dissim_sc if sc_share > 0.05 [aw= city_pop_sc], nograph generate(x fx)
  kdensity city_dissim_sc if sc_share > 0.05  [aw= city_pop_sc], nograph generate(fx0) at(x)
  kdensity city_dissim_muslim if muslim_share > 0.05  [aw= city_pop_muslim], nograph generate(fx1) at(x)
  kdensity msa_dissim_us_census  if msa_black_share > 0.05 [aw= msa_black_pop], nograph generate(fx2) at(x)

  /* label vars */
  label var fx0 "SC"
  label var fx1 "Muslim"
  label var fx2 "US Black"

  /* plot */
  line fx0 fx1 fx2 x, sort ytitle(Dissimilarity Density, size(large)) graphregion(color(white)) xtitle(Dissimiliarity, size(large)) ///
      lcolor(navy cranberry black) lwidth(medthick medthick thick) lpattern(dash solid dot) ///
      legend(lab(1 "SC") lab(2 "Muslim") lab(3 "Black or African American") ring(0) pos(10) region(lwidth(thin)) region(lcolor(black)) size(medlarge)) ylab(0(1)5)

  /* export */
  graphout city_pop_weighted_seg_density_urban_robust_`nbd'_4000, pdf

  /* mean values of dissimilarity */
  sum city_dissim_sc if sc_share > 0.05 [aw= city_pop_sc]
  sum city_dissim_muslim if muslim_share > 0.05 [aw= city_pop_muslim]
  sum msa_dissim_us_census  if msa_black_share > 0.05 [aw= msa_black_pop]
}

/****************************************************************/
/* isolation india (Urban) (nbd = 200/4000) vs. US (nbd = 4000) */
/****************************************************************/
/* loop over nbd size */
foreach nbd in 200 4000 {
  /* open  data */
  use $tmp/secc/segregation_citydata_urban_`nbd', clear

  /* Append US Data */
  append using  $tmp/us/us_census_msa_dissim.dta, force

  /* constrain data to be cities that have more than 100,000 people*/
  drop if city_pop_pc11 < 100000 |  msa_total_pop < 100000

  /* create density plots */
  kdensity city_iso_sc if sc_share > 0.05 [aw= city_pop_sc], nograph generate(x fx)
  kdensity city_iso_sc if sc_share > 0.05  [aw= city_pop_sc], nograph generate(fx0) at(x)
  kdensity city_iso_muslim if muslim_share > 0.05  [aw= city_pop_muslim], nograph generate(fx1) at(x)
  kdensity msa_iso_us_census  if msa_black_share > 0.05 [aw= msa_black_pop], nograph generate(fx2) at(x)

  /* label vars */
  label var fx0 "SC"
  label var fx1 "Muslim"
  label var fx2 "US Black"

  /* plot */
  if "`nbd'" == "4000"{
  line fx0 fx1 fx2 x, sort ytitle(Isolation Density, size(large)) graphregion(color(white)) xtitle(Isolation, size(large)) ///
      lcolor(navy cranberry black) lwidth(medthick medthick thick) lpattern(dash solid dot) ///
      legend(lab(1 "SC") lab(2 "Muslim") lab(3 "Black or African American") ring(0) pos(2) region(lwidth(thin)) region(lcolor(black)) size(medlarge)) ylab(0(1)5)
  }

    if "`nbd'" == "200"{
  line fx0 fx1 fx2 x, sort ytitle(Isolation Density, size(large)) graphregion(color(white)) xtitle(Isolation, size(large)) ///
      lcolor(navy cranberry black) lwidth(medthick medthick thick) lpattern(dash solid dot) ///
      legend(lab(1 "SC") lab(2 "Muslim") lab(3 "Black or African American") ring(0) pos(10) region(lwidth(thin)) region(lcolor(black)) size(medlarge)) ylab(0(1)5)
  }
  
  /* export */
  graphout city_pop_weighted_iso_density_urban_robust_`nbd'_4000, pdf

  /* mean values of isolation */
  sum city_iso_sc if sc_share > 0.05 [aw= city_pop_sc]
  sum city_iso_muslim if muslim_share > 0.05 [aw= city_pop_muslim]
  sum msa_iso_us_census  if msa_black_share > 0.05 [aw= msa_black_pop]
}

/*************************************************/
/* Neighoborhood Share India (200) vs US (4000)  */
/*************************************************/
/* almost exact same code from $scode/a/graph_group_shares */
/* It differs from $scode/a/graph_group_shares in that it
1 100,000 people (in both US and India)
2 5% minority share (careful with dropping! don't drop <5% SC share for the Muslim graphs)
3 weighted by MG population

*/

/* Alternative India-vs-US neighborhood-share graphs (primary paper version is in $scode/a/graph_group_shares.do). */


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

/* get national black share in US */
use $tmp/us/us_tract_pop, clear

/* collapse to get national level population estimates */
collapse (sum) tract_blackonly_pop tract_total_pop_bw

/* calc. national level black pop share*/
local b_share = (tract_blackonly_pop / tract_total_pop_bw)*100

/**********************************************/
/* Create the nbd share graphs across sectors */
/**********************************************/
/* Graph The % of muslim/sc's living in binned 5% muslim/sc neighborhoods */
/* loop over nbd size for urban */
foreach nbd in 200 4000 {

  /* create a fast-loading dataset with the stuff we want */
  use $tmp/secc/segregation_blockdata_urban_`nbd', clear

  /* keep only variables needed for binned population graph */
  keep *id block_no block_pop sc muslim non* bad* hh* *pop_* muslim_share sc_share 

  save $tmp/urban_short, replace

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
  save $tmp/foo_urban, replace
  
  /* collapse muslim population and shares */
  preserve
  collapse (firstnm) tpop_m, by(mcut)
  ren mcut share
  save $tmp/tpop_m, replace
  restore

  /* collapse sc population and shares */
  preserve
  collapse (firstnm) tpop_sc, by(sccut)
  ren sccut share
  save $tmp/tpop_sc, replace
  restore

  /* combine the Muslim and SC share dataset and rescale Y to go from 0 to 100 */
  use $tmp/tpop_m, clear
  merge 1:1 share using $tmp/tpop_sc, nogen
  merge 1:1 share using $tmp/us/us_tpop_b, nogen
  drop if mi(share)
  replace tpop_m = tpop_m * 100
  replace tpop_sc = tpop_sc * 100

  /* reformat population to look good in graphs */
  format tpop* %2.0f
  
  /* nudge share so points appear in middle of bin */
  replace share = share + 2.5

  /* sector dependent positions for urban graph labels */
  local ym 11.5
  local xm 20
  local ysc 11.5
  local xsc 10
  local mgeom east
  local scgeom west
  
  /* create the figure showing the share distribution */
  scatter tpop_sc tpop_m share, xline(0(5)100, lcolor(gs13)) msymbol(O T) ///
      xline(`urban_share_m', lcolor(navy) lwidth(thin)) ///
      text(`ym' `xm' "National" ///
      "Muslim" ///
      "Share", size(small)  color(navy) placement(`mgeom')) ///
      xline(`urban_share_sc', lcolor(cranberry) lwidth(thin)) ///
      text(`ysc' `xsc' "National" ///
      "SC Share", size(small) color(cranberry)  placement(`scgeom')) ///
      xtitle("Neighborhood marginalized group share") ytitle("Percentage of group living in this neighborhood bin") ///
      legend(lab(1 "SC") lab(2 "Muslim") ring(0) pos(2) region(lwidth(thin)) region(lcolor(black)))  ///
      mcolor(cranberry navy) msize(medsmall medsmall)   ///
      ylab(0(2)12)

  graphout group_share_density_urban_robust_`nbd', pdf

  /****************************/
  /* Add US Black group share */
  /****************************/

  /* create the figure showing the share distribution for all 3 groups */
  scatter tpop_sc tpop_m tpop_b share, xline(0(5)100, lcolor(gs13)) msymbol(O T s) ///
      xline(`urban_share_m', lcolor(navy) lwidth(thin)) ///
      text(`ym' `xm' "National" ///
      "Muslim" ///
      "Share", size(small)  color(navy) placement(`mgeom')) ///
      xline(`urban_share_sc', lcolor(cranberry) lwidth(thin)) ///
      text(`ysc' `xsc' "National" ///
      "SC Share", size(small) color(cranberry)  placement(`scgeom')) ///
      xline(`b_share', lcolor(black) lwidth(thin)) ///
      text(9 20 "Black or African American Share", size(small) color(black)  placement(east)) ///
      xtitle("Neighborhood marginalized group share") ytitle("Percentage of group living in this neighborhood bin") ///
      legend(lab(1 "SC") lab(2 "Muslim") lab(3 "Black or African American") ring(0) pos(2) region(lwidth(thin)) region(lcolor(black)))  ///
      mcolor(cranberry navy black) msize(medsmall medsmall medsmall)   ///
      ylab(0(2)12)

  graphout group_shares_density_urban_robust_`nbd', pdf

}
