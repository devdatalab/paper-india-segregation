/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_blockdata_`loc'_`bgroup'.dta            */
/* OUTPUTS:                                                            */
/*   - $tmp/a/tables/neighborhood_public_goods_reg.csv                 */
/*   - $tmp/a/tables/neighborhood_private_goods_reg.csv                */
/*   - $out/nbd_pg_share_`loc'_`bgroup'.tex                             */
/*   - $out/nbd_privg_share_`loc'_`bgroup'.tex                          */
/*   - $out/nbd_wash_mean_urban_200.tex                                */
/* GOAL:                                                               */
/*   Estimate PG/education/health regressions vs minority shares.       */
/*                                                                     */
/* Make a public goods with health/educ variables regressed on          */
/* minority group shares                                               */
/***********************************************************************/

/**********************/
/* Public Good Tables */
/**********************/
/* loop over block group sizes */
foreach bgroup in 200 4000 {

  /* loop over urban/rural */
  foreach loc in rural urban {

    /* load block data */
    use $tmp/secc/segregation_blockdata_`loc'_`bgroup', clear

    /* create tmp directory to store csv of results */
    cap mkdir $tmp/a/
    cap mkdir $tmp/a/tables
    
    /* define locals for fixed efects: town or subdistrict */
    if "`loc'" == "rural" local upper subdistrict
    if "`loc'" == "urban" local upper town
    
    /* town over public goods dummy */
    foreach pg in primary secondary hospital {

      areg dum_`pg'_pub sc_share  muslim_share log_block_pop , absorb(`upper') r
      store_est_tpl using $tmp/a/tables/neighborhood_public_goods_reg.csv, coef(sc_share) name(sc_dum_`pg'_`bgroup') all
      store_est_tpl using $tmp/a/tables/neighborhood_public_goods_reg.csv, coef(muslim_share) name(muslim_dum_`pg'_`bgroup') all
      insert_into_file using $tmp/a/tables/neighborhood_public_goods_reg.csv, key(dum_n_`pg'_`bgroup') val(`e(N)') format(%10.0f)
      sum dum_`pg'_pub if e(sample)         
      local mean: di %4.3f `r(mean)'
      di "`mean'"
      insert_into_file using $tmp/a/tables/neighborhood_public_goods_reg.csv, key(dum_mean_`pg'_`bgroup') val("`mean'")  format(%10.2f)
    }

    /* loop over public goods log employment */
    foreach pg in primary secondary hospital {

      areg log_`pg'_emp_pub sc_share  muslim_share log_block_pop , absorb(`upper') r
      store_est_tpl using $tmp/a/tables/neighborhood_public_goods_reg.csv, coef(sc_share) name(sc_log_`pg'_`bgroup') all
      store_est_tpl using $tmp/a/tables/neighborhood_public_goods_reg.csv, coef(muslim_share) name(muslim_log_`pg'_`bgroup') all
      insert_into_file using $tmp/a/tables/neighborhood_public_goods_reg.csv, key(log_n_`pg'_`bgroup') val(`e(N)') format(%10.0f)
      sum log_`pg'_emp_pub if e(sample)         
      local mean: di %4.3f `r(mean)'
      insert_into_file using $tmp/a/tables/neighborhood_public_goods_reg.csv, key(log_mean_`pg'_`bgroup') val("`mean'") format(%10.2f)
    }

    table_from_tpl , t($scode/a/tpl/table_neighborhood_public_goods_reg_`loc'_`bgroup'_tpl.tex) r($tmp/a/tables/neighborhood_public_goods_reg.csv) o($out/nbd_pg_share_`loc'_`bgroup'.tex)    
  }
}

/***********************/
/* Private Good Tables */
/***********************/
/* loop over neighborhood size */
foreach bgroup in 200 4000 {

  /* loop over urban/rural */
  foreach loc in rural urban {

    /* load block data */
    use $tmp/secc/segregation_blockdata_`loc'_200, clear

    /* create tmp directory to store csv of results */
    cap mkdir $tmp/a/
    cap mkdir $tmp/a/tables
    
    /* define locals for fixed efects: town or subdistrict */
    if "`loc'" == "rural" local upper subdistrict
    if "`loc'" == "urban" local upper town
    
    /* town over public goods dummy */
    foreach pg in primary secondary hospital {

      areg dum_`pg'_priv sc_share  muslim_share log_block_pop , absorb(`upper') r
      store_est_tpl using $tmp/a/tables/neighborhood_private_goods_reg.csv, coef(sc_share) name(sc_dum_`pg'_`bgroup') all
      store_est_tpl using $tmp/a/tables/neighborhood_private_goods_reg.csv, coef(muslim_share) name(muslim_dum_`pg'_`bgroup') all
      insert_into_file using $tmp/a/tables/neighborhood_private_goods_reg.csv, key(dum_n_`pg'_`bgroup') val(`e(N)') format(%10.0f)
      sum dum_`pg'_priv if e(sample)         
      local mean: di %4.3f `r(mean)'
      di "`mean'"
      insert_into_file using $tmp/a/tables/neighborhood_private_goods_reg.csv, key(dum_mean_`pg'_`bgroup') val("`mean'") format(%10.2f)
    }

    /* loop over public goods log employment */
    foreach pg in primary secondary hospital {

      areg log_`pg'_emp_priv sc_share  muslim_share log_block_pop , absorb(`upper') r
      store_est_tpl using $tmp/a/tables/neighborhood_private_goods_reg.csv, coef(sc_share) name(sc_log_`pg'_`bgroup') all
      store_est_tpl using $tmp/a/tables/neighborhood_private_goods_reg.csv, coef(muslim_share) name(muslim_log_`pg'_`bgroup') all
      insert_into_file using $tmp/a/tables/neighborhood_private_goods_reg.csv, key(log_n_`pg'_`bgroup') val(`e(N)') format(%10.0f)
      sum log_`pg'_emp_priv if e(sample)         
      local mean: di %4.3f `r(mean)'
      insert_into_file using $tmp/a/tables/neighborhood_private_goods_reg.csv, key(log_mean_`pg'_`bgroup') val("`mean'") format(%10.2f)
    }
    table_from_tpl , t($scode/a/tpl/table_neighborhood_public_goods_reg_`loc'_`bgroup'_tpl.tex) r($tmp/a/tables/neighborhood_private_goods_reg.csv) o($out/nbd_privg_share_`loc'_`bgroup'.tex)     
  }
}

/************************************/
/* Urban Infrastructure Regressions */
/************************************/
/* load block data */
use $tmp/secc/segregation_blockdata_urban_200, clear

/* town over public goods dummy */
foreach pg in closed_drain wat_source_home light_source_elec {
  /* Regress with and without cons controls */
  eststo `pg'_1: areg `pg' sc_share  muslim_share log_block_pop , absorb(town) r
  estadd ysumm
}

/* label vars */
label var sc_share "SC Share"
label var muslim_share "Muslim Share"

estout closed_drain_1  wat_source_home_1 light_source_elec_1 using $out/nbd_wash_mean_urban_200.tex, ///
    cells(b(star fmt(%10.3f))  se(par("(" ")")) ) stats(N ymean, fmt(%10.0f %10.2f) label("Observations" "Mean of Dependent Variable")) style(tex) replace label ///
    keep(sc_share muslim_share) order(sc_share muslim_share) ///
    mlabel("Closed Drainage" "Piped Water"  "Electric Light") ///
    collabels(,none) prefoot("\hline") postfoot("Town FE & Yes & Yes & Yes \\" "\hline\hline" "\end{tabular}" "}") prehead("{" "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" ///
    "\begin{tabular}{l*{4}{c}}" "\hline" "\hline") posthead("\hline")
