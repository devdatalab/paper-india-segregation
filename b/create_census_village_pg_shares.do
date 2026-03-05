/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $shrug/data/shrug_pc91_pca.dta                                   */
/*   - $shrug/data/shrug_pc91_vd.dta                                    */
/*   - $shrug/data/shrug_pc01_pca.dta                                   */
/*   - $shrug/data/shrug_pc01_vd.dta                                    */
/* OUTPUTS:                                                            */
/*   - $tmp/census_village_pg_shares.dta                        */
/* GOAL:                                                               */
/*   Link census waves and build village PG/share time-series data.     */
/*                                                                     */
/* This do file links data across censuses and creates a dataset to     */
/* show mg shares are constant over time                               */
/***********************************************************************/

/*load in PC91 data  */
use $shrug/data/shrug_pc91_pca.dta, clear

/* create sc_share_pc91 */
gen sc_share_pc91 = pc91_pca_p_sc/pc91_pca_tot_p

/* merge in vd */
merge 1:1  shrid using $shrug/data/shrug_pc91_vd.dta, nogen keep(match) 

/* generate primary school variable */
gen primary_pc91 = pc91_vd_p_sch

/* generate secondary school variable */
egen secondary_pc91 = rowtotal(pc91_vd_m_sch pc91_vd_s_sch pc91_vd_s_s_sch), missing

/* generate health variable */
egen hospital_pc91 = rowtotal( pc91_vd_hosp pc91_vd_mcw_cntr pc91_vd_m_home pc91_vd_cwc pc91_vd_h_cntr ///
    pc91_vd_ph_cntr pc91_vd_phs_cnt pc91_vd_disp_cntr pc91_vd_fwc_cntr pc91_vd_tb_cln pc91_vd_n_home), missing

/* merge in pc01 data */
merge 1:1 shrid using $shrug/data/shrug_pc01_pca.dta, nogen keep(match) 

/* create sc_share_pc01 */
gen sc_share_pc01 = pc01_pca_p_sc/pc01_pca_tot_p

/* merge in vd */
merge 1:1  shrid using $shrug/data/shrug_pc01_vd.dta, nogen keep(match)

/* generate primary school variable */
gen primary_pc01 = pc01_vd_p_sch

/* generate secondary school variable */
egen secondary_pc01 = rowtotal(pc01_vd_m_sch pc01_vd_s_sch pc01_vd_s_s_sch), missing

/* generate health variable */
egen hospital_pc01 = rowtotal( pc01_vd_hosp  pc01_vd_mcw_cntr pc01_vd_m_home pc01_vd_cwc pc01_vd_h_cntr ///
    pc01_vd_ph_cntr pc01_vd_phs_cnt pc01_vd_disp_cntr pc01_vd_fwc_cntr pc01_vd_tb_cln pc01_vd_n_home), missing

/* merge in pc11 pca data */
merge 1:1 shrid using $shrug/data/shrug_pc11_pca.dta, nogen keep(match)

/* create sc_share_pc01 */
gen sc_share_pc11 = pc11_pca_p_sc/pc11_pca_tot_p

/* merge in pc11 vd data */
merge 1:1 shrid using $shrug/data/shrug_pc11_vd.dta, nogen keep(match)

/* generate primary school variable */
/* Note: these are all government provided now */
gen primary_pc11 = pc11_vd_p_sch_gov 

/* generate secondary school variable */
egen secondary_pc11 = rowtotal(pc11_vd_m_sch_gov pc11_vd_s_sch_gov pc11_vd_s_s_sch_gov), missing

/* generate health (government) variable */
egen hospital_pc11 = rowtotal(pc11_vd_all_hosp pc11_vd_altmed_hosp pc11_vd_mcw_cntr pc11_vd_ch_cntr ///
    pc11_vd_ph_cntr pc11_vd_phs_cntr pc11_vd_disp pc11_vd_fwc_cntr pc11_vd_tb_cln pc11_vd_mh_cln  ), missing

/* Merge in PC11 state ID for fixed effects */
merge 1:m shrid using $shrug/keys/shrug_pc11r_key.dta,  nogen keep(match)

/* drop duplicates */
duplicates drop shrid, force

/* label variables */
label var primary_pc91 "Primary Schools (PC91)"
label var primary_pc01 "Primary Schools (PC01)"
label var primary_pc11 "Primary Schools (PC11)"
label var secondary_pc91 "Secondary Schools (PC91)"
label var secondary_pc01 "Secondary Schools (PC01)"
label var secondary_pc11 "Secondary Schools (PC11)"
label var hospital_pc91 "Health Facilities (PC91)"
label var hospital_pc01 "Health Facilities (PC01)"
label var hospital_pc11 "Health Facilities (PC11)"

/* save data */
save $tmp/census_village_pg_shares.dta, replace
