/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_citydata_urban_`bgroup'.dta             */
/*   - $tmp/secc/segregation_citydata_rural_`bgroup'.dta             */
/* OUTPUTS:                                                            */
/*   - $tmp/city_seg_district_rural_urban_`bgroup'.dta          */
/*   - $tmp/city_seg_district_{urban,rural}.dta                         */
/* GOAL:                                                               */
/*   Build district-level segregation correlates for urban vs rural.    */
/*                                                                     */
/* Create correlates for cons/pg variable Betas for urban vs rural      */
/* enumeration blocks within a district                                */
/***********************************************************************/

/* Maxvars in CVS after "xpose" command are 10,860, hence increase maxvar here */
clear
clear mata
clear matrix
set maxvar 20000

/* loop over EB group size */
foreach bgroup in 200 4000 {

  /*********************************/
  /* Generate Segregation Measures */
  /*********************************/

  /* save urban measures */
  /* use segregation data */
  use $tmp/secc/segregation_citydata_urban_`bgroup', clear
  
  /* take the means of segregation measures at the district level */
  gcollapse (mean) city_dissim_sc city_dissim_muslim city_iso_sc city_iso_muslim, by(pc11_district_id)
  
  /* rename segregation variables to add in the sector they come from */
  rename city_dissim_* city_dissim_*_u
  rename city_iso_* city_iso_*_u

  /* save data to merge in with rural measures below */
  save $tmp/city_seg_district_urban, replace
  
  /* save rural measures */
  /* use segregation data */
  use $tmp/secc/segregation_citydata_rural_`bgroup', clear
  
  /* take the means of segregation measures at the district level */
  gcollapse (mean) city_dissim_sc city_dissim_muslim city_iso_sc city_iso_muslim, by(pc11_district_id)
  
  /* rename segregation variables to add in the sector they come from */
  rename city_dissim_* city_dissim_*_r
  rename city_iso_* city_iso_*_r

  /* save data to merge in with rural measures below */
  save $tmp/city_seg_district_rural, replace

  /* merge rural urban data */
  merge 1:1 pc11_district_id using $tmp/city_seg_district_urban, nogen keep(match)
  
  /* save data */
  save $tmp/city_seg_district_rural_urban_`bgroup', replace
} 
