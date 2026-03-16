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

