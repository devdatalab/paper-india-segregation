/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_blockdata_`loc'_200.dta                 */
/* OUTPUTS:                                                            */
/*   - $tmp/a/tables/sum_stats_tbl.csv                                 */
/*   - $out/sum_stats_tbl_200.tex                                      */
/* GOAL:                                                               */
/*   Build summary statistics table for block-level data.               */
/*                                                                     */
/* create the summary statistics table                                 */
/***********************************************************************/

/**************************************/
/* generate demographic summary stats */
/**************************************/
/* loop over loc */
foreach loc in rural urban {
  
  /* Load `loc' data*/
  use $tmp/secc/segregation_blockdata_`loc'_200.dta, clear

  /* make tmp directory where all csv files are stored */
  cap mkdir $tmp/a/
  cap mkdir $tmp/a/tables
  
  /* loop over demographics */
  foreach demo in sc muslim {
    
    /* create summary stats */
    /***********************/
    /* SC and Muslim Share */
    /***********************/
    /* Mean Share */
    qui sum `demo'_share, d
    insert_into_file using $tmp/a/tables/sum_stats_tbl.csv, key(`demo'_share_block_`loc'_mean) value(`r(mean)') format(%8.2f)

    /* sd share */
    qui sum `demo'_share, d
    insert_into_file using $tmp/a/tables/sum_stats_tbl.csv, key(`demo'_share_block_`loc'_sd) value(`r(sd)') format(%8.2f)

    /* count share */
    qui sum `demo'_share, d
    insert_into_file using $tmp/a/tables/sum_stats_tbl.csv, key(`demo'_share_block_`loc'_n) value(`r(N)') format(%8.0f)

    /**************/
    /* Population */
    /**************/
    /* mg population mean */
    qui sum block_pop_`demo', d
    insert_into_file using $tmp/a/tables/sum_stats_tbl.csv, key(`demo'_block_`loc'_mean) val(`r(mean)') format(%10.0f)

    /* mg population sd */
    qui sum block_pop_`demo', d
    insert_into_file using $tmp/a/tables/sum_stats_tbl.csv, key(`demo'_block_`loc'_sd) val(`r(sd)') format(%10.0f)

    /* mg population counts*/
    qui sum block_pop_`demo', d
    insert_into_file using $tmp/a/tables/sum_stats_tbl.csv, key(`demo'_block_`loc'_n) value(`r(N)') format(%8.0f)
  }

  /********************/
  /* Total Population */
  /********************/
  qui sum block_pop, d
  insert_into_file using $tmp/a/tables/sum_stats_tbl.csv, key(block_`loc'_n) val(`r(N)') format(%8.0f)

  /* total poplation mean */
  qui sum block_pop, d
  insert_into_file using $tmp/a/tables/sum_stats_tbl.csv, key(block_`loc'_mean) val(`r(mean)') format(%10.0f)

  /* total poplation sd */
  qui sum block_pop, d
  insert_into_file using $tmp/a/tables/sum_stats_tbl.csv, key(block_`loc'_sd) val(`r(sd)') format(%10.0f)

  /**************************/
  /* Per Capita Consumption */
  /**************************/
  /* loop over demoraphics */
  foreach demo in sc muslim nonscmuslim {
    
    /* calculte consumption for mg groups */
    /* consumption mg mean */
    qui sum cons_pcap_`demo'
    insert_into_file using $tmp/a/tables/sum_stats_tbl.csv, key(block_`demo'_`loc'_cons_mean) val(`r(mean)') format(%10.0f)
    
    /* consumption mg sd */
    qui sum cons_pcap_`demo'
    insert_into_file using $tmp/a/tables/sum_stats_tbl.csv, key(block_`demo'_`loc'_cons_sd) val(`r(sd)') format(%10.0f)

    /* consumption mg total units */
    qui sum cons_pcap_`demo'
    insert_into_file using $tmp/a/tables/sum_stats_tbl.csv, key(block_`demo'_`loc'_cons_n) val(`r(N)') format(%10.0f)
  }


  /************************************************/
  /* Block Level Public and Private Goods Dummies */
  /************************************************/
  /* loop over public goods provision */
  foreach pg in dum_primary_pub dum_secondary_pub dum_hospital_pub dum_primary_priv dum_secondary_priv dum_hospital_priv {
    
    /* calculat pg provision for mg */
    /* calculate public goods provision mean */
    qui sum `pg' 
    insert_into_file using $tmp/a/tables/sum_stats_tbl.csv, key(block_`loc'_`pg'_mean) val(`r(mean)') format(%10.2f)
    
    /* calculate public goods provision sd */
    qui sum `pg' 
    insert_into_file using $tmp/a/tables/sum_stats_tbl.csv, key(block_`loc'_`pg'_sd) val(`r(sd)') format(%10.2f)
  }

  /******************************************/
  /* Add Semi-Private Goods for Urban Areas */
  /******************************************/
  if "`loc'" == "urban" {

    /* loop over semi-private goods */
    foreach pg in closed_drain light_source_elec wat_source_home {

      /* calculat pg provision for mg */
      /* calculate public goods provision mean */
      qui sum `pg' 
      insert_into_file using $tmp/a/tables/sum_stats_tbl.csv, key(block_`loc'_`pg'_mean) val(`r(mean)') format(%10.2f)
      
      /* calculate public goods provision sd */
      qui sum `pg' 
      insert_into_file using $tmp/a/tables/sum_stats_tbl.csv, key(block_`loc'_`pg'_sd) val(`r(sd)') format(%10.2f)
    }
  }
}

/*****************************/
/* Transfer Results to Table */
/*****************************/
table_from_tpl, t($scode/a/tpl/table_1_sum_stats_all_tpl.tex) r($tmp/a/tables/sum_stats_tbl.csv) o($out/sum_stats_tbl_200.tex)
