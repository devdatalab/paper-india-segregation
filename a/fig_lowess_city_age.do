/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_citydata_urban_200.dta                  */
/* OUTPUTS:                                                            */
/*   - $out/lowess_city_age_muslim.pdf                                  */
/*   - $out/lowess_city_age_sc.pdf                                      */
/* GOAL:                                                               */
/*   Plot lowess curves of city age effects by population size.         */
/*                                                                     */
/* Figure: lowess showing city age effect holds up at all population    */
/* sizes                                                               */
/***********************************************************************/
/* load urban data */
use $tmp/secc/segregation_citydata_urban_200, clear


/* prep the comparison vars */
cap gen ln_pop = ln(pc11_pca_tot_p)

/* schools, clinics per 100k people */
cap gen prim_pc = pc11_td_p_sch * 100000 / pc11_pca_tot_p 
cap gen mid_pc = pc11_td_m_sch * 100000 / pc11_pca_tot_p 
cap gen sec_pc = pc11_td_s_sch * 100000 / pc11_pca_tot_p 
cap gen hosp_pc = pc11_td_all_hosp * 100000 / pc11_pca_tot_p 

/* keep the sample within the 5-95 percentile so lowess doesn't
overweight small sample tails */
gen sample = inrange(ln_pop, 8.65, 11.85)

/* generate the graphs */
twoway (lowess city_dissim_muslim ln_pop if sample & city_origin_year < 1922, ytitle("Muslim Dissimilarity Index" size(medlarge)) lwidth(medthick) lcolor(cranberry)) (lowess city_dissim_muslim ln_pop if sample & city_origin_year > 1922 & !mi(city_origin_year), ytitle("Muslim Dissimilarity Index", size(medlarge)) lwidth(medthick) lpattern(dash) lcolor(navy)), ///
    legend(lab(1 "Old cities") lab(2 "New cities") ring(0) pos(5) region(lpattern(solid) lwidth(thin) lcolor(black))) xtitle("Log Population (2011)", size(medlarge)) 
graphout lowess_city_age_muslim, pdf

twoway (lowess city_dissim_sc ln_pop if sample & city_origin_year < 1922,  ytitle("SC Dissimilarity Index", size(medlarge)) lwidth(medthick) lcolor(cranberry)) (lowess city_dissim_sc ln_pop if sample & city_origin_year > 1922 & !mi(city_origin_year),  ytitle("SC Dissimilarity Index", size(medlarge)) lwidth(medthick) lpattern(dash) lcolor(navy)), ///
    legend(lab(1 "Old cities") lab(2 "New cities") ring(0) pos(5) region(lpattern(solid) lwidth(thin) lcolor(black))) xtitle("Log Population (2011)", size(medlarge))
graphout lowess_city_age_sc, pdf
