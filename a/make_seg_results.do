/* RUNS THE COMPLETE SEG ANALYSIS PIPELINE */

/*******************/
/* Save Start Time */
/*******************/
global analysis_start_time "$S_DATE $S_TIME"

/* set global to run only those files that take less than a few hours to build */
global fast 0

/* make temp directories to store intermediate data */
cap mkdir $tmp/a/
cap mkdir $tmp/a/tables/

/******************************************************/
/* analysis effect of reweighting the town sample     */
/* Appendix Table A.1                                 */
/******************************************************/
do $scode/a/reweight_town_subd_representativeness.do

/*****************************************/
/* appendix figure A.3: segregation maps */
/*****************************************/
shell PYTHONPATH=$scode $python $scode/a/seg_maps.py

/********************************/
/* city segregation/isolation density plots */
/********************************/
do $scode/a/city_seg_iso_density.do

/******************************************/
/* figure 2: segregation international comparison */
/******************************************/
do $scode/a/graph_seg_comparisons.do

/*********************************************/
/* Figure 3 district rural vs. urban correlates */
/*********************************************/
do $scode/a/graph_urban_rural_dissim_correlation.do

/*****************************/
/* correlates of segregation */
/* Table 4; Figure 4; Appendix Figure A.4; Appendix Table A.3 */
/*****************************/
do $scode/a/analyze_correlates.do

/************************************/
/* segregation vs service disparity */
/* Appendix Figure A.8 */
/************************************/
do $scode/a/explore_seg_vs_service_disparity.do

/****************************************************************/
/* table and graphs with segregation time series from handbooks */
/****************************************************************/
do $scode/a/gen_dissim_pc0111.do

/*****************************************************/
/* figure 5: public-good provision vs neighborhood minority-share binscatter */
/*****************************************************/
do $scode/a/block_pg_share_binscatter_pub_dummy.do

// for the online appendix, add private goods too
do $scode/a/block_pg_share_binscatter_priv_dummy.do

// for the online appendix, add semi-private goods too
do $scode/a/block_pg_share_binscatter_semipriv.do

/*****************************************************************/
/* figures 6-7 and appendix figures A.5-A.6: PE function visualizations */
/*****************************************************************/
do $scode/a/graph_pe_functions.do

/*********************************************************************/
/* figure 8: PE function for urban wash amenities/infrastructure access */
/*********************************************************************/
do $scode/a/graph_pe_sanitation.do

/*************************************/
/* table 1: summary statistics table */
/*************************************/
do $scode/a/table_sum_stats.do

/*********************************************/
/* table 2 : sample representativeness table */
/*********************************************/
do $scode/a/table_town_subd_representativeness.do

/*********************************************/
/* table 3 : SC segregation time comparison (2001 vs 2011) */
/*********************************************/
do $scode/a/analyze_seg_changes.do

/*********************************************/
/* city dissimilarity/isolation regressions on city characteristics */
/*********************************************/
do $scode/a/city_dissim_town_char.do

/****************************************************************/
/* table 5,6,7: public good provision at the neighborhood level */
/****************************************************************/
do $scode/a/table_block_pg_share_educ_health.do

/************************************************************/
/* appendix figure A.1: enumeration block groups distributions */
/************************************************************/
do $scode/a/block_group_pop_histogram_density.do

/***************************************************************/
/* appendix figure A.2: muslim(lstm) vs. muslim(pc11) correlation */
/***************************************************************/
do $scode/a/city_share_muslim_pc_classify.do

/*********************************************************/
/* figure 1: group-share distributions across neighborhoods */
/*********************************************************/
do $scode/a/graph_group_shares.do

/********************************************************/
/* India-vs-US segregation comparison graphs */
/********************************************************/
do $scode/a/city_seg_iso_density_india_us.do

/***********************************/
/* additional lowess graphs */
/***********************************/
do $scode/a/fig_lowess_city_age.do

/*************************************************************/
/* additional log-employment secondary-school binscatters */
/*************************************************************/
do $scode/a/block_pg_share_binscatter_pub_log_emp.do

// for the online appendix, add private goods too
do $scode/a/block_pg_share_binscatter_priv_log_emp.do

/**************************************************/
/* appendix table A.4: neighborhood PG regressions in and out of slums */
/**************************************************/
do $scode/a/table_block_pg_share_educ_health_slum.do

/************************************************************/
/* appendix table: nbd regs controlling for nbd consumption */
/* Appendix Table A.5 */
/************************************************************/
do $scode/a/pg_inequality_w_controls.do

/***************************************************************/
/* appendix table: PG supply, intersectionality of Muslim * SC */
/* Appendix Figure A.7 */
/***************************************************************/
do $scode/a/pg_intersection.do


/*****************/
/* Save End Time */
/*****************/
global analysis_end_time "$S_DATE $S_TIME"
di  "Make File Analysis started at: $analysis_start_time"
di "Make File Analysis ended at: $analysis_end_time"
