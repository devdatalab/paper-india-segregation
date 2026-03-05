/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_blockdata_urban_200.dta                 */
/* OUTPUTS:                                                            */
/*   - $out/nbd_pg_slum_200.tex                                         */
/* GOAL:                                                               */
/*   Estimate PG regressions with slum controls for appendix.           */
/*                                                                     */
/* Overflow Appendix Table: Slum                                       */
/***********************************************************************/
/* loop over block group sizes */
/* load block data */
use $tmp/secc/segregation_blockdata_urban_200, clear

/* label vars  */
/* set labels explicitly for table output */
label var sc_share "SC Share"
label var muslim_share "Muslim Share"

/* loop over slum variations */
foreach slum in slum_cont all_slum no_slum {
  
  /* create slum modifier */
  if "`slum'" == "slum_cont" local slum_mod slum
  if "`slum'" == "no_slum" local slum_mod "if slum == 0"
  
  /* town over public goods dummy */
  foreach pg in primary secondary hospital {
    eststo `pg'_`slum': areg dum_`pg'_pub sc_share muslim_share log_block_pop `slum_mod' , absorb(town) r
    estadd ysumm
  }
}


/* print one with slum as a control and no slums */
estout primary_slum_cont secondary_slum_cont hospital_slum_cont primary_no_slum secondary_no_slum hospital_no_slum using $out/nbd_pg_slum_200.tex, ///
    cells(b(fmt(%4.3f) star) se) stats(N ymean, fmt(%10.0f %4.3f) labels("Observations" "R^2" "Mean of Dependent Variable")) style(tex) replace label ///
    keep(sc_share muslim_share) order(sc_share muslim_share) ///
    mlabel("Primary School" "Secondary School" "Health Facility" "Primary School" "Secondary School" "Health Facility") collabels(,none) prehead("{" "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" "\begin{tabular}{l*{7}{c}}" "\hline" "\hline" " &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}&\multicolumn{1}{c}{(5)}&\multicolumn{1}{c}{(6)} \\" "&\multicolumn{3}{c}{Slum Controls}&\multicolumn{3}{c}{No Slum}\\" "\cmidrule(lr){2-4} \cmidrule(lr){5-7}") ///
    posthead("\hline") prefoot("\hline") postfoot("Town FE & Yes & Yes & Yes & Yes & Yes & Yes \\" "\hline" "\hline" "\end{tabular}" "}")

// billy write $out/nbd_pg_slum_200.tex
