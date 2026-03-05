/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/secc_ec_blockdata_`loc'_pooled_`bgroup'.dta         */
/*   - $tmp/secc/secc_ec_citydata_`loc'.dta                          */
/* OUTPUTS:                                                            */
/*   - $tmp/secc/seg_all_`geo'_data_`loc'_`bgroup'.dta                  */
/* GOAL:                                                               */
/*   Generate consumption, education, and public-goods variables.       */
/*                                                                     */
/* This do file breaks up the erstwhile gen_segregation_variables.do   */
/* file into several easier to understand do files. This do file       */
/* Generates Additional Block And City level variables such as:        */
/* 1. Consumption per capita                                           */
/* 2. Deprecated share variables from the EC data that we don't use    */
/*    and from PC data that we do use                                  */
/* 3. Education                                                        */
/* 4. Public Goods                                                     */
/***********************************************************************/

/* loop over group poolings */
foreach bgroup in 200 4000 {
  
  /* do for both rural and urban */
  foreach loc in rural urban {
    
    /* show progress */
    disp_nice "`loc'"
    
    /* set loc letter for filenames */
    if "`loc'" == "urban" {
      local l u
      local locality pc11_town_id
      local upper town
    }
    
    if "`loc'" == "rural" {
      local l r
      local locality pc11_village_id
      local upper subdistrict
    }
    
    /*********************************************************/
    /* I. Generate additional block and city level variables */
    /*********************************************************/
    foreach geo in block city {
      
      /* pooled data only exists for blocks, cities require no pooling */
      if "`geo'" == "block" {

        /* use data */
        use $tmp/secc/secc_ec_blockdata_`loc'_pooled_`bgroup', clear

        /* rename variables */
        /* hhpop is all individuals classified as sc or st in secc data
        block pop has all individuals in secc data.*/
        ren block_pop block_pop_with_invalid
        ren hhpop* block_pop*
        
        /*************************************/
        /* Remove Outlier enumeration blocks */
        /*************************************/
        /* Remove blocks that are too small or too big in 200 data */
        if `bgroup' == 200 {
          drop if block_pop < 150 | block_pop > 1000
        }

        /* remove very small block groups/neighborhoods in the 4000 dataset */
        if `bgroup' == 4000 {
          drop if block_pop < 150
        }
        
        
        /* remove blocks with 50% or more missing SC classification */
        drop if bad_sc > 0.5*block_pop & !mi(bad_sc)
      }
      
      if "`geo'" == "city"  {
        /* note: we don't remove outlier enumeration blocks here, but we don't use this
        in any of our analysis files so we should be okay. */
        use $tmp/secc/secc_ec_citydata_`loc', clear

        /* rename variables */
        /* hhpop is all individuals classified as sc or st in secc data
        block pop has all individuals in secc data.*/
        ren city_pop city_pop_with_invalid
        ren hhpop* city_pop*
      }

      /***************/
      /* Consumption */
      /***************/    
      /* calculate consumption per household and per capita */
      gen cons_pcap = cons / `geo'_pop

      /* convert all 0's in consumption to missing */
      replace cons_pcap = . if cons_pcap == 0

      /* winsorize consumption measures at the lower end:
      replace <1%le with the 1%ile value  */
      sum cons_pcap, d
      replace cons_pcap = `r(p1)' if cons_pcap < `r(p1)'
      
      /* generate log values */
      gen log_cons_pcap = log(cons_pcap)
      label var log_cons_pcap "log cons per cap"

      /* define list of all demographic groups */
      local demo_groups sc muslim nonscmuslim
      
      /* calculate population percentages and consumption per hh and per capita for each demographic group */
      foreach demo in `demo_groups' {

        /* replace 0 consumption with missings. 0 comes when all observations in the
        neighborhood collapse are missing */
        gen cons_pcap_`demo' = cons_`demo' / `geo'_pop_`demo'
        replace cons_pcap_`demo' = . if cons_pcap_`demo' == 0
        
        
        /* winsorize consumption measures: replace <1%le or >99%ile with the 1%ile and 99%ile values  */
        sum cons_pcap_`demo', d
        replace cons_pcap_`demo' = `r(p1)' if cons_pcap_`demo' < `r(p1)'

        /* get log consumption for different demographic groups */
        gen log_cons_pcap_`demo' = log(cons_pcap_`demo')
      }
      
      /* get the log of the block population */
      gen log_`geo'_pop =log(`geo'_pop)
      
      /*******************/
      /* Minority Shares */
      /*******************/
      /* calculate population percentages and consumption per hh and per capita for each demographic group */
      foreach demo in `demo_groups' {
        gen `demo'_share = `geo'_pop_`demo' / `geo'_pop if !mi(`geo'_pop_`demo')
      }
      
      /****************/
      /* Public Goods */
      /****************/
      /* calculate per capita percentages of employment at health facilities */
      foreach i in "" _pub _emp_pub _priv _emp_priv {
        
        /********************************/
        /* generate education variables */
        /********************************/
        /* gen primary education variable */
        gen primary`i' = nic851`i'
        gen dum_primary`i' = primary`i'
        replace dum_primary`i' = 1 if dum_primary`i' > 0 & !mi(dum_primary`i')
        gen log_primary`i' = log(primary`i' + 1)
        
        /* gen secondary education variable */
        gen secondary`i' =  nic852`i'
        gen dum_secondary`i' = secondary`i'
        replace dum_secondary`i' = 1 if dum_secondary`i' > 0 & !mi(dum_secondary`i')
        gen log_secondary`i' = log(secondary`i' + 1)
        
        /* gen higher education variable */
        gen higher`i' =  nic853`i'
        gen dum_higher`i' = higher`i'
        replace dum_higher`i' = 1 if dum_higher`i' > 0 & !mi(dum_higher`i')
        gen log_higher`i' = log(higher`i' + 1)

        /***********************/
        /* gen health variable */
        /***********************/        
        /* generate health dummies */
        /* nic861 = hospital activities; nic862 = medical and dental practice activities; nic869 = others (including ayurveda, unani etc.) */
        egen hospital`i' =  rowtotal(nic861`i'  nic862`i' nic869`i') , missing
        gen dum_hospital`i' = hospital`i'
        replace dum_hospital`i' = 1 if dum_hospital`i' > 0 & !mi(dum_hospital`i')
        gen log_hospital`i' = log(hospital`i' + 1)
      }
      
      /*****************************/
      /* Remove Redundnt variables */
      /*****************************/
      /* remove redundant ec variables */
      drop nic* own* caste* religion* emp* *_ec ecfirm

      /* remove parental-education variables; neighborhood-level analysis uses other education measures */
      drop father_ed* mother_ed* daughter_ed* son_ed* ed_yrs*

      /* Drop education and education#demo variables (from the secc collapse) */
      drop ed*

      /* drop consumption residuals and scaled hhpop and any st variables, pov rate (from secc collapse) */
      capdrop consr* *_st *scaled* st pov_rate*

      /* drop household counts we don't use */
      drop hh_* insidehh

      /* drop cons variables we don't use */
      drop cons_pc cons_pc_* cons cons cons_sc cons_muslim cons_non* 

      /* drop bothmuslim measures: these were added to check for overlap between sc and muslim pop */
      drop  *bothscmuslim
      
      /* save data */
      cap mkdir $tmp/secc/
      save $tmp/secc/seg_all_`geo'_data_`loc'_`bgroup', replace

    }
  }
}
