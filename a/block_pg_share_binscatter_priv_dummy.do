/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_blockdata_`loc'_200.dta                 */
/* OUTPUTS:                                                            */
/*   - $out/block_`pg'_by_{sc,mus}_dum_cfe_`loc'_200_priv.pdf            */
/* GOAL:                                                               */
/*   Generate binscatters of private-goods access vs group shares.      */
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
    if  "`pg'" == "hospital" local ytitle "Indicator For any Health Facility"
    if  "`pg'" == "primary" local ytitle "Indicator For any Primary School"
    if  "`pg'" == "secondary" local ytitle "Indicator For any Secondary School"

    /* Create loc wise controls for town/subdistrict and labels */
    if "`loc'" == "urban" {
      local fe "Town"
      local upper town
    }
    
    if "`loc'" == "rural" {
      local fe "Subdistrict"
      local upper subdistrict
    }

    /* sc binscatter */
    cap erase $out/block_`pg'_by_sc_dum_cfe_`loc'_200_priv_bindata.csv
    cap erase $out/block_`pg'_by_sc_dum_cfe_`loc'_200_priv_bindata.do
    cap erase $out/block_`pg'_by_mus_dum_cfe_`loc'_200_priv_bindata.csv
    cap erase $out/block_`pg'_by_mus_dum_cfe_`loc'_200_priv_bindata.do
    binscatter dum_`pg'_priv sc_share , control(muslim_share log_block_pop) absorb(`upper') ///
        xtitle(SC Share, size(large)) ytitle(`ytitle', size(large) )   ///
        xlab(0(0.1)1) mcolor(navy) msymbol(O)    ///
        name(block`pg'sc`loc', replace) linetype(none) savedata($out/block_`pg'_by_sc_dum_cfe_`loc'_200_priv_bindata)
    graphout block_`pg'_by_sc_dum_cfe_`loc'_200_priv, pdf
    
    /* muslim binscatter */
    binscatter dum_`pg'_priv  muslim_share , control(sc_share log_block_pop) absorb(`upper')  ///
        xtitle(Muslim Share, size(large)) ytitle(`ytitle', size(large))     ///
        xlab(0(0.1)1) mcolor(cranberry) msymbol(T)  ///
        name(block`pg'muslim`loc', replace) linetype(none) savedata($out/block_`pg'_by_mus_dum_cfe_`loc'_200_priv_bindata)
    graphout block_`pg'_by_mus_dum_cfe_`loc'_200_priv, pdf
  }
}
