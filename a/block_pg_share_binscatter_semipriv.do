/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_blockdata_urban_200.dta                 */
/* OUTPUTS:                                                            */
/*   - $out/block_`pg'_by_{sc,mus}_dum_cfe_urban_200_semipriv.pdf        */
/* GOAL:                                                               */
/*   Generate binscatters of semi-private goods vs group shares.        */
/*                                                                     */
/* create binscatters for semi private goods such as electricity,       */
/* closed drains and piped water                                       */
/***********************************************************************/

/************************************************/
/* Binscatter with Dummy for Semi-Private Goods */
/************************************************/
/* Only do this for Urban areas because we don't have this for rural */

/* use data */
use $tmp/secc/segregation_blockdata_urban_200, clear

/* loop over all public goods */
foreach pg in closed_drain wat_source_home light_source_elec {

  /* labels */
  if  "`pg'" == "closed_drain" local ytitle "HH Has Closed Drains (Mean)"
  if  "`pg'" == "wat_source_home" local ytitle "HH Has Water Source at Home (Mean)"
  if  "`pg'" == "light_source_elec" local ytitle "HH Has Electricity (Mean)"

  local fe "Town"
  local upper town
  
/* prep for saving  data for the webpage */
  cap erase $out/block_`pg'_by_sc_dum_cfe_urban_200_semipriv_bindata.csv
  cap erase $out/block_`pg'_by_sc_dum_cfe_urban_200_semipriv_bindata.do
  cap erase $out/block_`pg'_by_mus_dum_cfe_urban_200_semipriv_bindata.csv
  cap erase $out/block_`pg'_by_mus_dum_cfe_urban_200_semipriv_bindata.do

  /* sc binscatter */
  binscatter `pg' sc_share , control(muslim_share log_block_pop) absorb(`upper') ///
      xtitle(SC Share, size(large)) ytitle(`ytitle', size(large) )   ///
      xlab(0(0.1)1) mcolor(navy) msymbol(O)    ///
      linetype(none) savedata($out/block_`pg'_by_sc_dum_cfe_urban_200_semipriv_bindata)
  graphout block_`pg'_by_sc_dum_cfe_urban_200_semipriv, pdf
  
  /* muslim binscatter */
  binscatter `pg'  muslim_share , control(sc_share log_block_pop) absorb(`upper')  ///
      xtitle(Muslim Share, size(large)) ytitle(`ytitle', size(large))     ///
      xlab(0(0.1)1) mcolor(cranberry) msymbol(T)  ///
      linetype(none) savedata($out/block_`pg'_by_mus_dum_cfe_urban_200_semipriv_bindata)
  graphout block_`pg'_by_mus_dum_cfe_urban_200_semipriv, pdf
}
