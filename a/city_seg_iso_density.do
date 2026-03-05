/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_citydata_`loc'_200.dta                  */
/* OUTPUTS:                                                            */
/*   - $out/city_pop_weighted_seg_density_`loc'_200.pdf                 */
/*   - $out/city_pop_unweighted_seg_density_`loc'_200.pdf               */
/*   - $out/city_pop_weighted_seg_density_`loc'_200.csv                 */
/* GOAL:                                                               */
/*   Plot weighted/unweighted segregation density and isolation for India. */
/*                                                                     */
/* This do file creates weighted and unweighted segregation and        */
/* isolation measures for India. The version of this that creates      */
/* isolation and segregation measures for US vs India is in            */
/* $scode/a/city_seg_density_india_us.do                                  */
/***********************************************************************/

/***************************************************/
/* Create Weighted/Unweighted segregation measures */
/***************************************************/
/* we don't loop over 4000 here since we only use the versions for 4000 created in $scode/a/city_seg_density_india_us.do */
/* loop over urban/rural partitions */
foreach loc in urban rural {

  /***************************************************/
  /* Create a graph weighted by sc/muslim_population */
  /***************************************************/

  /* use 200 data only */
  use $tmp/secc/segregation_citydata_`loc'_200, clear

  /* compute weighted density */
  kdensity city_dissim_sc [aw = city_pop_sc] , nograph generate(x fx)
  kdensity city_dissim_sc [aw = city_pop_sc], nograph generate(fx0) at(x)
  kdensity city_dissim_muslim [aw = city_pop_muslim], nograph generate(fx1) at(x)

  /* labeling */
  label var fx0 "SC"
  label var fx1 "Muslim"

  /* plot */
  line fx0 fx1 x , sort ytitle(Dissimilarity Density, size(large)) graphregion(color(white)) xtitle(Dissimiliarity, size(large)) ///
      lcolor(navy cranberry) lpattern(dash solid) lwidth(medthick) ///
      legend(ring(0) pos(1) region(lpattern(solid) lwidth(thin) lcolor(black)) size(large)) 

  /* export */
  graphout city_pop_weighted_seg_density_`loc'_200, pdf

  /* export the density function data */
  ren fx0 sc_density
  ren fx1 muslim_density
  export delimited sc_density muslim_density x using $out/city_pop_weighted_seg_density_`loc'_200.csv, replace

  /****************************/
  /* create unweighted graphs */
  /****************************/

  /* drop unnecessary variables */
  drop x sc_density muslim_density fx
  
  /* compute unweighted density */
  kdensity city_dissim_sc  , nograph generate(x fx) 
  kdensity city_dissim_sc , nograph generate(fx0) at(x)
  kdensity city_dissim_muslim , nograph generate(fx1) at(x)

  /* labeling */
  label var fx0 "SC"
  label var fx1 "Muslim"

  /* plot */
  line fx0 fx1 x , sort ytitle(Dissimilarity Density, size(large)) graphregion(color(white)) xtitle(Dissimiliarity, size(large)) ///
      lcolor(navy cranberry) lpattern(dash solid) lwidth(medthick) ///
      legend(ring(0) pos(1) region(lpattern(solid) lwidth(thin) lcolor(black)) size(large)) 

  /* export */
  graphout city_pop_unweighted_seg_density_`loc'_200, pdf

}

/***************************/
/* isolation india (Urban) */
/***************************/
/* loop over loc */
foreach loc in urban rural {
  /* open  data */
  use $tmp/secc/segregation_citydata_`loc'_200, clear


  /* Create weighted measures */
  /* create density plots */
  kdensity city_iso_sc if sc_share > 0.05 [aw= city_pop_sc], nograph generate(x fx)
  kdensity city_iso_sc if sc_share > 0.05  [aw= city_pop_sc], nograph generate(fx0) at(x)
  kdensity city_iso_muslim if muslim_share > 0.05  [aw= city_pop_muslim], nograph generate(fx1) at(x)

  /* plot */
 line fx0 fx1 x, sort ytitle(Isolation Density, size(large)) graphregion(color(white)) xtitle(Isolation, size(large)) ///
      lcolor(navy cranberry black) lwidth(medthick medthick thick) lpattern(dash solid dot) ///
      legend( size(large) lab(1 "SC") lab(2 "Muslim") lab(3 "Black or African American") ring(0) pos(2) region(lwidth(thin)) region(lcolor(black))) ylab(0(1)5)

  /* export */
  graphout city_pop_weighted_iso_density_`loc'_200, pdf

  /* export the density function data */
  ren fx0 sc_density
  ren fx1 muslim_density
  export delimited sc_density muslim_density x using $out/city_pop_weighted_iso_density_`loc'_200.csv, replace

/* mean values of isolation */
  sum city_iso_sc if sc_share > 0.05 [aw= city_pop_sc]
  sum city_iso_muslim if muslim_share > 0.05 [aw= city_pop_muslim]
  
  /* Create unweighted measures */
  /* drop variables from weighted reg above so you can recreate them */
  drop x sc_density muslim_density fx

  /* create density plots */
  kdensity city_iso_sc if sc_share > 0.05 , nograph generate(x fx)
  kdensity city_iso_sc if sc_share > 0.05  , nograph generate(fx0) at(x)
  kdensity city_iso_muslim if muslim_share > 0.05  , nograph generate(fx1) at(x)

  /* plot */
  line fx0 fx1 x, sort ytitle(Isolation Density, size(large)) graphregion(color(white)) xtitle(Isolation, size(large)) ///
      lcolor(navy cranberry black) lwidth(medthick medthick thick) lpattern(dash solid dot) ///
      legend(size(large) lab(1 "SC") lab(2 "Muslim") lab(3 "Black or African American") ring(0) pos(2) region(lwidth(thin)) region(lcolor(black))) ylab(0(1)5)

  /* export */
  graphout city_pop_unweighted_iso_density_`loc'_200, pdf

  /* mean values of isolation */
  sum city_iso_sc if sc_share > 0.05 
  sum city_iso_muslim if muslim_share > 0.05 
}
