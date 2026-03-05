/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_citydata_`loc'_200.dta                  */
/* OUTPUTS:                                                            */
/*   - $out/city_share_muslim_pc_classify_`loc'.pdf                     */
/*   - $out/city_share_muslim_pc_classify_`loc'_nofe.pdf                */
/* GOAL:                                                               */
/*   Compare LSTM Muslim shares to PC11 shares with/without FE.         */
/*                                                                     */
/* Regression on muslim classification on PC shares                    */
/***********************************************************************/

/* loop over locs */
foreach loc in urban rural {

  use $tmp/secc/segregation_citydata_`loc'_200, clear

  /* regress to get r2 */
  reg muslim_share muslim_share_pc11 [aw=city_pop_pc11]

  /* plot */

  /* with FE */
  binscatter muslim_share muslim_share_pc11 [aw=city_pop_pc11] , absorb(pc11_state_id) xtitle("Muslim Share (Population Census 2011)", size(medlarge)) ///
      ytitle("Muslim Share (LSTM Classification)", size(medlarge)) caption("Includes State FE", size(medium)) ///
      mcolor(cranberry) msymbol(T) ///
      xlab(0(0.2)1) ylab(0(0.2)1)
  graphout city_share_muslim_pc_classify_`loc', pdf

  /* without FE */
  binscatter muslim_share muslim_share_pc11  [aw=city_pop_pc11]  , xtitle("Muslim Share (Population Census 2011)", size(medlarge)) ///
      ytitle("Muslim Share (LSTM Classification)", size(medlarge))  ///
      xlab(0(0.2)1) ylab(0(0.2)1) ///
      mcolor(cranberry) msymbol(T)      
  
  graphout city_share_muslim_pc_classify_`loc'_nofe, pdf 
}
