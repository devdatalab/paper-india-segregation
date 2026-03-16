/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_blockdata_`loc'_`bgroup'.dta            */
/* OUTPUTS:                                                            */
/*   - $out/block_`pg'_by_{sc,mus}_dum_cfe_`loc'_`bgroup'_pub.pdf        */
/*   - $out/binscatter_viz_sc.csv                                      */
/*   - $out/binscatter_viz_muslim.csv                                  */
/* GOAL:                                                               */
/*   Generate binscatters of public-goods access vs group shares.       */
/*                                                                     */
/* create binscatters for public and private goods dummies             */
/***********************************************************************/

/******************************************/
/* Binscatter with Dummy for Public Goods */
/******************************************/
/* loop over block groups */
foreach bgroup in 200 4000 {

  /* Loop over locs(Urban/Rural) */
  foreach loc in urban rural {
    
    /* use data */
    use $tmp/secc/segregation_blockdata_`loc'_`bgroup', clear
    
    /* loop over all public goods */
    foreach pg in primary secondary hospital {
      
      /* labels */
      if  "`pg'" == "hospital" local ytitle "Indicator For any Health Facility"
      if  "`pg'" == "primary" local ytitle "Indicator For any Primary School"
      if  "`pg'" == "secondary" local ytitle "Indicator For any Secondary School"
      
      if inlist("`pg'", "hospital", "hospital_861", "hospital_862" "hospital_other") &  "`loc'" == "urban" {
        local title "Health Facility (Urban)"
        if "`bgroup'" == "200" local ylab "0.01(0.004)0.03"
        if "`bgroup'" == "4000" local ylab "0.12(0.01)0.16"
      }
      
      if inlist("`pg'", "hospital", "hospital_861", "hospital_862" "hospital_other")  & "`loc'" == "rural" {
        local title "Health Facility (Rural)"
        if "`bgroup'" == "200" local ylab "0.04(0.005)0.06"
        if "`bgroup'" == "4000" local ylab "0.1(0.005)0.125"        
      }
      
      if "`pg'" == "primary" & "`loc'" == "urban" {
        local title "Primary School (Urban)"
        if "`bgroup'" == "200" local ylab "0.06(0.005)0.08"
        if "`bgroup'" == "4000" local ylab "0.28(0.02)0.36"
      }

      if "`pg'" == "primary" & "`loc'" == "rural" {
        local title "Primary School (Rural)"
        if "`bgroup'" == "200" local ylab "0.25(0.025)0.35"
        if "`bgroup'" == "4000" local ylab "0.54(0.005)0.57"
      }
      
      if  "`pg'" == "secondary" & "`loc'" == "urban" {
        local title "Secondary School (Urban)"
        if "`bgroup'" == "200" local ylab "0.014(0.002)0.026"
        if "`bgroup'" == "4000" local ylab "0.12(0.01)0.17"
      }
      
      if  "`pg'" == "secondary" & "`loc'" == "rural" {
        local title "Secondary School (Rural)"
        if "`bgroup'" == "200" local ylab "0.055(0.005)0.075"
        if "`bgroup'" == "4000" local ylab "0.12(0.01)0.16"        
      }
      

      /* Create loc wise controls for town/subdistrict and labels */
      if "`loc'" == "urban" {
        local fe "Town"
        local upper town
      }
        
      if "`loc'" == "rural" {
        local fe "Subdistrict"
        local upper subdistrict
      }

      
      /* public-goods dummy binscatters for education and health outcomes */
      /* sc binscatter */
      cap erase $out/block_`pg'_by_sc_dum_cfe_`loc'_`bgroup'_bindata_pub.csv
      cap erase $out/block_`pg'_by_sc_dum_cfe_`loc'_`bgroup'_bindata_pub.do
      cap erase $out/block_`pg'_by_mus_dum_cfe_`loc'_`bgroup'_bindata_pub.csv
      cap erase $out/block_`pg'_by_mus_dum_cfe_`loc'_`bgroup'_bindata_pub.do
      binscatter dum_`pg'_pub sc_share , control(muslim_share log_block_pop) absorb(`upper') ///
          xtitle(SC Share, size(large)) ytitle(`ytitle', size(large) ) ylab(`ylab')  ///
          xlab(0(0.1)1) mcolor(navy) msymbol(O)    ///
          name(block`pg'sc`loc', replace) linetype(none) savedata($out/block_`pg'_by_sc_dum_cfe_`loc'_`bgroup'_bindata_pub)
      graphout block_`pg'_by_sc_dum_cfe_`loc'_`bgroup'_pub, pdf
      
      /* muslim binscatter */
      binscatter dum_`pg'_pub  muslim_share , control(sc_share log_block_pop) absorb(`upper')  ///
          xtitle(Muslim Share, size(large)) ytitle(`ytitle', size(large))  ylab(`ylab')   ///
          xlab(0(0.1)1) mcolor(cranberry) msymbol(T)  ///
          name(block`pg'muslim`loc', replace) linetype(none) savedata($out/block_`pg'_by_mus_dum_cfe_`loc'_`bgroup'_bindata_pub)
      graphout block_`pg'_by_mus_dum_cfe_`loc'_`bgroup'_pub, pdf
    }
  }
}

/* ---------------------------- cell:  ---------------------------- */

/*********************************************/
/* create binscatters for the devdatalab viz */
/*********************************************/
use $tmp/secc/segregation_blockdata_urban_200, clear
local ytitle "Indicator For any Secondary School"
local ylab "0.014(0.002)0.026"
local fe "Town"
local upper town

/* erase savedata files */
cap erase $out/binscatter_viz_sc.csv
cap erase $out/binscatter_viz_sc.do
cap erase $out/binscatter_viz_muslim.csv
cap erase $out/binscatter_viz_muslim.do

/* generate per capita versions of binscatter variables */
gen dum_secondary_pub_pcap = dum_secondary_pub / block_pop * 100000

/* sc binscatter */
binscatter dum_secondary_pub_pcap sc_share , control(muslim_share log_block_pop) absorb(town) ///
    xtitle(SC Share, size(large)) ytitle("Secondary schools per 100,000 people", size(medlarge) )   ///
    xlab(0(0.1)1) mcolor(navy) msymbol(O)    ///
    name(blocksecondaryscurban, replace) linetype(none) savedata($out/binscatter_viz_sc)
graphout binscatter_viz_sc, pdf

/* muslim binscatter */
binscatter dum_secondary_pub_pcap  muslim_share , control(sc_share log_block_pop) absorb(town)  ///
    xtitle(Muslim Share, size(large)) ytitle("Secondary schools per 100,000 people", size(medlarge))     ///
    xlab(0(0.1)1) mcolor(cranberry) msymbol(T)  ///
    name(blocksecondarymuslimurban, replace) linetype(none) savedata($out/binscatter_viz_muslim)
graphout binscatter_viz_muslim, pdf

