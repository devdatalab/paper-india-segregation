/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_blockdata_`loc'_`bgroup'.dta               */
/*   - $tmp/secc/seg_all_city_data_`loc'_`bgroup'.dta                   */
/*   - $shrug/data/shrug_pc11_{td,vd,pca}.dta                           */
/*   - $shrug/keys/shrug_pc11_subdistrict_key.dta                       */
/*   - $tmp/pc11/pc11_muslims_`loc'.dta                         */
/* OUTPUTS:                                                            */
/*   - $tmp/secc/segregation_citydata_`loc'_`bgroup'.dta                */
/*   - $tmp/secc/segregation_blockdata_`loc'_`bgroup'.dta               */
/*   - $tmp/subdist_`loc'_`bgroup'.dta                                 */
/* GOAL:                                                               */
/*   Produce final city- and block-level segregation datasets.          */
/*                                                                     */
/* This file uses the temp files created in gen_seg_variables.do and   */
/* gen_pg_cons_variables.do, and saves the final segregation data at   */
/* the city and block level.                                           */
/*                                                                     */
/* City Level Data:                                                    */
/* 1. First read in the block level data (this has all the dissimilarity */
/*    info at the upper/city/shrid level from the underlying           */
/*    enumeration blocks from the secc. keep only segregation variables*/
/*    and those used to create the share of population with public     */
/*    good access. Then merge in the city level variables you'd        */
/*    generated at the city level in gen_pg_cons_variables.do.         */
/*                                                                     */
/* 2. After you've got segregation and share variables merged in with  */
/*    other city level variables, we then merge in pc11_vd/pc11_td      */
/*    amenities data. That's done in two loops.                        */
/*                                                                     */
/* Block Level Data                                                    */
/* In a tiny missable loop, we also save the block level segregation   */
/* data.                                                              */
/***********************************************************************/

/* loop over block groups */
foreach bgroup in 200 4000 {

  /******************************************/
  /* Create Shrid/Subdistrict Level Dataset */
  /******************************************/
  
  /* loop over sectors to create city data */
  foreach loc in urban rural {

    /* Use saved block data */
    use $tmp/secc/segregation_blockdata_`loc'_`bgroup', clear

    /* Create local for subdistrict/city based on loc */
    if "`loc'" == "urban" local upper town
    if "`loc'" == "rural" local upper subdistrict
    
    /* keep only the subdistrict/shrid-level measure generated in the dissimilarity calculations*/
    keep `upper' block_units city_dissim*  city_interact_min* city_interact_maj* city_correlation* ///
        elf city_iso_* ent_hindex city_gini*

    /* drop duplicate values for `upper' */
    duplicates drop `upper', force

    /* There seems to be one shrid in urban data which we get rid of here */
    cap drop if mi(`upper')
    
    /* Merge in shrid/subdistrict-level dissimilarity measures with the shrid/subdistrict-level data */
    merge 1:1 `upper' using $tmp/secc/seg_all_city_data_`loc'_`bgroup', keep(master match) nogen
    
    /* get log of shrid/subdistrict population */
    gen city_log_pop = log(city_pop)

    /* Merge iin pc11 data for urban/rural locs*/
    if "`loc'" == "urban" { 
      
      /* we use town as the identiier, which in the urban partition is just the shrid */
      gen shrid = `upper'
      
      /* bring in town directory */
      merge 1:1 shrid using $shrug/data/shrug_pc11_td, keep(master match) nogen keepusing(pc11_td_tot_p pc11_td_p_st pc11_td_p_sc pc11_td_primary_gov pc11_td_sec_gov ///
          pc11_td_area pc11_td_tot_p_* pc11_td_p_sch pc11_td_m_sch pc11_td_s_sch pc11_td_all_hospital)
      
      /* bring in pca */
      merge 1:1 shrid using $shrug/data/shrug_pc11_pca, keep(master match) nogen keepusing(pc11_pca_tot_p)

      /* generate city/town level variables */
      gen city_pop_pc11 = pc11_td_tot_p
      gen primary_pub_pc11 = pc11_td_primary_gov
      gen secondary_pub_pc11 = pc11_td_sec_gov
      gen log_primary_pub_pc11 = log(pc11_td_primary_gov)
      gen log_secondary_pub_pc11 = log(pc11_td_sec_gov)
      gen log_area_pc11 = log(pc11_td_area)
      gen log_city_pop_pc11 = log(pc11_td_tot_p)

      /* create city_origin_year variable */
      gen city_origin_year = .
      forval y = 1901(10)2011 {
        replace city_origin_year = `y' if mi(city_origin_year) & !mi(pc11_td_tot_p_`y') & (pc11_td_tot_p_`y' != 0)
      }

      /* construct pc share variables */
      gen scst_share_pc11 = (pc11_td_p_sc+pc11_td_p_st)/pc11_td_tot_p
      gen sc_share_pc11 = pc11_td_p_sc/pc11_td_tot_p
      gen st_share_pc11 = pc11_td_p_st/pc11_td_tot_p      

      /* drop block_units and total population variables */
      drop block_units pc11_td_tot_p_19* pc11_td_tot_p_20*

      /* schools, clinics per 100k people */
      gen prim_pc = pc11_td_p_sch * 100000 / pc11_pca_tot_p 
      gen mid_pc = pc11_td_m_sch * 100000 / pc11_pca_tot_p 
      gen sec_pc = pc11_td_s_sch * 100000 / pc11_pca_tot_p 
      gen hosp_pc = pc11_td_all_hospital * 100000 / pc11_pca_tot_p 

    }
    
    /* village-specific fixes */
    if "`loc'" == "rural" {
      
      /* collapse vd data to subdistrict */
      preserve
      use $shrug/data/shrug_pc11_vd, clear
      merge 1:1 shrid using $shrug/data/shrug_pc11_pca, keep(master match) keepusing(pc11_pca_tot_p) nogen
      merge 1:1 shrid using $shrug/keys/shrug_pc11_subdistrict_key, nogen
      gen subdistrict = pc11_state_id + pc11_district_id + pc11_subdistrict_id
      keep subdistrict pc11_state_id  pc11_district_id  pc11_subdistrict_id pc11_vd_all_hosp_doc_tot ///
          pc11_vd_p_sch_priv pc11_vd_p_sch_gov pc11_vd_s_sch_gov  ///
          pc11_vd_t_p pc11_vd_sc_p pc11_vd_st_p pc11_vd_s_sch_gov ///
          pc11_vd_p_sch pc11_vd_m_sch pc11_vd_s_sch pc11_vd_all_hosp pc11_vd_area ///
          pc11_pca_tot_p
      collapse (sum) pc11_vd_* pc11_pca_tot_p, by(subdistrict)
      save $tmp/temp_vd_subd, replace
      restore
      
      /* merge village data */
      merge m:1 subdistrict using $tmp/temp_vd_subd, keep(master match) nogen 
      
      /* construct pc variables */
      /* generate pc11 share variables */
      gen scst_share_pc11 = (pc11_vd_sc_p +pc11_vd_st_p)/pc11_vd_t_p
      gen sc_share_pc11 = pc11_vd_sc_p/pc11_vd_t_p
      gen st_share_pc11 = pc11_vd_st_p/pc11_vd_t_p      
      /* muslim_share_pc11 comes from $tmp/pc11/pc11_muslims_`loc' */
      
      /* generate city/subdistrict level variables */
      gen city_pop_pc11 = pc11_vd_t_p
      gen primary_pub_pc11 = pc11_vd_p_sch_gov
      gen secondary_pub_pc11 = pc11_vd_s_sch_gov
      gen log_primary_pub_pc11 = log(pc11_vd_p_sch_gov)
      gen log_secondary_pub_pc11 = log(pc11_vd_s_sch_gov)
      gen log_area_pc11 = log(pc11_vd_area)
      gen log_city_pop_pc11 = log(pc11_vd_t_p)

      /* schools, clinics per 100k people */
      gen prim_pc = pc11_vd_p_sch * 100000 / pc11_pca_tot_p 
      gen mid_pc = pc11_vd_m_sch * 100000 / pc11_pca_tot_p 
      gen sec_pc = pc11_vd_s_sch * 100000 / pc11_pca_tot_p 
      gen hosp_pc = pc11_vd_all_hosp * 100000 / pc11_pca_tot_p 

    }
    
    /* merge in muslim_share_pc11 variables variables */
    merge m:1 `upper' using $tmp/pc11/pc11_muslims_`loc', keep(master match) nogen
    
    /* save the city-level data */
    save $tmp/secc/segregation_citydata_`loc'_`bgroup', replace

    /* start with shrid subdist key */
    use $shrug/keys/shrug_pc11_subdistrict_key, clear
    if "`loc'" == "urban" {
      gen `upper' = shrid 
    }
    if "`loc'" == "rural" {
      gen `upper' = pc11_state_id + pc11_district_id + pc11_subdistrict_id
    }

    /* Drop if missing shrid data */
    drop if mi(shrid)
    
    /* clean variables in this shrid/subdistrict to `upper' key */
    drop shrid
    duplicates drop

    /* save subdist/shrid to `upper' key */
    save $tmp/subdist_`loc'_`bgroup', replace
    
    /* Merge citydata with this key */
    use $tmp/secc/segregation_citydata_`loc'_`bgroup', clear
    merge 1:1 `upper' using $tmp/subdist_`loc'_`bgroup', keep(master match) nogen

    /* Clean state ID for subdistricts */
    if "`loc'" == "rural" {
      replace pc11_state_id = substr(`upper',1,2) if pc11_state_id==""
      replace pc11_state_id = substr(`upper',3,5) if pc11_district_id==""
      replace pc11_state_id = substr(`upper',6,10) if pc11_subdistrict_id==""
    }

    /* save data */
    save $tmp/secc/segregation_citydata_`loc'_`bgroup', replace

  }

  
  /******************/
  /* Save BlockData */
  /******************/

  /* Loop over locs to save block data */
  foreach loc in urban rural {

    /* use data */
    use $tmp/secc/segregation_blockdata_`loc'_`bgroup', clear

    /* create locals */
    if "`loc'" == "urban" local upper town
    if "`loc'" == "rural" local upper subdistrict

    /* Drop missing data*/
    drop if mi(shrid)

    /* drop group_pop variable */
    cap drop group_pop
    
    /* save data */
    save $tmp/secc/segregation_blockdata_`loc'_`bgroup', replace
  }
}

  
