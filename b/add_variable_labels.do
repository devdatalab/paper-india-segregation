/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_`geo'data_`loc'_`bgroup'.dta               */
/* OUTPUTS:                                                            */
/*   - $tmp/secc/segregation_blockdata_`loc'_`bgroup'.dta            */
/*   - $tmp/secc/segregation_citydata_`loc'_`bgroup'.dta             */
/*   - $raw/clean/segregation_villagedata_rural.dta                   */
/* GOAL:                                                               */
/*   Apply variable labels to block and city segregation datasets.      */
/*                                                                     */
/* Label SECC block and city level variables                            */
/*                                                                     */
/* This do-file adds labels to block and city level SECC data.          */
/*                                                                     */
/* Labels are read from local CSV files in $raw/labels.                 */
/*                                                                     */
/* This avoids external runtime dependencies during replication.        */
/***********************************************************************/

/*******************************************************/
/* Apply labels from local CSV mappings                */
/*******************************************************/

/* loop over block group size */
foreach bgroup in 200 4000 {

  /* loop over sector */
  foreach loc in rural urban {

    /* loop over block or city */
    foreach geo in  city block {

      /* display nice */
      disp_nice "`loc' `geo' `bgroup'"
      
      /* use urban data */
      use $tmp/secc/segregation_`geo'data_`loc'_`bgroup', clear
      
      local label_csv "$raw/labels/seg_labels_`geo'_`loc'.csv"
      label_from_csv using "`label_csv'"

      save $tmp/secc/segregation_`geo'data_`loc'_`bgroup', replace
    }
  }
}

/*******************************************/
/* Data Validation: Paper Validation Stats */
/*******************************************/
// /*********************************/
// /* Paper Stats by Section: Intro */
// /*********************************/
// /* L100, number of urban neighborhoods */
// 
// use $tmp/secc/segregation_blockdata_urban_200, clear
// 
// /* get number of neighborhoods */
// count
// 
// /* store count measure*/
// 
// /* line 112: get secondary school % disparity in muslim neighborhoods */
// coef_pg_muslim_normalized, pg(dum_secondary_pub) local_name(secondary_muslim) fe(town)
// 
// /* store muslim coefficient on secondary education */
//     timestamp($validation_logtime) group("pg disparity") sample_size(`r(N_secondary_muslim)') warning("any change") error("10% change") format(numeric)
// 
// /* line 112: get drinking water % disparity in muslim neighborhoods */
// coef_pg_muslim_normalized, pg(wat_source_home) local_name(wat_muslim) fe(town)
// 
// /* store muslim coefficient on piped drinking water */
//     timestamp($validation_logtime) group("pg disparity") sample_size(`r(N_wat_muslim)') warning("any change") error("10% change") format(numeric)
// 
// /* L100, number of towns */
// use $tmp/secc/segregation_citydata_urban_200, clear
// 
// /* get number of neighborhoods */
// count
// 
// /* store count measure, */
//     timestamp($validation_logtime) group("summary stat") sample_size(`r(N)') warning("any change") error("10% change") format(numeric)
// 
// /* paper stat 3: L100, number of rural neighborhoods */
// use $tmp/secc/segregation_blockdata_rural_200, clear
// 
// /* get number of neighborhoods */
// count
// 
// /* store count measure*/
//     timestamp($validation_logtime) group("summary stat") sample_size(`r(N)') warning("any change") error("10% change") format(numeric)
// 
// /* get number of villages, use distinct because of the easy to save scalar */
// distinct pc11_state_id pc11_district_id pc11_subdistrict_id pc11_village_id
// 
// /* store count measure, */
//     timestamp($validation_logtime) group("summary stat") sample_size(`r(ndistinct)') warning("any change") error("10% change") format(numeric)
