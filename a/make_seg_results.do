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

if ($fast == 0) {

  /***********/
  /* Figures */
  /***********/
  /***************************/
  /* figure 2: segregation maps */
  /***************************/
  /* make sure python environment is set to py_spatial before this is run */
  /* this can randomly throw tex errors, in which case restart the emacs sessions and try again */
  /* currently excluded from replication runtime */
  shell PYTHONPATH=$scode $python $scode/a/seg_maps.py
  // billy write $out/india_segregation_sc_urban.png
  // billy write $out/india_segregation_sc_rural.png
  // billy write $out/india_segregation_muslim_urban.png
  // billy write $out/india_segregation_muslim_rural.png

  
  /********************/
  /* Appendix Figures */
  /********************/

  /*************************/
  /* figure A.10 and A.11: */
  /*************************/
  /* excluded from replication runtime */
  // do $scode/a/coefplot_block_individual_ed_age.do
  
  /*********************************************************************/
  /* appendix figure A.13: educational attainment across neighborhoods */
  /*********************************************************************/
  /* takes a couple hours to run */
  /* excluded from replication runtime */
  // do $scode/a/block_individual_ed_coefplot.do

  /*************************************************************************/
  /* appendix figure A.13: Individual Educational Attainment (No Controls) */
  /*************************************************************************/
  /* note resist the temptation to combine the two lengthy coefplot do files, they take a while to run
  and have specific labels that need to be changed with every edit. Handle them separately.*/
  /* excluded from replication runtime */
  // do $scode/a/block_individual_ed_no_control_coefplot.do

  /**********/
  /* Tables */
  /**********/
  /****************************************/
  /* tables 7 and 8: Individual ed tables */
  /****************************************/
  /* excluded from replication runtime */
  // do $scode/a/table_block_individual_ed.do
  
  /*******************/
  /* Appendix Tables */
  /*******************/
  /*************************************************************/
  /* appendix table A.2 and A.3: Individual ed by demographics */
  /*************************************************************/
  /* excluded from replication runtime */
  // do $scode/a/table_block_individual_ed_demo.do
  
  /******************************/
  /* appendix table A.4 and A.5 */
  /******************************/
  /* excluded from replication runtime */
  // do $scode/a/table_block_individual_ed_age.do

}

/*****************/
/* Paper Figures */
/*****************/
/********************************/
/* figure 1: extent of segregation */
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
/*****************************/
do $scode/a/analyze_correlates.do

/************************************/
/* segregation vs service disparity */
/************************************/
do $scode/a/explore_seg_vs_service_disparity.do

/****************************************************************/
/* table and graphs with segregation time series from handbooks */
/****************************************************************/
do $scode/a/gen_dissim_pc0111.do

/*****************************************************/
/* figure 4: pg provision vs nbd mg share binscatter */
/*****************************************************/
do $scode/a/block_pg_share_binscatter_pub_dummy.do

// for the online appendix, add private goods too
do $scode/a/block_pg_share_binscatter_priv_dummy.do

// for the online appendix, add semi-private goods too
do $scode/a/block_pg_share_binscatter_semipriv.do

/*****************************************************************/
/* figure 5-6 & appendix figure A.7 & A.8: pe function visualise */
/*****************************************************************/
do $scode/a/graph_pe_functions.do

/*********************************************************************/
/* figure 7: pe function for urban wash amenities/infrastructure access */
/*********************************************************************/
do $scode/a/graph_pe_sanitation.do


/**********/
/* Tables */
/**********/
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
/* table 4 : dissim on town char regressions */
/*********************************************/
do $scode/a/city_dissim_town_char.do

/****************************************************************/
/* table 5,6,7: public good provision at the neighborhood level */
/****************************************************************/
do $scode/a/table_block_pg_share_educ_health.do

/****************************************************/
/* tables 7 & 8: look to fast == 0 block at the top */
/****************************************************/

/*********************/
/* Appendix Figures: */
/*********************/
/************************************************************/
/* appendix figure A.1: enumeration block groups distributions */
/************************************************************/
do $scode/a/block_group_pop_histogram_density.do

/***************************************************************/
/* appendix figure A.2: muslim(lstm) vs. muslim(pc11) correlation */
/***************************************************************/
do $scode/a/city_share_muslim_pc_classify.do

/*********************************************************/
/* appendix figure A.3: MG Pop distribution in MG share nbd */
/*********************************************************/
do $scode/a/graph_group_shares.do

/********************************************************/
/* appendix figure A.4: Comparision on India Seg vs US Seg */
/********************************************************/
do $scode/a/city_seg_iso_density_india_us.do

/***********************************/
/* appendix figure A.5: lowess graphs */
/***********************************/
do $scode/a/fig_lowess_city_age.do

/*************************************************************/
/* appendix figure A.6: log emp secondary school binscatters */
/*************************************************************/
do $scode/a/block_pg_share_binscatter_pub_log_emp.do
// for the online appendix, add private goods too
do $scode/a/block_pg_share_binscatter_priv_log_emp.do

/*******************/
/* Appendix Tables */
/*******************/
/**************************************************/
/* appendix table A.1: nbd pg in and out of slums */
/**************************************************/
do $scode/a/table_block_pg_share_educ_health_slum.do

/************************************************************/
/* appendix table: nbd regs controlling for nbd consumption */
/************************************************************/
do $scode/a/pg_inequality_w_controls.do

/***************************************************************/
/* appendix table: PG supply, intersectionality of Muslim * SC */
/***************************************************************/
do $scode/a/pg_intersection.do


/*****************/
/* Save End Time */
/*****************/
global analysis_end_time "$S_DATE $S_TIME"
di  "Make File Analysis started at: $analysis_start_time"
di "Make File Analysis ended at: $analysis_end_time"
