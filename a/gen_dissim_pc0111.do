/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $raw/clean/handbooks/pc01_pdf_eb_clean.dta                     */
/*   - $raw/clean/handbooks/pc11_pdf_eb_clean.dta                     */
/*   - $raw/clean/handbooks/pc01_pdf_shrid_key.dta                    */
/*   - $raw/clean/handbooks/pc11_pdf_shrid_key.dta                    */
/*   - $tmp/secc/segregation_citydata_urban_200.dta                  */
/* OUTPUTS:                                                            */
/*   - $raw/clean/handbooks/pc01_pdf_shrid_dissim.dta                 */
/*   - $raw/clean/handbooks/pc11_pdf_shrid_dissim.dta                 */
/*   - $raw/clean/segregation_pc0111.dta                              */
/*   - $tmp/seg_pc0111.dta                                              */
/*   - $tmp/a/tables/seg_time.csv                                       */
/*   - $out/seg_time.tex                                                */
/* GOAL:                                                               */
/*   Compute PC01/PC11 dissimilarity series and compare to SECC.        */
/*                                                                     */
/* This do file generates dissimilarity and isolation measures for all */
/* towns from 2011 and 2001 eb data                                    */
/* 1. First it cleans 2001 eb data, calculates dissimilarity and       */
/*    isolation at the shrid level and saves this dataset              */
/* 2. Clean 2011 eb data, calculate dissimilarity and isolation and    */
/*    save this dataset                                                */
/* 3. Merge 2011 and 2001 data from 1 and 2 above on shrid              */
/* 4. Merge 2011 shrid dissimilarity with SECC shrid dissimilarity     */
/*    (to check how correlated it is)                                 */
/*                                                                     */
/* Note: Since the District handbooks only have, total, sc and st       */
/* population, we can get the sc dissimilarity but not the muslim       */
/* dissimilarity                                                      */
/***********************************************************************/

cap mkdir $tmp/handbooks

/***************************************/
/* Clean 2001 Shrid Dissimilarity Data */
/***************************************/
/* use clean eb data */
use $raw/clean/handbooks/pc01_pdf_eb_clean, clear

/* generate non-sc population */
gen pop_nonsc = pop_tot - pop_sc

/* drop negative values of pop_nonsc */
/* This drops about 30 towns in the collapsed dataset as compared to $raw/clean/handbooks/pc01_pdf_town_clean */
drop if pop_nonsc < 0

/* drop impossible sc shares */
drop if pop_sc > pop_tot & !mi(pop_sc)
drop if pop_st > pop_tot & !mi(pop_st)

/* keep enumeration blocks sized between 200 and 1200, consistent with our main analysis */
keep if inrange(pop_tot, 200, 1200)

/* drop locations missing town names */
drop if mi(town_name)

/* prepare dataset for merging with the pc01_shrid_key */
rename town_name town_name_pc01_pdf
label var town_name_pc01_pdf "PC01 Town Name in the PDF"

/* turn the town_name from strL to str#  */
gen len = length(town_name_pc01_pdf)
summ len, d
recast str100 town_name_pc01_pdf, force

/* merge with shrid keys */
merge m:1 town_name_pc01_pdf using $raw/clean/handbooks/pc01_pdf_shrid_key
keep if _merge == 3
drop _merge

/* drop older pdf from the key*/
drop pdf_*

/* generate dissimilarity and isolation measures */
gen_dissimilarity, min(pop_sc) maj(pop_nonsc) gen(city_dissim_sc_pc01) label("SC Dissimilarity PC 2001") upper(shrid)
gen_isolation, min(pop_sc) maj(pop_nonsc) gen(city_iso_sc_pc01) label("SC Isolation PC 2001") upper(shrid)

/* generate a variable to hold number of blocks used in each city for the measure */
gen block_count_2001 = 1

/* collapse data to town level */
collapse (first) city_dissim_sc_pc01 city_iso_sc_pc01  pc01_pca_tot_p pc01_pca_p_sc (sum) pop_tot pop_sc block_count_2001, by(shrid)

/* drop towns with fewer than 4 blocks (consistent with what we do in the SECC) */
drop if block_count_2001 < 4

/* drop if no sc population in towns */
drop if pop_sc == 0

/* rename eb pop variables */
ren pop_tot eb_pop_tot_2001
ren pop_sc  eb_pop_sc_2001


/*  generate variable to track differences in population of extracted city and pc01 city */
gen diff_tot_pop01  = abs(pc01_pca_tot_p - eb_pop_tot_2001) / pc01_pca_tot_p
gen pdiff_tot_pop01 = eb_pop_tot_2001 / pc01_pca_tot_p

count if diff_tot_pop01 == 0
count if diff_tot_pop01 < 0.05

/* label and save dataset */
label var diff_tot_pop01 "Total population difference between district handbook and pc01 pca"
label var pdiff_tot_pop01 "District handbook 2001 EB pop / PC01 pop"

/* save the clean 2001 dissimilarity data */
save $tmp/handbooks/pc01_pdf_shrid_dissim, replace

/***************************************/
/* Clean 2011 Shrid Dissimilarity Data */
/***************************************/
/* use clean eb data */
use $raw/clean/handbooks/pc11_pdf_eb_clean, clear

/* replpace missing pop_sc's with zeroes */
replace pop_sc = 0 if mi(pop_sc)

/* drop blocks with missing populations */
drop if mi(pop_tot)

/* generate non-sc population */
gen pop_nonsc = pop_tot - pop_sc

/* drop negative values of pop_nonsc */
/* This drops about 30 towns in the collapsed dataset as compared to $raw/clean/handbooks/pc11_pdf_town_clean */
drop if pop_nonsc < 0

/* drop impossible sc shares */
drop if pop_sc > pop_tot & !mi(pop_sc)
drop if pop_st > pop_tot & !mi(pop_st)

/* keep enumeration blocks sized between 200 and 1200, consistent with our main analysis */
keep if inrange(pop_tot, 200, 1200)

/* drop locations missing town names */
drop if mi(town_name)

/* prepare dataset for merging with the pc11_shrid_key */
rename town_name town_name_pc11_pdf
label var town_name_pc11_pdf "PC11 Town Name in the PDF"

/* turn the town_name from strL to str#  */
gen len = length(town_name_pc11_pdf)
summ len, d
recast str100 town_name_pc11_pdf, force

/* merge with shrid keys */
merge m:1 town_name_pc11_pdf using $raw/clean/handbooks/pc11_pdf_shrid_key
keep if _merge == 3
drop _merge

/* generate dissimilarity and isolation measures */
gen_dissimilarity, min(pop_sc) maj(pop_nonsc) gen(city_dissim_sc_pc11) label("SC Dissimilarity PC 2011") upper(shrid)
gen_isolation, min(pop_sc) maj(pop_nonsc) gen(city_iso_sc_pc11) label("SC Isolation PC 2011") upper(shrid)

/* generate a variable to hold number of blocks used in each city for the measure */
gen block_count_2011 = 1

/* collapse data to town level */
collapse (first) city_dissim_sc_pc11 city_iso_sc_pc11 pc11_pca_tot_p pc11_pca_p_sc (sum) pop_tot pop_sc block_count_2011, by(shrid)

/* drop towns with fewer than 4 blocks (consistent with what we do in the SECC) */
drop if block_count_2011 < 4

/* drop if no sc population in towns */
drop if pop_sc == 0

/* rename eb pop variables */
ren pop_tot eb_pop_tot_2011
ren pop_sc  eb_pop_sc_2011

/*  generate variable to track differences in population of extracted city and pc11 city */
gen diff_tot_pop11 = abs(pc11_pca_tot_p - eb_pop_tot_2011) / pc11_pca_tot_p
gen pdiff_tot_pop11 = eb_pop_tot_2011 / pc11_pca_tot_p

count if diff_tot_pop11 == 0
count if diff_tot_pop11 < 0.05

/* label and save dataset */
label var diff_tot_pop11 "Absolute value of proportional population difference between pc11 pca and dist handbook"
label var pdiff_tot_pop11 "District handbook 2011 EB pop / PC11 pop"

/* save the clean 2011 dissimilarity data */
save $tmp/handbooks/pc11_pdf_shrid_dissim, replace
/* 6195 towns in pc11 data */



/***********************************/
/* Merge in pc01 data to pc11 data */
/***********************************/
/* ---------------------------- cell:  ---------------------------- */
use $tmp/handbooks/pc11_pdf_shrid_dissim, clear
merge 1:1 shrid using $tmp/handbooks/pc01_pdf_shrid_dissim
keep if _merge == 3
drop _merge

/* assert dataset is clean and ready for analysis */
assert eb_pop_sc_2001 != 0 & eb_pop_sc_2011 != 0
assert block_count_2001 >= 4 & block_count_2011 >= 4
assert city_dissim_sc_pc01 != 0 & city_dissim_sc_pc11 != 0

/* drop places where handbook population is 1.2x greater than PCA or more ---
   we've assigned too many incorrect neighborhoods to these places. */
drop if pdiff_tot_pop01 > 1.2 | pdiff_tot_pop11 > 1.2

/* calculate log city population for the X axis of lowess graphs */
gen ln_pop_01 = ln(pc01_pca_tot_p )
gen ln_pop_11 = ln(pc11_pca_tot_p )

/* review how the block count changes across years */
gen ln_bcount_2001 = ln(block_count_2001)
gen ln_bcount_2011 = ln(block_count_2011)
gen block_diff = block_count_2011 / block_count_2001
scatter ln_bcount_2011 ln_bcount_2001
graphout block_count_persistence_2001_2011

/* generate match quality flags internal to each year -- based on match between total population in 2001 and 2011 */
gen match_exact = pdiff_tot_pop11 == 1 & pdiff_tot_pop01 == 1
label var match_exact "Exact match in handbook and pca population"

gen match_5 = inrange(pdiff_tot_pop11, 0.95, 1.05) & inrange(pdiff_tot_pop01, 0.95, 1.05)
label var match_5 "Match within 5% in handbook and pca population"

gen match_50 = inrange(pdiff_tot_pop11, 0.5, 2) & inrange(pdiff_tot_pop01, 0.5, 2)
label var match_50 "Match within 50% of PCA population"

/* calculate weights as total SC populations */
gen wt01 = pc01_pca_p_sc
gen wt11 = pc11_pca_p_sc

/* define 5 samples in which we do the comparison */

/* sample 1: all places */
gen sample1 = 1

/* sample 2: population match for both sources within 5% of pca */
gen sample2 = match_5

/* sample 3: population match within 50% */
gen sample3 = match_50

/* sample 4: within 5% on population and 50% on block count */
gen sample4 = match_5  & inrange(block_diff, .5, 2)

/* sample 5: within 5% on population and 20% on block count */
gen sample5 = match_5  & inrange(block_diff, .8, 1.25)

/* drop unnecessary variables */
drop diff*

/* get town names into the dataset */
merge 1:1 shrid using $shrug/keys/shrug_names, keepusing(place_name)
keep if _merge == 3
drop _merge

/* calculate change measures */
gen dissim_change = city_dissim_sc_pc11 - city_dissim_sc_pc01
gen iso_change = city_iso_sc_pc11 - city_iso_sc_pc01
save $tmp/seg_pc0111, replace

/* merge to the full shrug to understand the sample coverage */
merge 1:1 shrid using $shrug/data/shrug_pc11_pca, keepusing(pc11_pca_tot_p pc11_sector)
drop if pc11_sector == 2

/* compare matches */
gen match = _merge == 3
tabstat pc11_pca_tot_p , by(match) s(mean sd p5 p25 p50 p75 p95)

/* generate a polynomial weight function based on population  */
gen ln_pop = ln(pc11_pca_tot_p )
gen ln_pop2 = ln_pop^3
gen ln_pop3 = ln_pop^4
gen ln_pop4 = ln_pop^5
gen ln_pop5 = ln_pop^6
reg match ln_pop ln_pop2 ln_pop3 ln_pop4 ln_pop5
predict match_hat
winsorize match_hat 0 1, replace

/* the "sample weight" corrects the sample for the over-representation of big cities */
gen wt = 1 / match_hat

/* plot the match functions */
binscatter match_hat match ln_pop, linetype(none)
graphout pc0111_match

/* drop the SHRUG locations not in the current dataset */
keep if _merge == 3
drop _merge pc11_sector match ln_pop-ln_pop5

/* save the dissimilarity comparison dataset */
order shrid *dissim*
save $tmp/segregation_pc0111, replace

/* ---------------------------- cell: difference in mean dissimilarity and isolation------- */
use $tmp/segregation_pc0111, clear

/* we use the "sample weights" for the main spec; the "weighted" spec takes these sample weights
   and multiplies by SC and Muslim shares to reflect marginalized group experiences. */

/* reweight the SC populations with the "sampling weights" */
replace wt01 = wt01 * wt
replace wt11 = wt11 * wt

/* loop over dissimilarity and isolation indices */
foreach m in dissim iso {

  local name_dissim "Dissimilarity"
  local name_iso "Isolation"
  
  disp_nice "`name_`m''"
  
  /* calculate dissimilarity in both years under each measure */
  forval s = 2/3 {
  
    qui {  

      /* calculate unweighted measure (2001) */
      sum city_`m'_sc_pc01 [aw=wt] if sample`s' == 1
      local mean_01_nowt_s`s': di %5.3f `r(mean)'
      
      /* calculate unweighted measure (2011) */
      sum city_`m'_sc_pc11 [aw=wt] if sample`s' == 1
      local mean_11_nowt_s`s': di  %5.3f `r(mean)'
      local n_s`s': di  %5.0f `r(N)'

      /* calculate difference (unweighted) */
      local diff_nowt_s`s': di %5.3f (`mean_11_nowt_s`s'' - `mean_01_nowt_s`s'')
      
      /* calculate weighted measure (2001) */
      sum city_`m'_sc_pc01 [aw=wt01] if sample`s' == 1
      local mean_01_wt_s`s': di  %5.3f `r(mean)'
      
      /* calculate weighted measure (2011) */
      sum city_`m'_sc_pc11 [aw=wt11] if sample`s' == 1
      local mean_11_wt_s`s': di  %5.3f `r(mean)'

      /* calculate difference (weighted) */
      local diff_wt_s`s': di %5.3f (`mean_11_wt_s`s'' - `mean_01_wt_s`s'')
    }
    /* report results */
    di "Sample `s' nowt (2011 minus 2001): `mean_11_nowt_s`s'' -  `mean_01_nowt_s`s'' = " %5.3f (`diff_nowt_s`s'') " (`n_s`s'')"
    di "Sample `s'   wt (2011 minus 2001): `mean_11_wt_s`s'' -  `mean_01_wt_s`s'' = "     %5.3f (`diff_wt_s`s'')   " (`n_s`s'')"
  }
}

/* ---------------------------- cell:  ---------------------------- */



/* save disimilarity and isolation measures to csv to make a table in stata-tex */
/* loop over segregation measures */
foreach seg in dissim iso {

  /* loop over precise and full sample results */
  forval s = 2/3 {

    /* calculate unweighted segregation measures for 2001 */
    sum city_`seg'_sc_pc01 if sample`s' == 1
    local pc01_`seg'_`s'_uwtd : di %5.3f `r(mean)'
    insert_into_file using $tmp/a/tables/seg_time.csv, key(pc01_`seg'_`s'_uwtd) val(`pc01_`seg'_`s'_uwtd') format(%5.3f)

    /* calculate unweighted segregation measures for 2011 */
    sum city_`seg'_sc_pc11 if sample`s' == 1
    local pc11_`seg'_`s'_uwtd : di %5.3f `r(mean)'
    insert_into_file using $tmp/a/tables/seg_time.csv, key(pc11_`seg'_`s'_uwtd) val(`pc11_`seg'_`s'_uwtd') format(%5.3f)


    /* calculate weighted and unweighted sample */
    sum city_`seg'_sc_pc11 if sample`s' == 1
    insert_into_file using $tmp/a/tables/seg_time.csv, key(sample_`s') val(`r(N)') format(%5.0f)

    /* calculate weighted segregation measures for 2001 */
    sum city_`seg'_sc_pc01 [aw=wt01] if sample`s' == 1
    local pc01_`seg'_`s'_wtd : di %5.3f `r(mean)'
    insert_into_file using $tmp/a/tables/seg_time.csv, key(pc01_`seg'_`s'_wtd) val(`pc01_`seg'_`s'_wtd') format(%5.3f)

    /* calculate weighted segregation measures for 2011 */
    sum city_`seg'_sc_pc11 [aw = wt11] if sample`s' == 1
    local pc11_`seg'_`s'_wtd : di %5.3f `r(mean)'    
    insert_into_file using $tmp/a/tables/seg_time.csv, key(pc11_`seg'_`s'_wtd) val(`pc11_`seg'_`s'_wtd') format(%5.3f)

    /* save diferences: no weights */
    local diff_`seg'_`s'_uwtd: di %5.3f (`pc11_`seg'_`s'_uwtd' - `pc01_`seg'_`s'_uwtd')
    insert_into_file using $tmp/a/tables/seg_time.csv, key(diff_`seg'_`s'_uwtd) val(`diff_`seg'_`s'_uwtd') format(%5.3f)
    
    /* save diferences: weights */
    local diff_`seg'_`s'_wtd: di %5.3f (`pc11_`seg'_`s'_wtd' - `pc01_`seg'_`s'_wtd')
    insert_into_file using $tmp/a/tables/seg_time.csv, key(diff_`seg'_`s'_wtd) val(`diff_`seg'_`s'_wtd') format(%5.3f)
  }
}

/* make table */
table_from_tpl, t($scode/a/tpl/seg_time_tpl.tex) r($tmp/a/tables/seg_time.csv) o($out/seg_time.tex)




/* ---------------------------- cell: graph of segregation change vs. city size ---------- */
use $tmp/segregation_pc0111, clear

/* set lpoly parameters */
local polyparams deg(1) bwidth(.5)
local graphparams ylabel(0(.1).7) legend(lab(1 "2001") lab(2 "2011") ring(0) pos(5) region(lwidth(medthick) lcolor(black)) size(large)) xtitle("Log City Population in 2001", size(large)) 
local line1 lwidth(medthick) lpattern(dash) lcolor("237 108 82")
local line2 lwidth(medthick) lpattern(solid) lcolor(black)

/* graph dissimilarity for each year, for very good and good match samples */
twoway ///
    (lpoly city_dissim_sc_pc01 ln_pop_01 [aw=pc01_pca_p_sc] if sample2, `line1' `polyparams') ///
    (lpoly city_dissim_sc_pc11 ln_pop_01 [aw=pc01_pca_p_sc] if sample2, `line2' `polyparams'), ///
    `graphparams' ytitle("Dissimilarity Index", size(large))
graphout dissim_over_time_sample2, pdf

twoway ///
    (lpoly city_dissim_sc_pc01 ln_pop_01 [aw=pc01_pca_p_sc] if sample3, `line1' `polyparams') ///
    (lpoly city_dissim_sc_pc11 ln_pop_01 [aw=pc01_pca_p_sc] if sample3, `line2' `polyparams'), ///
    `graphparams' ytitle("Dissimilarity Index", size(large))
graphout dissim_over_time_sample3, pdf

/* repeat for isolation */
twoway ///
    (lpoly city_iso_sc_pc01 ln_pop_01 [aw=pc01_pca_p_sc] if sample2, `line1' `polyparams') ///
    (lpoly city_iso_sc_pc11 ln_pop_01 [aw=pc01_pca_p_sc] if sample2, `line2' `polyparams'), ///
    `graphparams' ytitle("Isolation Index", size(large))
graphout iso_over_time_sample2, pdf

twoway ///
    (lpoly city_iso_sc_pc01 ln_pop_01 [aw=pc01_pca_p_sc] if sample3, `line1' `polyparams') ///
    (lpoly city_iso_sc_pc11 ln_pop_01 [aw=pc01_pca_p_sc] if sample3, `line2' `polyparams'), ///
    `graphparams' ytitle("Isolation Index", size(large))
graphout iso_over_time_sample3, pdf

/* ---------------------------- cell: Try some less outlier-sensitive comparisons ---------------------------- */

/* count the share of cities where dissimilarity fell (i.e. improved)  */
gen less_dissim = city_dissim_sc_pc11 < city_dissim_sc_pc01

tab less_dissim if sample2
tab less_dissim if sample3

/* count the share of cities where isolation fell (i.e. improved)  */
gen less_iso = city_iso_sc_pc11 < city_iso_sc_pc01

tab less_iso if sample2
tab less_iso if sample3

/* ---------------------------- cell: Check representativeness of time series sample------------------------ */
use $tmp/segregation_pc0111, clear

/* drop fields that we want to get from the full PC11 PCA */
drop pc11_pca_tot_p pc11_pca_p_sc

/* get PCA11 demographic data from Shrug1 */
merge 1:1 shrid using $shrug/data/shrug_pc11_pca, keepusing(pc11_pca_tot_p pc11_pca_p_sc pc11_pca_p_st pc11_pca_p_06 pc11_sector)

/* get latitude/longitude from Shrug1 */
merge 1:1 shrid using $shrug/data/shrug_spatial, keepusing(latitude longitude) keep(match master) nogen

/* get state names */
merge 1:1 shrid using $shrug/keys/shrug_pc11_state_key, keepusing(pc11_state_id pc11_state_name) keep(match master) nogen

/* generate demographic shares */
gen sc_share = pc11_pca_p_sc / pc11_pca_tot_p
gen st_share = pc11_pca_p_st / pc11_pca_tot_p
gen kid_share = pc11_pca_p_06 / pc11_pca_tot_p
gen ln_pop = ln(pc11_pca_tot_p)

/* keep only the PC11 towns */
keep if pc11_sector == 1

/* rename merge -> match, to have a binary variable that describes the match */
recode _merge 2=0 3=1
ren _merge match
label drop _merge

/* check sample coverage */
tabstat pc11_pca_tot_p , by(match) s(mean n)

tabstat pc11_pca_tot_p sc_share st_share kid_share, by(match)

/* show pop density function of matched vs unmatched cities  */
twoway (kdensity ln_pop if match == 0) (kdensity ln_pop if match == 1)
graphout x

/* show match rate by population */
binscatter match ln_pop, linetype(none)
graphout handbook_secc_match_pop

/* repeat for latitude and longitude */
binscatter match latitude, linetype(none)
graphout handbook_secc_match_lat
binscatter match longitude, linetype(none)
graphout handbook_secc_match_lon

/* review match rate by state */
tabstat match [aw=pc11_pca_tot_p], by(pc11_state_name)


/* ---------------------------- cell:  ---------------------------- */


/******************************************************/
/* Compare PC11 dissimilarity with SECC dissimilarity */
/******************************************************/

/* use pc11_shrid data */
use $tmp/handbooks/pc11_pdf_shrid_dissim, clear

/* create same sample quality definitions as above */
gen match_exact = pdiff_tot_pop11 == 1
label var match_exact "Exact match in handbook and pca population"

gen match_5 = inrange(pdiff_tot_pop11, 0.95, 1.05)
label var match_5 "Match within 5% in handbook and pca population"

gen match_50 = inrange(pdiff_tot_pop11, 0.5, 2)
label var match_50 "Match within 50% of PCA population"

/* merge in our primary dissimilarity and isolation stats */
merge 1:1 shrid using $tmp/secc/segregation_citydata_urban_200, keepusing(city_dissim_sc city_iso_sc) keep(match) nogen

/* drop zeroes before comparing */
drop if city_dissim_sc == 0 | city_dissim_sc_pc11 == 0

/* get correlations */
corr city_dissim_sc_pc11 city_dissim_sc if match_exact
corr city_dissim_sc_pc11 city_dissim_sc if match_5
corr city_dissim_sc_pc11 city_dissim_sc if match_50

/* repeat for isolation */
corr city_iso_sc_pc11 city_iso_sc if match_exact
corr city_iso_sc_pc11 city_iso_sc if match_5
corr city_iso_sc_pc11 city_iso_sc if match_50

/* scatterplot dissimilarity in district handbooks vs. in SECC */
label var city_dissim_sc_pc11 "PC11 dissimilarity"
label var city_dissim_sc "SECC Dissimilarity"
scatter city_dissim_sc_pc11 city_dissim_sc if match_5
graphout dissim_2011_internal_check
