/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/city_seg_district_rural_urban_`bgroup'.dta          */
/* OUTPUTS:                                                            */
/*   - $out/bin_seg_sc_urban_rural_corr_`bgroup'.pdf                    */
/*   - $out/bin_seg_muslim_urban_rural_corr_`bgroup'.pdf                */
/*   - $out/bin_iso_sc_urban_rural_corr_`bgroup'.pdf                    */
/*   - $out/bin_iso_muslim_urban_rural_corr_`bgroup'.pdf                */
/* GOAL:                                                               */
/*   Plot district-level urban-rural dissimilarity/isolation correlations. */
/*                                                                     */
/* create binscatters showing the district-level correlation           */
/* between urban and rural dissimilarity                               */
/*                                                                     */
/* data for this figure is created in                                  */
/* $scode/b/gen_district_correlates_urban_rural.do                         */
/***********************************************************************/

/***********/
/* Figures */
/***********/
/* loop over neighborhood size */
foreach bgroup in 200 {

  /* load district-level data */
  use $tmp/city_seg_district_rural_urban_`bgroup', clear

  /* calculate corr coefficient */
  corr city_dissim_sc_u city_dissim_sc_r
  local rho_dissim_sc: di %5.2f `r(rho)'

  /* calculate muslim coeff */
  corr city_dissim_muslim_u city_dissim_muslim_r
  local rho_dissim_muslim: di %5.2f `r(rho)'

  /* graph binscatters */
  /* graph sc urban vs rural binscatter */
  binscatter city_dissim_sc_u city_dissim_sc_r,  ///
      xtitle(SC Dissimilarity: Rural, size(large)) ytitle(SC Dissimilarity: Urban, size(large))  xsca(titlegap(2)) ///
      xlab(0.2(0.1)1) ylab(0.2(0.1)1) linetype(none)  ///
      msymbol(O) mcolor(navy) ///
      note("{&rho} = `rho_dissim_sc'", color(black) ring(0) pos(1) size(large) box lcolor(black) lwidth(thin) lpattern(solid) justification(center) alignment(middle) fcolor(white))

  graphout bin_seg_sc_urban_rural_corr_`bgroup', pdf
  
  
  /* graph muslim urban vs rural binscatter */
  binscatter city_dissim_muslim_u city_dissim_muslim_r, ///
      xtitle(Muslim Dissimilarity: Rural, size(large)) ytitle(Muslim Dissimilarity: Urban, size(large)) xsca(titlegap(2)) ///
      xlab(0.2(0.1)1) ylab(0.2(0.1)1) linetype(none) ///
      msymbol(T) mcolor(cranberry) ///
      note("{&rho} = `rho_dissim_muslim'", color(black) ring(0) pos(1) size(large)box lcolor(black) lwidth(thin) lpattern(solid) justification(center) alignment(middle) fcolor(white))
  graphout bin_seg_muslim_urban_rural_corr_`bgroup', pdf


  /* repeat for isolation */
  /* calculate corr coefficient */
  corr city_iso_sc_u city_iso_sc_r
  local rho_iso_sc: di %5.2f `r(rho)'

  /* calculate muslim coeff */
  corr city_iso_muslim_u city_iso_muslim_r
  local rho_iso_muslim: di %5.2f `r(rho)'

  /* graph binscatters */
  /* graph sc urban vs rural binscatter */
  binscatter city_iso_sc_u city_iso_sc_r,  ///
      xtitle(SC Isolation: Rural, size(large)) ytitle(SC Isolation: Urban, size(large))  xsca(titlegap(2)) ///
      xlab(0(0.1)1) ylab(0(0.1)1) linetype(none)  ///
      msymbol(O) mcolor(navy) ///
      note("{&rho} = `rho_iso_sc'", color(black) ring(0) pos(1) size(large) box lcolor(black) lwidth(thin) lpattern(solid) justification(center) alignment(middle) fcolor(white))

  graphout bin_iso_sc_urban_rural_corr_`bgroup', pdf
  
  
  /* graph muslim urban vs rural binscatter */
  binscatter city_iso_muslim_u city_iso_muslim_r, ///
      xtitle(Muslim Isolation: Rural, size(large)) ytitle(Muslim Isolation: Urban, size(large)) xsca(titlegap(2)) ///
      xlab(0(0.1)1) ylab(0(0.1)1) linetype(none) ///
      msymbol(T) mcolor(cranberry) ///
      note("{&rho} = `rho_iso_muslim'", color(black) ring(0) pos(1) size(large)box lcolor(black) lwidth(thin) lpattern(solid) justification(center) alignment(middle) fcolor(white))
  graphout bin_iso_muslim_urban_rural_corr_`bgroup', pdf
  
 
}

