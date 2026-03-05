/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_blockdata_`loc'_`bgroup'.dta            */
/* OUTPUTS:                                                            */
/*   - $out/block_`pg'_by_{sc,mus}_log_emp_cfe_`loc'_`bgroup'_pub.pdf    */
/* GOAL:                                                               */
/*   Plot log employment at public goods vs group shares.              */
/*                                                                     */
/* create binscatters of log employment at PG on mg share              */
/***********************************************************************/

/*****************************/
/* Log Employment Binscatter */
/*****************************/
/* loop over block groups */
foreach bgroup in 200 4000 { 

  /* Loop over locs(Urban/Rural) */
  foreach loc in rural urban {
    
    /* use data */
    use $tmp/secc/segregation_blockdata_`loc'_`bgroup', clear
    
    /* loop over all public goods */
    foreach pg in primary secondary hospital {
      
      /* labels */
      if  "`pg'" == "hospital" local ytitle "Log Employment at Health Facility"
      if  "`pg'" == "primary" local ytitle "Log Employment at Primary School"
      if  "`pg'" == "secondary" local ytitle "Log Employment at Secondary School"
      
      if inlist("`pg'", "hospital", "hospital_861", "hospital_862" "hospital_other") &  "`loc'" == "urban" {
        local title "Health Facility (Urban)"
        if "`bgroup'" == "200" local ylab "0.01(0.005)0.06"
        if "`bgroup'" == "4000" local ylab "0.05(0.02)0.17"
      }
      
      if inlist("`pg'", "hospital", "hospital_861", "hospital_862" "hospital_other")  & "`loc'" == "rural" {
        local title "Health Facility (Rural)"
        if "`bgroup'" == "200" local ylab "0.055(0.005)0.095"
        if "`bgroup'" == "4000" local ylab "0.07(0.005)0.1"        
      }
      
      if "`pg'" == "primary" & "`loc'" == "urban" {
        local title "Primary School (Urban)"
        if "`bgroup'" == "200" local ylab "0.1(0.005)0.14"
        if "`bgroup'" == "4000" local ylab "0.24(0.02)0.36"
      }

      if "`pg'" == "primary" & "`loc'" == "rural" {
        local title "Primary School (Rural)"
        if "`bgroup'" == "200" local ylab "0.45(0.025)0.6"
        if "`bgroup'" == "4000" local ylab "0.7(0.05)1"
      }
      
      if  "`pg'" == "secondary" & "`loc'" == "urban" {
        local title "Secondary School (Urban)"
        if "`bgroup'" == "200" local ylab "0.04(0.004)0.076"
        if "`bgroup'" == "4000" local ylab "0.1(0.02)0.22"
      }
      
      if  "`pg'" == "secondary" & "`loc'" == "rural" {
        local title "Secondary School (Rural)"
        if "`bgroup'" == "200" local ylab "0.11(0.005)0.16"
        if "`bgroup'" == "4000" local ylab "0.16(0.01)0.21"        
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

      /* erase older saved data */
      cap erase $out/block_`pg'_by_sc_log_emp_cfe_`loc'_`bgroup'_pub_bindata_pub.csv
      cap erase $out/block_`pg'_by_sc_log_emp_cfe_`loc'_`bgroup'_pub_bindata_pub.do
      cap erase $out/block_`pg'_by_mus_log_emp_cfe_`loc'_`bgroup'_pub_bindata_pub.csv
      cap erase $out/block_`pg'_by_mus_log_emp_cfe_`loc'_`bgroup'_pub_bindata_pub.do
      
      /* log employment binscatter */
      /* sc binscatter */
      binscatter log_`pg'_emp_pub sc_share , control(muslim_share log_block_pop) absorb(`upper') ///
          xtitle(SC Share, size(large)) ytitle(`ytitle', size(large) ) ylab(`ylab')  ///
          xlab(0(0.1)1) mcolor(navy) msymbol(O)    ///
          name(block`pg'sc`loc', replace) linetype(none) savedata($out/block_`pg'_by_sc_log_emp_cfe_`loc'_`bgroup'_pub_bindata_pub)
      graphout block_`pg'_by_sc_log_emp_cfe_`loc'_`bgroup'_pub, pdf
      
      /* muslim binscatter */
      binscatter log_`pg'_emp_pub  muslim_share , control(sc_share log_block_pop) absorb(`upper')  ///
          xtitle(Muslim Share, size(large)) ytitle(`ytitle', size(large))  ylab(`ylab')   ///
          xlab(0(0.1)1) mcolor(cranberry) msymbol(T)  ///
          name(block`pg'muslim`loc', replace) linetype(none) savedata($out/block_`pg'_by_mus_log_emp_cfe_`loc'_`bgroup'_pub_bindata_pub)
      graphout block_`pg'_by_mus_log_emp_cfe_`loc'_`bgroup'_pub, pdf
    }
  }
}
