/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_blockdata_`loc'_200.dta                 */
/* OUTPUTS:                                                            */
/*   - $out/block_`pg'_by_{sc,mus}_log_emp_cfe_`loc'_200_priv.pdf        */
/* GOAL:                                                               */
/*   Plot log employment at private goods vs group shares.              */
/*                                                                     */
/* create binscatters for private goods dummy                          */
/***********************************************************************/

/*******************************************/
/* Binscatter with Dummy for Private Goods */
/*******************************************/
/* Loop over locs(Urban/Rural) */
foreach loc in urban rural {

  /* use data */
  use $tmp/secc/segregation_blockdata_`loc'_200, clear
  
  /* loop over all public goods */
  foreach pg in primary secondary hospital {
    
    /* labels */
    if  "`pg'" == "hospital" local ytitle "Log Employment at Health Facility"
    if  "`pg'" == "primary" local ytitle "Log Employment at Primary School"
    if  "`pg'" == "secondary" local ytitle "Log Employment at Secondary School"

    /* Create loc wise controls for town/subdistrict and labels */
    if "`loc'" == "urban" {
      local fe "Town"
      local upper town
    }
    
    if "`loc'" == "rural" {
      local fe "Subdistrict"
      local upper subdistrict
    }

    /* erase older saved data */
    cap erase $out/block_`pg'_by_sc_log_emp_cfe_`loc'_200_priv_bindata.csv
    cap erase $out/block_`pg'_by_sc_log_emp_cfe_`loc'_200_priv_bindata.do
    cap erase $out/block_`pg'_by_mus_log_emp_cfe_`loc'_200_priv_bindata.csv
    cap erase $out/block_`pg'_by_mus_log_emp_cfe_`loc'_200_priv_bindata.do
    
    /* sc binscatter */
    binscatter log_`pg'_emp_pub sc_share , control(muslim_share log_block_pop) absorb(`upper') ///
        xtitle(SC Share, size(large)) ytitle(`ytitle', size(large) )   ///
        xlab(0(0.1)1) mcolor(navy) msymbol(O)    ///
        name(block`pg'sc`loc', replace) linetype(none) savedata($out/block_`pg'_by_sc_log_emp_cfe_`loc'_200_priv_bindata)
    graphout block_`pg'_by_sc_log_emp_cfe_`loc'_200_priv, pdf
    
    /* muslim binscatter */
    binscatter log_`pg'_emp_pub  muslim_share , control(sc_share log_block_pop) absorb(`upper')  ///
        xtitle(Muslim Share, size(large)) ytitle(`ytitle', size(large))     ///
        xlab(0(0.1)1) mcolor(cranberry) msymbol(T)  ///
        name(block`pg'muslim`loc', replace) linetype(none) savedata($out/block_`pg'_by_mus_log_emp_cfe_`loc'_200_priv_bindata)
    graphout block_`pg'_by_mus_log_emp_cfe_`loc'_200_priv, pdf
  }
}
