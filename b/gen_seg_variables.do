/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/seg_all_block_data_`loc'_`bgroup'.dta                  */
/* OUTPUTS:                                                            */
/*   - $tmp/secc/segregation_blockdata_`loc'_`bgroup'.dta               */
/* GOAL:                                                               */
/*   Compute segregation and dissimilarity measures by demographics.    */
/*                                                                     */
/* This do file contains the part of erstwhile gen_segregation_         */
/* variables.do that creates the dissimilarity measure. This do file   */
/* calculates various segregation measures. For now we only use        */
/* segregation by demographics.                                       */
/*                                                                     */
/* II. Calculate dissimilarities                                       */
/* A. Segregation by Demographics                                      */
/* 1. Calculate Gini Index                                             */
/***********************************************************************/


/* loop over block groups */
foreach bgroup in 200 4000 {

  /* loop over sector */
  foreach loc in urban rural {

    /*******************************/
    /* II. Calculate Dissimilarity */
    /*******************************/
    /* Note: All Segregation Measures come from
    "Segregation and Diversity Measures in Population Distribution",
    Michael J. White, 1986*/
    use $tmp/secc/seg_all_block_data_`loc'_`bgroup', clear

    /* Create local for subdistrict/city based on sector */
    if "`loc'" == "rural" local upper subdistrict
    if "`loc'" == "urban" local upper town

    /* create a counter of the number of block units in a upper(subdistrict/town) unit */
    bysort `upper': egen block_units = sum(1)
    label var block_units "number of block units in this `upper' unit"
    
    /*****************************/
    /* Segregation: Demographics */
    /*****************************/
    /* these are the dissimilarity dimensions */
    foreach demo in sc muslim {

      /* dissimilarity measure inputs */
      capdrop minority_pop majority_pop
      gen minority_pop = block_pop_`demo' 
      gen majority_pop = block_pop_non`demo' 
      
      /* calculate dissimilarity, interaction, isolation and correlation */
      gen_dissimilarity, min(minority_pop) maj(majority_pop) gen("city_dissim_`demo'") label("`demo' (`upper')") upper(`upper') 

      /* calculate interaction indices for majority and minority */
      gen_interact_maj, min(minority_pop) maj(majority_pop) gen("city_interact_maj_`demo'") label("`demo' (`upper')") upper(`upper')
      gen_interact_min, min(minority_pop) maj(majority_pop) gen("city_interact_min_`demo'") label("`demo' (`upper')") upper(`upper') 
      
      /* calculate isolation index */
      gen_isolation, min(minority_pop) maj(majority_pop) gen("city_iso_`demo'") label("`demo' (`upper')") upper(`upper')
      
      /* calculate correlation index
      note: this depends on isolation*/
      gen_correlation, min(minority_pop) maj(majority_pop) gen("city_correlation_`demo'") demo(`demo') label("`demo' (`upper')") upper(`upper')

      /* calculate gini index */
      gen_gini, x_i(minority_pop) y_i(majority_pop) gen("city_gini_`demo'") label("`demo' (`upper')") upper(`upper') 

      /* if city is less than 4 blocks, set the city segregation indices to missing */
      foreach var in dissim interact_min interact_maj iso correlation gini {
        replace city_`var'_`demo' =. if block_units < 4
      }
    }

    /*********************/
    /* Calculate Entropy */
    /*********************/
    /* generate demo specific measures to calculate Hbar and Hhat */

    /* create `upper' pop */
    bysort `upper': egen `upper'_pop = sum(block_pop)

    /* create pop weights */
    gen ent_weight = block_pop/`upper'_pop

    /* loop over demo */
    foreach demo in sc muslim nonscmuslim {

      /* create variables for Hbar */
      gen ent_p_`demo' = `demo'/block_pop
      gen log_ent_p_`demo' = log(ent_p_`demo')

      
      /* Create variables for hhat */
      bysort `upper': egen ent_total_`demo' = sum(`demo')
      bysort `upper': gen ent_total_p_`demo' = ent_total_`demo'/`upper'_pop
      bysort `upper': gen log_ent_total_p_`demo' = log(ent_total_p_`demo')
      
    }

    /* gen h  */
    gen ent_h = -(ent_p_sc*log_ent_p_sc + ent_p_muslim*log_ent_p_muslim  + ent_p_nonscmuslim*log_ent_p_nonscmuslim )
    gen ent_h_wtd = ent_h*ent_weight

    /* gen hbar */
    bysort `upper': egen ent_hbar = sum(ent_h_wtd)

    /* gen hhat */
    gen ent_hhat = -(ent_total_p_sc*log_ent_total_p_sc + ent_total_p_muslim*log_ent_total_p_muslim  + ent_total_p_nonscmuslim*log_ent_total_p_nonscmuslim )

    /* generate entropy index */
    gen ent_hindex = 1 - ent_hbar/ent_hhat
    label var ent_hindex "Entropy Index"

    /* drop intermediate entropy terms */
    drop ent_hbar ent_hhat ent_total_p_sc log_ent_total_p_sc ent_total_p_muslim  log_ent_total_p_muslim ent_total_p_nonscmuslim log_ent_total_p_nonscmuslim ent_h_wtd ent_h ent_weight

    /**********************************************************************/
    /* calculate ethnolinguistic fractionalisation/ELF at the block level */
    /**********************************************************************/

    /* loop over demo and total population */
    local i = 1
    foreach demo in sc muslim nonscmuslim block_pop {
      bysort `upper': egen x_`i' = sum(`demo')
      replace x_`i' = x_`i'^2
      local i = `i' + 1
    }

    /* generate share for each demo */
    /* loop over demo */
    local i = 1
    foreach demo in sc muslim nonscmuslim {
      bysort `upper': gen `demo'_share_2 = x_`i'/x_4
      local i = `i' + 1
    }
    
    /* generate ELF measure at the `upper' level */
    egen elf = rowtotal(sc_share_2 muslim_share_2 nonscmuslim_share_2)
    replace elf = 1 - elf
    label var elf "Fractionalisation"

    /* drop intermediary terms */
    drop x* *_share_2
    
    /* save block level data */
    save $tmp/secc/segregation_blockdata_`loc'_`bgroup', replace
  }
}
