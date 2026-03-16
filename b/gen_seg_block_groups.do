/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/block_to_nbd/secc_`loc'_block_to_nbd_`bgroup'_key.dta */
/*   - $tmp/secc/secc_ec_blockdata_`loc'_pooled_`bgroup'.dta         */
/* OUTPUTS:                                                            */
/*   - $tmp/block_group_seg.csv                                        */
/*   - $tmp/nbd_count_`loc'_`bgroup'.dta                               */
/* GOAL:                                                               */
/*   Summarize segregation metrics across block group sizes.            */
/*                                                                     */
/* This file appends all partitions of different block group data      */
/* This data is then plotted out by $scode/a/city_seg_block_group_decrease.do */
/* in the analysis makefile                                            */
/*                                                                     */
/* This dataset supports neighborhood-size sensitivity graphs.         */
/***********************************************************************/


/**********************************************************************/
/* Collapse each dataset to mean sc/muslim share and save it to a csv */
/**********************************************************************/
/* save average dissimilarity over different bgroups to file */
cap file close f_dissim_iso
file open f_dissim_iso using $tmp/block_group_seg.csv, write replace

/* write in column headers */
file write f_dissim_iso "block_group,mean_pop,sector,mean_sc_dissim,mean_muslim_dissim,mean_sc_iso,mean_muslim_iso,mean_sc_iso_rescaled,mean_muslim_iso_rescaled" _n

/* loop over sector. We don't do rural, since this is currently only
   used for the international comparison of urban segregation across countries.. */
foreach loc in urban /* rural */ {

  /* loop over block group thresholds */
  foreach bgroup in 0 200 500 1000 1500 2000 3000 4000 5000 7500 10000 /* 100000 */ {


    /* Get the neighborhood count dataset, used to estimate total population of the the neighborhood.
       Note that we have incomplete coverage of each neighborhood, so we don't want to use block_pop.
       The average enumeration block size, given 2.5 million eb's, is 504. but examination of 2011
       census district handbooks suggests in urban areas the mean is 530. */
    use $tmp/secc/block_to_nbd/secc_`loc'_block_to_nbd_`bgroup'_key, clear

    /* get the number of blocks in each "neighborhood" at this size */
    gen nbd_count = 1
    collapse (sum) nbd_count, by(nbd)

    /* rename nbd to block_no, for consistency with how it's saved in the aggregated files */
    ren nbd block_no
    
    save $tmp/nbd_count_`loc'_`bgroup', replace
    
    /* display loc bg0 roup */
    di "Calculating segregation at aggregation `bgroup' in `loc' sector"
    
    /* open the neighborhood level file with minority populations */
    use $tmp/secc/secc_ec_blockdata_`loc'_pooled_`bgroup', clear

    /* merge in the neighborhood count */
    /* use mean figure from sample 2011 census district handbooks, as explained above */
    /* this is used only later in the graph, to show how we compare to US Census Tracts */
    merge m:1 block_no using $tmp/nbd_count_`loc'_`bgroup'
    gen block_total_pop = 530 * nbd_count

    /* if we don't observe the number of neighborhoods, just use the observed population */
    replace block_total_pop = block_pop if mi(block_total_pop)

    /* gen upper variable */
    if "`loc'" == "rural" {
      local upper subdistrict
    }

    if "`loc'" == "urban" {
      local upper town
    }

    /* remove outlier enumeration blocks with 50% or more missing SC classification */
    drop if bad_sc > (0.5 * hhpop) & !mi(bad_sc)

    /* count the number of blocks in each location */
    bys `upper': egen block_count = count(hhpop)

    /* drop some vars we don't use */ 
    capdrop sc_share muslim_share nonscmuslim_share city_dissim_sc city_dissim_muslim 
    
    /* calculate each city's population of each minority and total population */
    bys `upper': egen upper_pop_sc = total(hhpop_sc)
    bys `upper': egen upper_pop_muslim = total(hhpop_muslim)
    bys `upper': egen upper_pop_total = total(hhpop)
    
    /* calculate the mean block population at this aggregation of block */
    sum block_total_pop
    local block_total_pop = `r(mean)'
    
    /* create sc and muslim share variables */
    foreach demo in  sc muslim nonscmuslim { 
      gen `demo'_share = `demo' / block_pop if !mi(`demo')
    }

    /* create segregation variables */
    foreach demo in sc muslim  {

      /* dissimilarity measure inputs */
      capdrop minority_pop majority_pop
      gen minority_pop = hhpop_`demo' 
      gen majority_pop = hhpop_non`demo' 
      
      /* calculate dissimilarity, interaction, isoation and correlation */
      gen_dissimilarity, min(minority_pop) maj(majority_pop) gen("city_dissim_`demo'") label("`demo' (`upper')") upper(`upper') 

      /* calculate isolation index */
      gen_isolation, min(minority_pop) maj(majority_pop) gen("city_iso_`demo'") label("`demo' (`upper')") upper(`upper')

      /* if city is less than 4 blocks, set the city dissimilarity index to missing */
      qui replace city_dissim_`demo' = . if block_count <= 4
      qui replace city_iso_`demo' = . if block_count <= 4
      qui replace city_iso_`demo'_rescaled = . if block_count <= 4
    }

    /* Get the cross-city mean of dissimilarity for SCs and Muslims */

    /* tag each city so we only count it once */
    egen place_tag = tag(`upper')

    /* note that each is weighted by own-group population, which is our standardized comparison approach */
    sum city_dissim_sc [aw = upper_pop_sc] if place_tag == 1
    local mean_sc_dissim `r(mean)'

    sum city_dissim_muslim [aw = upper_pop_muslim] if place_tag == 1
    local mean_muslim_dissim `r(mean)'

    /* repeat for isolation */
    sum city_iso_sc [aw = upper_pop_sc] if place_tag == 1
    local mean_sc_iso `r(mean)'
    sum city_iso_muslim [aw = upper_pop_muslim] if place_tag == 1
    local mean_muslim_iso `r(mean)'
    
    /* repeat for cutler-glaeser-vigdor rescaled isolation */
    sum city_iso_sc_rescaled [aw = upper_pop_sc] if place_tag == 1
    local mean_sc_iso_rescaled `r(mean)'
    sum city_iso_muslim_rescaled [aw = hhpop_muslim] if place_tag == 1
    local mean_muslim_iso_rescaled `r(mean)'

    /* parse out sub-state blocks to ease memory load for large states*/
    file write f_dissim_iso "`bgroup',`block_total_pop',`loc',`mean_sc_dissim',`mean_muslim_dissim',`mean_sc_iso',`mean_muslim_iso',`mean_sc_iso_rescaled',`mean_muslim_iso_rescaled'" _n
  }
}

file close f_dissim_iso

/* open the modified csv */
insheet using $tmp/block_group_seg.csv, clear

/* save it to a Stata file */
save $tmp/dissim_iso_block_groups, replace
