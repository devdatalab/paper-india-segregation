/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $seg/us/census-tract-pop-2020.csv                                */
/*   - $seg/us/msa-level-pop-2020.csv                                   */
/*   - $seg/us/MSA_key.csv                                              */
/* OUTPUTS:                                                            */
/*   - $tmp/us/us_tract_pop.dta                                 */
/*   - $tmp/us/us_tpop_b.dta                                    */
/*   - $tmp/us/msa_keys.dta                                     */
/*   - $tmp/us/msa_tract_race_pop.dta                           */
/*   - $tmp/us/us_census_msa_dissim.dta                         */
/* GOAL:                                                               */
/*   Build US tract/MSA segregation inputs for cross-country analysis.  */
/*                                                                     */
/* DATA SOURCES                                                        */
/*                                                                     */
/* TRACT DATA:                                                         */
/* Source: 2020: DEC Redistricting Data (PL 94-171)                     */
/* Link: https://data.census.gov/table?g=010XX00US$1400000&tid=DECENNIALPL2020.P1 */
/*                                                                     */
/* MSA DATA:                                                           */
/* Source: 2020: DEC Redistricting Data (PL 94-171)                     */
/* Link: https://data.census.gov/table?g=010XX00US$31000M1              */
/*                                                                     */
/* MSA KEYS:                                                           */
/* Source: Delineation Files CBSAs, metropolitan divisions and CSAs     */
/* (Mar. 2020)                                                         */
/* Link: https://www.census.gov/geographies/reference-files/time-series/demo/metro-micro/delineation-files.html */
/***********************************************************************/

cap mkdir $tmp/us

/*************************************************/
/* CLEAN TRACT LEVEL DATA FROM THE CENSUS BUREAU */
/*************************************************/
/* load TRACT data */
import delimited using $seg/us/census-tract-pop-2020.csv, clear varnames(1)

/* ren vars */
ren *, lower

/* drop all columns with var annotions  */
drop *na v145

/* rename and clean total pop var */
ren (p1_001n name) (tract_total_pop tract_name)

/* there's a single observation for which all columns are strings because of csv structure*/
gen notnumeric = real(tract_total_pop) == .

/* drop that single obs so we can destring pop counts*/
drop if notnumeric == 1

/* destring total pop separately from the rest bc of var naming */
destring tract_total_pop, replace
destring p1_*n, replace

/* partition the data into 2 non-overlapping groups: black and non-black */
/* all race variables which contain "black"  */
egen tract_black_pop = rowtotal(p1_004n p1_011n p1_016n p1_017n p1_018n p1_019n p1_027n p1_028n p1_029n p1_030n p1_037n p1_038n p1_039n p1_040n p1_041n p1_042n p1_048n p1_049n p1_050n  p1_051n p1_052n p1_053n p1_058n p1_059n p1_060n p1_061n p1_064n p1_065n p1_066n p1_067n p1_069n p1_071n)

/* all variables that don't contain black */
egen tract_nonblack_pop = rowtotal(p1_003n p1_005n p1_006n p1_007n p1_008n p1_012n p1_013n p1_014n p1_015n p1_020n p1_021n p1_022n p1_023n p1_024n p1_025n p1_031n p1_032n p1_033n p1_034n p1_035n p1_036n p1_043n p1_044n p1_045n p1_046n p1_054n p1_055n p1_056n p1_057n p1_062n p1_068n)

/* reconstruct total pop by adding black + non-black groups */
gen total_pop = tract_black_pop + tract_nonblack_pop

/* make sure that constructed groups add up to total given by the data */
assert total_pop  == tract_total_pop

/***********************************************************************/
/* create vars for alternative definition of minority/majority samples */
/***********************************************************************/

/* define the black sample as black population only */
ren p1_004n tract_blackonly_pop

/* define the white sample as white population only */
ren p1_003n tract_whiteonly_pop

/* define the total pop as black + white only */
egen tract_total_pop_bw = rowtotal(tract_blackonly_pop tract_whiteonly_pop)

/* drop tracts with pop = 0 */
drop if tract_total_pop_bw == 0

/* split geo_id to later extract FIPS code  */
split geo_id, parse(US)

/* keep only FIPS part (first 5 nrs in geo2) */
gen fips_code = substr(geo_id2, 1,5)

/* create state-level FIPS code (first 2 nrs) to drop PR from sample */
gen fipsstatecode = substr(fips_code, 1,2)
drop if fipsstatecode == "72"

/* keep only vars of interest */
keep geo_id tract_total_pop tract_total_pop_bw tract_nonblack_pop tract_black_pop tract_blackonly_pop tract_whiteonly_pop fips_code 

/* rename geo_id  */
ren geo_id tract_id

/*********************************************************************/
/* calc. black pop living in each 5 percentage point black share bin */
/*********************************************************************/

/* calc. share of black residents in each tract */
gen tract_black_prop = tract_blackonly_pop / tract_total_pop_bw

/* generate 5% cuts on muslim_share in neighborhoods */
egen bcut = cut(tract_black_prop), at(0(.05)1)

/* cap muslim share at 95% (because the top bin is 95-100, not 100-100)  */
replace bcut = .95 if bcut == 1

/* get absolute/total population within each 5% cut of muslim share in neighborhoods  */
bys bcut: egen tpop_b = total(tract_blackonly_pop)

/* get % of total muslim population living within 5% cuts of muslim share */
sum tract_blackonly_pop
replace tpop_b = tpop_b / (`r(mean)' * `r(N)')

/* round cuts of muslim share */
replace bcut = round(bcut * 100)

/* save only tract id and populations of interest in tmp  */
save $tmp/us/us_tract_pop, replace

/* preserve data at tract level */
preserve

/* collapse to get national level population estimates */
collapse (sum) tract_blackonly_pop tract_total_pop_bw

/* calc. national level black pop share*/
local b_share = (tract_blackonly_pop / tract_total_pop_bw)*100

/* restore data to tract level */
restore

/* collapse black pop shares */
collapse (firstnm) tpop_b, by(bcut)
ren bcut share
drop if mi(share)
replace tpop_b = tpop_b * 100
format tpop_b %2.0f

/* save share dataset to merge with SC/Muslim shares for the India-vs-US comparison graph */
save $tmp/us/us_tpop_b, replace

/* shift share to middle of bin */
replace share = share + 2.5

/* ---------------------------- cell ---------------------------- */

/********************************/
/* CLEAN MSA LEVEL CENSUS DATA  */
/********************************/
/* load MSA-FIPS key data */
import delimited using $seg/us/MSA_key.csv, clear varnames(1)

/* convert FIPS codes to string to later concatenate */
tostring fipsstatecode, format(%02.0f) replace
tostring fipscountycode, format(%03.0f) replace

/* drop PR fom sample */
drop if fipsstatecode == "72"

/* concatenate state & county code to combine state and county FIPS codes into single var */
egen fips_code = concat(fipsstatecode fipscountycode)

/* drop any missing MSA name observations (because we later merge on MSA name, so if that's missing we can't map it to FIPS codes) */
drop if missing(cbsatitle)

/* clean MSA title that we'll merge on later on */
replace cbsatitle = strtrim(cbsatitle)

/* save clean MSA key */
save $tmp/us/msa_keys,replace

/* import MSA-level population data from Census */
import delimited using $seg/us/msa-level-pop-2020.csv, clear varnames(1)
/* NB -- this file was transposed before being downloaded so every other row is completely empty */

/* rename variables */
ren (labelgrouping total) (cbsatitle msa_total_pop) 

/* keep only nonmissing rows (see note above) */
keep if !missing(msa_total_pop)

/* drop any missing MSA name obs */
drop if missing(cbsatitle)

/* remove thousands delimiter , from number values */
foreach v in msa_total_pop totalpopulationofoneraceblackora v12 v17 v18 v19 v20 v28 v29 v31 v38 v40 v41 v42 v49 v51 v52 v53 totalpopulationofoneracewhitealo totalpopulationofoneraceamerican totalpopulationofoneraceasianalo totalpopulationofoneracenativeha totalpopulationofoneracesomeothe v13 v14 v15 v16 v21 v23 v24 v25 v26 v32 v33 v34 v35 v36 v37 v55 v56 v58 {
  replace `v' = subinstr(`v', ",","",.)
  destring `v', replace
}

/* gen minority group pop */
egen msa_black_pop = rowtotal(totalpopulationofoneraceblackora v12 v17 v18 v19 v20 v28 v29 v30 v31 v38 v39 v40 v41 v42 v43 v49 v50 v51 v52 v53 v54 v59 v60 v61 v62 v65 v66 v67 v68 v70 v72)

/* gen majority group */
egen msa_nonblack_pop = rowtotal(totalpopulationofoneracewhitealo totalpopulationofoneraceamerican totalpopulationofoneraceasianalo totalpopulationofoneracenativeha totalpopulationofoneracesomeothe v13 v14 v15 v16 v21 v22 v23 v24 v25 v26 v32 v33 v34 v35 v36 v37 v44 v45 v46 v47 v55 v56 v57 v58 v63 v69)

/* reconstruct total pop */
gen total_pop = msa_black_pop + msa_nonblack_pop

/* confirm that reconstructed total pop is identical to raw data total pop */
assert total_pop == msa_total_pop

/***********************************************************************/
/* create vars for alternative definition of minority/majority samples */
/***********************************************************************/
/* define the black sample as black population only */
ren totalpopulationofoneraceblackora msa_pop_blackonly

/* define the white sample as white population only */
ren totalpopulationofoneracewhitealo msa_pop_whiteonly

/* define the total pop as black + white only */
egen msa_total_pop_bw = rowtotal(msa_pop_blackonly msa_pop_whiteonly)

/* keep only vars of interest  */
keep cbsatitle msa_total_pop msa_total_pop_bw msa_black_pop msa_pop_blackonly msa_nonblack_pop msa_pop_whiteonly

/* remove "Metro Area" from string in  MSA name var and clean unicode chars */
replace cbsatitle = subinstr(cbsatitle, "Metro Area", "",.)
replace cbsatitle = subinstr(cbsatitle, "Â ", "",.)

/* remove leading and trailing blanks from MSA name */
replace cbsatitle = strtrim(cbsatitle)

/* remove non-breaking-space character from MSA names */
replace cbsatitle = subinstr(cbsatitle, " ", "", .)

/* merge 1:m on MSA name to get FIPS codes for each MSA */
/* nb: this is necessary to then map MSAs to tract-level data */
merge 1:m cbsatitle using $tmp/us/msa_keys, keep(match) gen(key_merge) 

/* merge in tract data on FIPS codes */
/* here we lose 15% of the tract data because they're in counties that don't appear in the MSA pop data */
merge 1:m fips_code using $tmp/us/us_tract_pop, keep(match)

/* gen MSA numeric identifier */
sort cbsatitle
encode cbsatitle, gen(msa_id)

/* keep only vars of interest */
keep cbsatitle msa_id tract_id msa_total_pop msa_total_pop_bw msa_nonblack_pop msa_black_pop msa_pop_blackonly msa_pop_whiteonly fips_code tract_total_pop tract_nonblack_pop tract_black_pop tract_blackonly_pop tract_whiteonly_pop tract_total_pop_bw

/* gen minority weights (minority sample: all black subgroups) */
gen msa_black_prop = msa_black_pop / msa_total_pop

/* gen alt. minority weights (minority sample: black only) */
gen msa_blackonly_prop = msa_pop_blackonly / msa_total_pop_bw

/* gen US MSAs dissimilarity index */
gen_dissimilarity, min(tract_black_pop) maj(tract_nonblack_pop) gen(msa_dissim_us_census) label("US Black") upper(msa_id)

/* gen US MSAs alt. dissimilarity index */
gen_dissimilarity, min(tract_blackonly_pop) maj(tract_whiteonly_pop) gen(msa_dissim_bw_census) label("US Black") upper(msa_id)

/* generate isolation measures for US */
gen_isolation, min(tract_black_pop) maj(tract_nonblack_pop) gen(msa_iso_us_census) label("US Black") upper(msa_id)
gen_isolation, min(tract_blackonly_pop) maj(tract_whiteonly_pop) gen(msa_iso_bw_census) label("US Black") upper(msa_id)

/* gen black share variable */

/* save dataset with population at both tract and MSA level  */
save $tmp/us/msa_tract_race_pop, replace

/* rename *prop to *share */
ren msa_black_prop msa_black_share
ren msa_blackonly_prop msa_blackonly_share

/* collapse data to MSA level (unit of obs for dissimilarity index) */
collapse (first) msa_blackonly_share msa_black_share msa_black_pop msa_pop_blackonly msa_total_pop msa_total_pop_bw msa_dissim_us_census msa_dissim_bw_census msa_iso_us_census msa_iso_bw_census , by(msa_id)

/* save dataset at MSA level */
save $tmp/us/us_census_msa_dissim, replace
