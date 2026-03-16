/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $raw/clean/secc_`loc'_collapsed_block.dta                      */
/*   - $sdata/secc_ec_blockdata_`loc'.dta                               */
/*   - $shrug/keys/shrug_pc11`l'_key.dta                                */
/* OUTPUTS:                                                            */
/*   - $sdata/secc_ec_blockdata_`loc'_pooled_`bgroup'.dta               */
/* SUBCALLS:                                                           */
/*   - seg_programs.do                                                  */
/* GOAL:                                                               */
/*   Pool SECC blocks into 200/4000 population block groups.            */
/*                                                                     */
/* Pool SECC block data to block groups                                */
/*                                                                     */
/* This do-file pools SECC block data into groups with a minimum        */
/* population. We pool blocks into groups of 200 and 4000:              */
/* i) 200 which gives us comparable EBs for comparision across rural    */
/*    and urban areas                                                  */
/* ii) 4000 which seems to include entire villages and larger chunks of */
/*     a town                                                          */
/*                                                                     */
/* Blocks are only pooled if they are geographically adjacent and are  */
/* located in the same town/village in the same ward. Last, we merge in */
/* the block group identifiers and collapse the block data to the block */
/* group level.                                                        */
/*                                                                     */
/* I. Clean data                                                       */
/* II. Pool blocks                                                     */
/* III. Collapse blocks to block groups (pool blocks)                   */
/*                                                                     */
/* *****NOTE : REQUIRES SSC INST _GWTMEAN *****                         */
/***********************************************************************/

/* load the segregation helper functions */
do $scode/seg_programs.do

cap mkdir $tmp/secc
cap mkdir $tmp/secc/block_to_nbd

/* If $rebuild is specified, create all the different block group collapses (used for
   generating dissim and isolation at different neighborhood sizes only. */
if ($rebuild == 1) {
  global group_min_list 0 200 500 1000 1500 2000 3000 4000 5000 7500 10000
}
else {
  global group_min_list 200 4000
}

/* create all the aggregated neighborhoods */
foreach group_min in $group_min_list {
	foreach loc in rural urban {

    local fp_out $tmp/secc/secc_ec_blockdata_`loc'_pooled_`group_min'
    create_block_groups, bgroup(`group_min') sector(`loc') outfile(`fp_out')
  }
}
