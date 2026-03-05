/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $raw/clean/secc_[rural/urban]_collapsed[_block].dta            */
/*   - $sdata/ec13_[rural/urban]_[city/block].dta                       */
/* OUTPUTS:                                                            */
/*   - $sdata/secc_ec_[city/block]data_[rural/urban].dta                */
/* GOAL:                                                               */
/*   Merge SECC and EC data at city and block level.                    */
/*                                                                     */
/* Merge SECC and EC data                                              */
/*                                                                     */
/* This do file merges SECC and EC data at city and block level.        */
/*                                                                     */
/* Input:                                                              */
/* 1. $raw/clean/secc_[rural/urban]_collapsed[_block] : SECC Block    */
/*    Data collapsed at Block or upper(subdistrict or shrid) level      */
/* 2. $sdata/ec13_[rural/urban]_[city/block] : Collapsed EC13 data at   */
/*    Block or upper(subdistrict or shrid) level                        */
/*                                                                     */
/* Output:                                                             */
/* 1. $sdata/secc_ec_[city/block]data_[rural/urban]                     */
/***********************************************************************/


cap mkdir $tmp/secc

/* loop over rural and urban*/
foreach loc in rural urban {


  /*****************************/
  /* I. Merge EC and SECC data */
  /*****************************/
  /* Note that the SECC covers about ~75%(rural) - ~57%(urban) as many Enumeration Blocks the EC.
  However, we keep only the blocks from the SECC data, since all our calculations of sc/muslim
  shares and dissimilarity etc. come from here  */

  /* This data comes from an earlier EC build which has upper*/
  /* merge city (upper) level ec and secc data */
  use $raw/clean/secc_`loc'_collapsed, clear

  /* define locals */
  /* show progress and set local geo ids */
  disp_nice "`loc'"
  if "`loc'" == "urban" {
    ren town upper
    local locality pc11_town_id
  }

  if "`loc'" == "rural" {
    local locality pc11_village_id
    ren subdistrict upper
  }

  /* define geographic variables to collapse on */
  local geo_vars pc11_state_id pc11_district_id pc11_subdistrict_id `locality'

  merge 1:1 upper using $raw/clean/ec13_`loc'_city, keep(master match) nogen
  /* This step to explicitly remove the shrid and upper variable that comes from ec data,
  and only exists for common EBs and not all SECC EBs */
  cap drop shrid

  /* rename upper to town or subdistrict */
  if "`loc'" == "urban" ren upper town
  if "`loc'" == "rural" ren upper subdistrict

  /* rename own1 variable from ec to be pub */
  rename *own1 *pub
  
  /* save data */
  save $tmp/secc/secc_ec_citydata_`loc', replace

  /* merge block level ec and secc data */
  /* keep all secc ebs, drop ec ebs not in SECC data, hence option keep(master match) */
  use $raw/clean/secc_`loc'_collapsed_block, clear
  merge m:1 `geo_vars' pc11_ward_id pc11_block_id using $raw/clean/ec13_`loc'_block, keep(master match) nogen

  /* This step to explicitly remove the shrid and upper variable that comes from ec data,
  and only exists for common EBs and not all SECC EBs*/
  cap drop shrid
  cap drop upper
  
  /* rename own1 variable from ec to be pub */
  rename *own1 *pub

  /* save data */
  save $tmp/secc/secc_ec_blockdata_`loc', replace
}
