/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $pc11/pca/religion/pc11r_subdistrict_social_group.dta            */
/*   - $pc11/pca/religion/pc11u_town_social_group.dta                   */
/*   - $shrug/keys/shrug_pc11r_key.dta                                  */
/*   - $shrug/keys/shrug_pc11u_key.dta                                  */
/* OUTPUTS:                                                            */
/*   - $tmp/pc11/pc11_muslims_rural.dta                         */
/*   - $tmp/pc11/pc11_muslims_urban.dta                         */
/* GOAL:                                                               */
/*   Compute Muslim population shares at rural/urban PC11 levels.       */
/*                                                                     */
/* Compute muslim PC shares                                            */
/*                                                                     */
/* This do file calculates the muslim PC share for each shrid from PCA */
/* files                                                               */
/***********************************************************************/

cap mkdir $tmp/pc11

/* Rural */
use $pc11/pca/religion/pc11r_subdistrict_social_group.dta, clear

/* merge with shrids */
merge 1:m pc11_state_id pc11_state_id pc11_district_id pc11_subdistrict_id using "$shrug/keys/shrug_pc11r_key.dta"
gen subdistrict = pc11_state_id + pc11_district_id + pc11_subdistrict_id

/* average data for same shrid across subdistricts */
collapse (sum) pc11_p_muslim pc11_tot_p, by(subdistrict)

/* compute share */
gen muslim_share_pc11 = pc11_p_muslim/pc11_tot_p

/* keep share and shrid vars */
keep subdistrict muslim_share_pc11

/* drop if missing identifier for merge */
drop if mi(subdistrict)

/*save */
save "$tmp/pc11/pc11_muslims_rural.dta" , replace 

/* Urban */
use $pc11/pca/religion/pc11u_town_social_group.dta, clear

/* merge with shrid key */
merge m:1 pc11_state_id pc11_town_id using "$shrug/keys/shrug_pc11u_key.dta"
gen town = shrid

/* collapse --- note we keep town and shrid because they're both used as town identifiers in the code */
collapse (sum) pc11_p_muslim pc11_tot_p, by(town shrid)

/* gen muslim share */
gen muslim_share_pc11 = pc11_p_muslim / pc11_tot_p
keep shrid town muslim_share_pc11

/* drop if missing identifier for merge */
drop if mi(town)

/* save */
save "$tmp/pc11/pc11_muslims_urban.dta" , replace
