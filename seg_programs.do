global letters a b c d e f g h i j k l m n o p q r s t u v w x y z
/* Define several functions that are used in various files of the segregation build.  */

/**********************************************************************************/
/* program basic_person_name_clean : Remove non-letter characters from names

This program is used to clean the names extracted from the SECC as well as the set
of names classified by religion that we use to classify the SECC names.
*/
/***********************************************************************************/
cap prog drop basic_person_name_clean
prog def basic_person_name_clean
{
  syntax varname, [noinitialsdrop nokeepunique]

  /* get the varnmae and store it in `varname' */
  tokenize `varlist'
  local varname = "`1'"

  noi di "(1/5) Convert all characters to lower case $S_TIME"
  /* convert all names to lower case */
  gen __temp  = lower(`varname')
  drop `varname'

  noi di "(2/5) Initial replacement of symbols and trim $S_TIME"
  /* replace symbols that with blank spaces (in the case that they shouldn't simply be removed)  */
  foreach sym in "(" ")" "." "-" "|" {
    replace __temp = subinstr(__temp, "`sym'", " ", .)
  }

  /* replace titles that got mangled */
  foreach title in "da0" "mo0" "mo 0" {
    replace __temp = subinstr(__temp, "`title'", "", .)
  }

  /* trim the blank spaces */
  replace __temp = trim(itrim(__temp))

  noi di "(3/5) Sieve all non-letter characeters $S_TIME"
  /* remove all other characters to ensure the names are just combinations of letters a-z and spaces */
  egen `varname' = sieve(__temp), char(abcdefghijklmnopqrstuvwxyz )
  replace `varname' = trim(itrim(`varname'))

  noi di "(4/5) Replace non-names $S_TIME"
  /* replace non-names with missing */
  replace `varname' = "" if `varname' == "nan"
  replace `varname' = "" if `varname' == "no name"
  replace `varname' = "" if `varname'  == "new born"
  replace `varname' = "" if `varname' == "nama"
  replace `varname' = "" if `varname' == "name"
  replace `varname' = "" if `varname' == "nam"

  /* replace "baby" with empty spaces */
  replace `varname' = subinstr(`varname', "baby boy", "", .)
  replace `varname' = subinstr(`varname', "baby girl", "", .)
  replace `varname' = subinstr(`varname', "baby ", "", .)
  replace `varname' = subinstr(`varname', " baby", "", .)

  /* eliminate non-names */
  foreach i in baby infant son daughter girl boy wife husband name noname unname new nam head { 
    replace `varname' = "" if `varname' == "`i'"
  }

  /* eliminate mangled character names */
  replace `varname' = "" if regexm(`varname', "chid chid")

  noi di "(5/5) Remove initials and trim again $S_TIME"
  /* if initials_drop is specified, drop all single letter initials */
  if "`initialsdrop'" != "" {

    /* eliminate any single character strings (initials) that begin the name*/
    replace `varname' = regexr(`varname', "^[a-z] ", " ")
  
    /* replace single letters with space until there are no more initials */
    local initials = 1
    while (`initials' > 0) {

      /* replace inidividual letter with a space */
      qui replace `varname' = regexr(`varname', " [a-z] ", " ")

      /* check to see if there are any more initials */
      count if regexm(`varname', " [a-z] ")
      local initials = `r(N)'
    }
  }

  /* count how many unique letters are in each name */
  gen __unique_letters = 0
  foreach l in $letters {
    replace __unique_letters = __unique_letters + regexm(`varname', "`l'")
  }
  
  /*  eliminate all names that have only 1 unique letter */
  replace `varname' = "" if __unique_letters < 2

  /* trim again */
  replace `varname' = trim(itrim(`varname'))

  /* drop any names only two letters or less */
  replace `varname' = "" if length(`varname') <= 2

  if mi(`keep_unique') {
    drop __unique_letters
  }
  drop __temp
}
end
/* *********** END program basic_person_name_clean ***************************************** */


/**********************************************************************************/
/* program calculate_cdf : calculate the cdf of a variable depending on its frequncy

This program is used to calculate the frequency of names occurring in the SECC
and in the set of names classified by religion. By calculating the frequency of each
name, we can use the most commonly occurring names to speef up parts of the build.

*/
/***********************************************************************************/
cap prog drop calculate_cdf
prog def calculate_cdf
{
  syntax varname, COUNTvar(string)

  /* get the varnmae and store it in `name' */
  tokenize `varlist'
  local varname = "`1'"

  /* ensure that the dataset is unique on the variable of interest */
  is_unique `varname'

  /* count the total number of occurrences of the name */
  egen total = sum(`countvar')

  /* calculate the frequency of occurence of each name */
  gen freq = `countvar' / total
  
  /* sort by frequency */
  gsort freq

  /* calculate the cdf of the occurrnece of each name */
  gen cum_freq = freq[1]
  replace cum_freq = cum_freq[_n - 1] + freq[_n] if _n > 1

  /* reverse the sorting for plotting */
  gsort -cum_freq

}
end
/* *********** END program calculate_cdf ***************************************** */

/**********************************************************************************/
/* program manual_name_replacements : this program replaces names with shorter 
versions for the purpose of muslim classification. 

some states have lots of long, unique names, meaning we can't run an efficient fuzzy
string match on the names (there are just too many). these long names often have one
component that is all we need to classify the name, i.e. any name with  "shek" in it
will be muslim and any name with "devi" will not. this step allows us to reduce the 
complexity of the names before calculating the cdf so that we reduce the total number
of names that we have to classify. 
*/
/***********************************************************************************/
cap prog drop manual_name_replacements
prog def manual_name_replacements
{
  syntax varname

  /* get the varnmae and store it in `name' */
  tokenize `varlist'
  local varname = "`1'"

  /* define replace names */
  /* Andhrapradesh, Gujarat */
  local varname raw_string_trans
  replace `varname' = "shek" if strpos(`varname', "shek") != 0
  replace `varname' = "devi" if strpos(`varname', "devi") != 0
  replace `varname' = "krishna" if strpos(`varname', "krishna") != 0
  replace `varname' = "kumar" if strpos(`varname', "kumar") != 0
  replace `varname' = "lakshmi" if strpos(`varname', "lakshmi") != 0  
  replace `varname' = "laxmi" if strpos(`varname', "laxmi") != 0
  replace `varname' = "nagaraju" if strpos(`varname', "nagaraju") != 0  
  replace `varname' = "reddi" if strpos(`varname', "reddi") != 0
  replace `varname' = "reddy" if strpos(`varname', "reddy") != 0

  /* Karnataka */
  replace `varname' = "kahtun" if strpos(`varname', "khatun") != 0
  replace `varname' = "dasa" if strpos(`varname', "dasa") != 0
  replace `varname' = "sekha" if strpos(`varname', "sekha") != 0
  replace `varname' = "manara" if strpos(`varname', "manara") != 0
  replace `varname' = "amara" if strpos(`varname', "amara") != 0
  replace `varname' = "lama" if strpos(`varname', "lama") != 0
  replace `varname' = "manala" if strpos(`varname', "manala") != 0
  replace `varname' = "vivi" if strpos(`varname', "vivi") != 0
  replace `varname' = "viva" if strpos(`varname', "viva") != 0

}
end
/* *********** END program manual_name_replacements ***************************************** */



/**********************************************************************************/
/* program interaction_term : this program interacts a varlist with a set of
variables. the set of varibles interacted can be as long as needed, meaning the 
function can produce simple, triple, quadruple, etc. interactions

varlist: list of root variables to be interacted
interact: a varlist to be interacted with each root variable

Examples:
interaction_term ed1 ed2 ed3, interact(scst)
  --> ed1_scst ed2_scst ed3_scst

interaction_term ed1 ed2 ed3, interact(scst slum)
  --> ed1_scst_slum ed2_scst_slum ed3_scst_slum
*/
/***********************************************************************************/
cap prog drop interaction_term
prog def interaction_term
{
  syntax varlist, interact(varlist)

  /* cycle through each primary variable that will be interacted */
  foreach var1 in `varlist' {

    /* use the var1 name to initiate the new name of the interaction term */
    local new_var `var1'

    /* create a __temp variable to hold the interaction term */
    gen __temp = `var1'
  
    /* cycle through each variable to be interacted with the primary variable */
    foreach i in `interact' {
    
      /* add this variable to the interaction term name */
      local new_var `new_var'_`i'
    
      /* multiply the interaction term by this variable */
      replace __temp = __temp * `i'
    }

    /* name the interaction term with the concatenated name */
    ren __temp `new_var'

  }
}
end
/* *********** END program interaction_term ***************************************** */

/**********************************************************************************/
/* program gen_dissimilarity : calcualte the dissimilarity index given two
inverse variables as minority_pop and majority_pop.

minority_pop: variable describing the minority group of interest
majority_pop: variable describing the majority group of interest
gen: name of the new variable to be generated
label: label for generated variable
nodrop: specify if you don't want to drop the intermediate terms
upper: the larger group/city/subdistrict you want to calculate seg measure within

All definitions for the 
dissimilarity/interaction/isolation/correlation variables here come 
from Segregation and Diversity Measures in Population Distribution:  White, 1986.*/
/***********************************************************************************/
cap prog drop gen_dissimilarity
prog def gen_dissimilarity
{
    syntax, MINority_pop_block(string) MAJority_pop_block(string) gen(string) label(string) upper(string) [nodrop]

    /* drop any existing variables that will obstruct the build */
    capdrop temp total_pop_block minority_share_block minority_pop_town_sd majority_pop_town_sd total_pop_town_sd minority_share_town

    /* calculate intermediate terms */
    gen_intermediate_terms, min(`minority_pop_block') maj(`majority_pop_block') upper(`upper')

    /***************************/
    /* Calculate Dissimilarity */
    /***************************/

     /* calculate the summand of the dissimilarity term, i.e. the difference in the 
    percentage of each population at the unit level relative to the larger geographic area */
    gen temp = 0.5 * (abs((`minority_pop_block' /minority_pop_town_sd) - (`majority_pop_block' / majority_pop_town_sd)))

    /* sum the new dissimilarity var over the town/subdistrict */
    bysort `upper': egen `gen' = sum(temp)
    label var `gen'  "dissimilarity: `label'"
    drop temp
    
    /* drop intermediate terms unless otherwise specified */
    if "`drop'" == "" {
      drop total_pop_block  minority_pop_town_sd majority_pop_town_sd total_pop_town_sd minority_share_town
    }
  
}
end
/* *********** END program gen_dissimilarity ***************************************** */

/*******************************************************/
/* program gen_intermediate_terms: Create all intermediate
terms used to create dissimilarity, interaction, isolation
and correlation variables*/
/*******************************************************/
cap prog drop gen_intermediate_terms
prog def gen_intermediate_terms

  syntax,  MINority_pop_block(string) MAJority_pop_block(string) upper(string)

  capdrop total_pop_block minority_pop_town_sd total_pop_town_sd majority_pop_town_sd minority_share_town
  
  /* generate total block population */
  gen total_pop_block = `minority_pop_block' + `majority_pop_block'

  /* sum over town/subdistrict */
  bysort `upper': egen minority_pop_town_sd = total(`minority_pop_block')
  bysort `upper': egen total_pop_town_sd    = total(total_pop_block)
  gen majority_pop_town_sd = total_pop_town_sd - minority_pop_town_sd
  gen minority_share_town = minority_pop_town_sd / total_pop_town_sd

end
/** END program gen_intermediate_terms *****************/



/***************************************************************************/
/* program gen_interact_maj: generate interaction_maj_`demo' terms */
/***************************************************************************/
cap prog drop gen_interact_maj
prog def gen_interact_maj

  syntax, MINority_pop_block(string) MAJority_pop_block(string) gen(string) label(string) upper(string) [nodrop]

  /* drop any existing variables that will obstruct the build */
  capdrop temp total_pop_block minority_share_block minority_pop_town_sd majority_pop_town_sd total_pop_town_sd minority_share_town

  /* calculate intermediate terms */
  gen_intermediate_terms, min(`minority_pop_block') maj(`majority_pop_block') upper(`upper')

  /********************************************/
  /* calculate interaction index for majority */
  /********************************************/
  /* calculate the summand: probability that someone from the majority in the town
  interacts with a someone from the minority in the block*/
  gen temp = (`majority_pop_block' / majority_pop_town_sd) * (`minority_pop_block' / total_pop_block)

  /* sum interaction-majority term over town/subdistrict */
  bysort `upper': egen `gen'  = sum(temp)
  label var `gen' "Interaction Index- majority: `label'"
  drop temp

  /* drop intermediate terms unless otherwise specified */
  if "`drop'" == "" {
    drop total_pop_block  minority_pop_town_sd majority_pop_town_sd total_pop_town_sd minority_share_town
  }


end
/** END program gen_interact_maj ********************************************/

/***************************************************************************/
/* program gen_interact_min: generate interaction_min_`demo' terms */
/***************************************************************************/
cap prog drop gen_interact_min
prog def gen_interact_min

  syntax, MINority_pop_block(string) MAJority_pop_block(string) gen(string) label(string) upper(string) [nodrop]

  /* drop any existing variables that will obstruct the build */
  capdrop temp total_pop_block minority_share_block minority_pop_town_sd majority_pop_town_sd total_pop_town_sd minority_share_town

  /* calculate intermediate terms */
  gen_intermediate_terms, min(`minority_pop_block') maj(`majority_pop_block') upper(`upper')
  
  /********************************************/
  /* calculate interaction index for minority */
  /********************************************/
  /* calculate the summand: probability that someone from the minority in the town
  interacts with a someone from the majority in the block*/
  gen temp = (`minority_pop_block' / minority_pop_town_sd) * (`majority_pop_block' / total_pop_block)

  /* sum interaction-minority term over town/subdistrict */
  bysort `upper': egen `gen' = sum(temp)
  label var `gen'  "Interaction Index- minority: `label'"
  drop temp

  /* drop intermediate terms unless otherwise specified */
  if "`drop'" == "" {
    drop total_pop_block  minority_pop_town_sd majority_pop_town_sd total_pop_town_sd minority_share_town
  }

end
/** END program gen_interact_min ********************************************/

/*********************************************************************************************************************/
/* program gen_isolation: generate isolation measures (see gen_dissim for more info on what the intermediate terms
mean*/
/*********************************************************************************************************************/
cap prog drop gen_isolation
prog def gen_isolation

  syntax, MINority_pop_block(string) MAJority_pop_block(string) gen(string) label(string) upper(string) [nodrop]

  /* drop any existing variables that will obstruct the build */
  capdrop temp total_pop_block minority_share_block minority_pop_town_sd majority_pop_town_sd total_pop_town_sd minority_share_town

  /* calculate intermediate terms */
  gen_intermediate_terms, min(`minority_pop_block') maj(`majority_pop_block') upper(`upper')
  
  /*****************************/
  /* calculate isolation index */
  /*****************************/
  /* calculate the summand: probability that someone from the
  minority in the town interacts with someone from the minority in
  the block */
  /* 1. the first term weights each neighborhood by the share of the town's minorities that live there  */
  /* 2. the second term is just the minority share */
  /* 3. Across all places, it's the minority-pop-weighted minority share --- e.g. if you're a
       minority, what is the expected minority share of your neighborhood. */
  gen temp = (`minority_pop_block' / minority_pop_town_sd) * (`minority_pop_block' / total_pop_block)

  /* sum isolation summand over town/subdistrict */
  bysort `upper': egen `gen' = sum(temp)
  label var `gen' "Isolation: `label'"
  drop temp

  /*****************************/
  /* rescale isolation index to [0,1] range */
  /*****************************/
  /* generate rescaled version following D&D: (isolation - minority_share) / (1 - minority_share) */
  gen `gen'_rescaled = (`gen' - minority_share_town) / (1 - minority_share_town)
  label var `gen'_rescaled "Rescaled Isolation (0-1): `label'"
  
  /* drop intermediate terms unless otherwise specified */
  if "`drop'" == "" {
    drop total_pop_block  minority_pop_town_sd majority_pop_town_sd total_pop_town_sd minority_share_town
  }

end
/** END program gen_isolation ****************************************************************************************/

/****************************************************************************************************/
/* program gen_correlation: generate city_correaltion_`demo' measure (see gen_dissimilarity() for
more details*/
/****************************************************************************************************/
cap prog drop gen_correlation
prog def gen_correlation

  syntax, MINority_pop_block(string) MAJority_pop_block(string) gen(string) demo(string) label(string) upper(string) [nodrop]

  /* drop any existing variables that will obstruct the build */
  capdrop temp total_pop_block minority_share_block minority_pop_town_sd majority_pop_town_sd total_pop_town_sd minority_share_town

  /* calculate intermediate terms */
  gen_intermediate_terms, min(`minority_pop_block') maj(`majority_pop_block') upper(`upper')

  /* check if isolation terms exist, if not, flag error and quit.  */
  cap assert !mi(city_iso_`demo')

  /* print error message about missing isolation variables */
  if _rc {
    noi di "missing sc/muslim isolation measures. create those before running this"
    exit
  }
  
  /*******************************/
  /* calculate correlation index */
  /*******************************/
  gen `gen' = (city_iso_`demo' - minority_share_town) / (1 - minority_share_town)
  label var `gen' "Correlation: `label'"
  
  /* drop intermediate terms unless otherwise specified */
  if "`drop'" == "" {
    drop total_pop_block  minority_pop_town_sd majority_pop_town_sd total_pop_town_sd minority_share_town
  }
  
end
/** END program gen_correlation *********************************************************************/

/**************************************************************************************************/
/* program: gen_gini: calculate gini index. Note: all precalculated programs don't calculate gini */
/* consistently, so we write our own program for it.

Also note: calculation  for the gini index comes from A Methodological Analysis of Segregation Indexes,
Duncan and Duncan 1955. We use the simplest definition for the gini index here provided on page 2/211
of the Duncan and Duncan paper.

If there are
1. k enumeration blocks in the town/subdistrict
2. i denotes the ith enumeration block, 
3. enumeration blocks are ranked in order of minority share miniorty_pop_block/total_block_pop (X_i/T_i)
4. X_i is the cumulative sum of minority group up until the ith block in the town/subdistrict
5. Y_i is the cumulative sum of the majority group up until the ith block in the town/subdistrict

then the gini index G = \sum_{i=1}^{i=k}X_{i-1}*Y_{i} - \sum_{i=1}^{i=k}X_{i}*Y_{i-1} */
/**************************************************************************************************/
cap prog drop gen_gini
prog def gen_gini
{
    syntax, x_i(string) y_i(string) gen(string) label(string) upper(string) [nodrop] 

    /* drop any existing variables that will obstruct the build */
//    capdrop temp total_pop  minority_share_block p_j minority_pop_town_sd Y T P
    
    /* calculate intermediate terms */
    gen total_pop_block = `x_i' + `y_i'
    gen minority_share_block = `x_i' / total_pop_block

    /* sum over shrid */
    bysort `upper': egen minority_pop_town_sd = sum(`x_i')
    bysort `upper': egen total_pop_town_sd = sum(total_pop_block)
    gen majority_pop_town_sd = total_pop_town_sd - minority_pop_town_sd

    /* sort by sc_share within `upper' */
    sort `upper' minority_share_block

    /* create block id within sorted data
    used in rangestat to create a rolling sum*/
    bysort `upper': gen block_id = _n
    
    /* create a cumulative sum term X_i = x_1 + ...+ x_i by sorted city, block */
    rangestat (sum) X_i = `x_i', interval(block_id . 0)  by(`upper')
    replace X_i = X_i/minority_pop_town_sd

    /* create a cumulative sum term X_i_1 = x_1 + ...+ x_i-1 by sorted city, block */    
    rangestat (sum) X_i_1 = `x_i', interval(block_id . -1)  by(`upper')
    replace X_i_1 = X_i_1/minority_pop_town_sd

    /* create a cumulative sum term Y_i = y_1 + ...+ y_i by sorted city, block */
    rangestat (sum) Y_i = `y_i', interval(block_id . 0)  by(`upper')
    replace Y_i = Y_i/majority_pop_town_sd

    /* create a cumulative sum term Y_i_1 = y_1 + ...+ y_i-1 by sorted city, block */    
    rangestat (sum) Y_i_1 = `y_i', interval(block_id . -1)  by(`upper')
    replace Y_i_1 = Y_i_1/majority_pop_town_sd

    /* Generate Pairwise Interaction terms */
    gen X_i_Y_i_1 = X_i*Y_i_1
    gen X_i_1_Y_i = X_i_1*Y_i

    bysort `upper': egen X_Y_1 = sum(X_i_Y_i_1)
    bysort `upper': egen X_1_Y = sum(X_i_1_Y_i)

    /* sum the new gini var over the shrid */
    bysort `upper': gen `gen' = abs(X_1_Y - X_Y_1)
    label var `gen'  "gini: `label'"

    /* drop intermediate terms unless otherwise specified */
    if "`drop'" == "" {
      drop total_pop_block minority_share_block  minority_pop_town_sd majority_pop_town_sd total_pop_town_sd  X_Y_1 X_1_Y Y_i_1 Y_i X_i_1 X_i block_id X_i_Y_i_1 X_i_1_Y_i
    }
    
}
end
/* *********** END program gen_gini ***************************************** */

/**********************************************************************************/
/* program create_household_muslim_key : create household level muslim key

this program transforms the probability assigned to each household member's name of being 
muslim and/or nonmuslim to create a household-level muslim indicator.

state = the state of interest
sector = rural, urban
nodata_low = bottom threshold for uncertainty window, default 0.35
nodata_high = top bracket for uncertainty window, default 0.65
   --> for names with a probability of being both muslim and nonmuslim that lies within this window,
       we re-classify them as unkown as we cannot be certain which classificaiton is correct
high_conf = the probability associated with high confidence that a members is muslim/nonmuslim
savekey = save the household key to $iec, nosavekey just returns the data wihtout saving

*/
/***********************************************************************************/
cap prog drop create_household_muslim_key
prog def create_household_muslim_key
{
  syntax, state(string) sector(string) [nodata_low(real 0.35) nodata_high(real 0.65) high_conf(real 0.9) savekey]

  quietly {

    if "`sector'" == "urban" local locality pc11_town_id
    if "`sector'" == "rural" local locality pc11_village_id
    
    /***********************************************************************/
    /* (1) threshold the predicted probability of each member being muslim */
    /***********************************************************************/
    noi di "(1/3) Thresholding muslim probability..."

    /* define thresholding of muslim */
    gen muslim = .
    replace muslim = 1 if muslim_prob >= `nodata_high' & nonmuslim_prob <= `nodata_low'
    replace muslim = 0 if muslim_prob <= `nodata_low' & nonmuslim_prob >= `nodata_high'
    
    /* create a variable to count household members */
    gen members = 1
    
    /* save the full dataset */
    tempfile full_members
    save `full_members'

    /******************************************************************/
    /* (2) use household composition to classify the entire household */
    /******************************************************************/
    noi di "(2/3) Collapsing classification to household level...$S_TIME"
    
    /* drop any missing/ambiguous classifications */
    drop if mi(muslim)
    
    /* generate counters for people with high certainty muslim/nonmuslim values */
    gen muslim_high = 0
    replace muslim_high = 1 if muslim_prob >= `high_conf'

    gen nonmuslim_high = 0
    replace nonmuslim_high = 1 if nonmuslim_prob >= `high_conf'

    /* drop if missing the house_no */
    drop if mi(house_no)
    
    /* collapse to the household */
    gcollapse (sum) members muslim_high nonmuslim_high (mean) muslim_prob nonmuslim_prob muslim (max) max_mus=muslim_prob max_nonmus=nonmuslim_prob , by(pc11_state_id pc11_district_id pc11_subdistrict_id `locality' pc11_ward_id pc11_block_id house_no)

    /* rename the variables to indicate they are household level measures */
    ren members members_hh
    label var members_hh "the number of classified hh members"

    /* drop if there are an absurd number of people in the household */
    drop if members_hh > 40

    /* apply rule for classifying the household*/
    gen muslim_hh = 0
    replace muslim_hh = 1 if muslim_high > nonmuslim_high | muslim > 0.4
    label var muslim_hh "household muslim classifier"

    /* save a tempfile: these are all the households that were matched and we can identify muslim/non-muslim */
    tempfile household_classification
    save `household_classification'

    /*******************************************************/
    /* (3)  merge in the total number of household members */
    /*******************************************************/
    noi di "(3/3) Merging in the total number of household members...$S_TIME"

    /*  get the number of members in a household for ALL households */
    use `full_members', clear
    drop if mi(house_no)
    collapse (sum) members,  by(pc11_state_id pc11_district_id pc11_subdistrict_id `locality' pc11_ward_id pc11_block_id house_no)

    /* rename members variable and label */
    ren members all_members_hh
    label var all_members_hh "the total number of household members"

    /* merge in the total household members number */
    merge 1:1 pc11_state_id pc11_district_id pc11_subdistrict_id `locality' pc11_ward_id pc11_block_id house_no using `household_classification', nogen
    
    /* replace missing muslim identification with value */
    replace muslim_hh = 2 if mi(muslim_hh)
    label define muslim_hh 0 "0 not muslim" 1 "1 muslim" 2 "2 missing"
    label values muslim_hh muslim_hh

    /* save only the muslim_hh variable to the key if specified */
    if "`nosavekey'" == "" {
      noi di "Saving final muslim key as $iec2/secc/parsed_draft/tables/rural/household/`state'_muslim_clean_key...$S_TIME"
      keep pc11_state_id pc11_district_id pc11_subdistrict_id `locality' pc11_ward_id pc11_block_id house_no members_hh all_members_hh muslim_hh
      save $iec2/secc/parsed_draft/tables/`sector'/members/`state'_muslim_hh_clean_key, replace
    }
    noi di "DONE `sector' `state'..$S_TIME $S_DATE"
  }
}
end
/* *********** END program create_household_muslim_key ***************************************** */


/* small utility program */
cap prog drop gen_collapse_levels
prog def gen_collapse_levels
  {
    syntax anything
    
    if "`anything'" == "rural" {
      gen subdistrict = pc11_state_id + pc11_district_id + pc11_subdistrict_id
      gen upper = subdistrict
    } 
    else if "`anything'" == "urban" {
      gen town = shrid
      gen upper = town
    }
    else {
      fail "program accepts only rural/urban"      
    }
  }
end
/* *********** END program gen_collapse_levels ***************************************** */
/* ************ FORMERLY gen_upper_levels */


/* small utility program */
/* So when you specify a part, it merges in the key for state, district and part id.
Then it keeps only the part id for which part_id has been specified */
cap prog drop keep_pc11_state_part
prog def keep_pc11_state_part
  {
    syntax , part(string)
    merge m:1 pc11_state_id pc11_district_id using $keys/pcec/pc11_partition_key.dta, keepusing(pc11_part_id)
    cap assert _merge != 1
    if _rc != 0 {
      disp_nice "warning: some of your data was not matched to the parts key on state-dist"
    }
    keep if pc11_part_id == "`part'"
    drop pc11_part_id
  }
end
/* *********** END program keep_pc11_state_part ***************************************** */

/* get all parts for secc state string  */
cap prog drop get_pc11_state_parts
prog def get_pc11_state_parts, rclass
  {
    syntax , state(string) infile(string)

    /* requires a key with prepped string statenames */
    preserve
    use `infile', clear
    
    /* get pc11 state key for this state */
    qui levelsof pc11_state_id if pc11_state_name == "`state'", clean local(stateid)

    /* get sub-state parts */
    qui levelsof pc11_part_id if pc11_state_id == "`stateid'", local(parts)

    /* telangana manual override to andhrapradesh; set parts */
    if "`state'" == "telangana" {
      local stateid "28"
      local dists `"532"' `"533"' `"534"' `"535"' `"536"' `"537"' `"538"' `"539"' `"540"' `"541"'
      gen keep = 0
      foreach dist in `"`dists'"' {
        replace keep = 1 if pc11_district_id == "`dist'"
      }
      keep if keep == 1
      qui levelsof pc11_part_id, local(parts)
    }

    /* ap override parts */
    if "`state'" == "andhrapradesh" {
      local dists `"542"' `"543"' `"544"' `"545"' `"546"' `"547"' `"548"' `"549"' `"550"' `"551"' `"552"' `"553"' `"554"'
      gen keep = 0
      foreach dist in `"`dists'"' {
        replace keep = 1 if pc11_district_id == "`dist'"
      }
      keep if keep == 1
      qui levelsof pc11_part_id, local(parts)
    }

    /* send back parts in `e(parts)' */
    restore
    return local parts `parts'
  }
end
/* *********** END program get_pc11_state_parts ***************************************** */


/* set SECC collapse statelist. takes lower case of directory names as
listed in ~/iec2/secc/raw_input/parsed/, which includes all states in
$secc/parsed_draft/dta/urban/. note thatdadranagarhaveli does not have
rural data! */
global seccstatelist uttarpradesh westbengal tamilnadu rajasthan andamannicobarislands andhrapradesh arunachalpradesh assam bihar chandigarh chhattisgarh dadranagarhaveli damananddiu goa gujarat haryana himachalpradesh jammukashmir jharkhand karnataka madhyapradesh maharashtra manipur meghalaya mizoram nagaland nctofdelhi odisha puducherry punjab sikkim telangana tripura uttarakhand







/**********************************************************************/
/* program set_scheme: set scheme pn.    */
/**********************************************************************/
cap prog drop set_scheme
prog def set_scheme
  set scheme pn
end
/** END program set_scheme ********************************************/

/***********************************************************************************************/
/* program regress_ec_pg_pc: Regress EC PG's on sc and muslim share for EC results over time   */
/***********************************************************************************************/
cap prog drop regress_ec_pg_pc
prog def regress_ec_pg_pc
  syntax, pg(string) ec(string) pc(string) fe(string)

  /* rename pc variables for more generalisable regression */
  ren sc_share_`pc' sc_share
  cap drop log_pop
  ren log_pop_`pc' log_pop

  /* run regression */
  noi areg shric_gov_`pg'_`ec' sc_share muslim_share log_pop, absorb(pc11_`fe'_id)
  estimates store `pg'_`ec'

  /* rename variables back */
  ren sc_share sc_share_`pc'
  ren log_pop log_pop_`pc'
  
end
/** END program regress_ec_pg_pc ***************************************************************/

/***********************************************************************************************/
/* program regress_ec_pg_pc_kerala: Regress EC PG's on sc and muslim share for EC results over time   */
/***********************************************************************************************/
cap prog drop regress_ec_pg_pc_kerala
prog def regress_ec_pg_pc_kerala
  syntax, pg(string) ec(string) pc(string) fe(string)

  /* rename pc variables for more generalisable regression */
  ren sc_share_`pc' sc_share
  cap drop log_pop
  ren log_pop_`pc' log_pop

  /* run regression */
  noi areg shric_gov_`pg'_`ec' sc_share log_pop, absorb(pc11_`fe'_id)
  estimates store `pg'_`ec'

  /* rename variables back */
  ren sc_share sc_share_`pc'
  ren log_pop log_pop_`pc'
  
end
/** END program regress_ec_pg_pc_kerala ***************************************************************/

/**********************************************************************************************/
/* program create_block_groups: Groups enumeration blocks till a minimum threshold is reached

This do-file pools SECC block data into groups with a minimum population
Enumeration Blocks are only pooled if they are geographically adjacent and
are located in the same town/village in the same ward.

We do the 
I. Clean data
II. Pool blocks and create a key
III. Merge key to original dataset and collapse blocks to block groups (pool blocks)

Inputs:
1.$sdata/clean/secc_`sector'_collapsed_block: SECC block level Data
2.$sdata/secc_ec_blockdata_`sector' SECC-EC13 Merged Block Level Data to create the block groups
3.$shrug/keys/shrug_pc11`l'_key : shrug key to add in shrids to the  SECC-EC Merged Blockdata

Outputs:
Saved to filepath defined in `fp_out'
*****NOTE : REQUIRES SSC INST _GWTMEAN *****

*/
/**********************************************************************************************/
cap prog drop create_block_groups
prog def create_block_groups

  syntax, bgroup(string) sector(string) outfile(string)

  /* show status */
  disp_nice "`sector': `bgroup'"

  /* set locality ID based on sector */
  if "`sector'" == "urban" {
    local l u
    local locality pc11_town_id
  }
  if "`sector'" == "rural" {
    local l r
    local locality pc11_village_id
  }
  cap mkdir $tmp/secc
  cap mkdir $tmp/secc/block_to_nbd

  /**************/
  /* Clean data */
  /**************/
  /* use block level data */
  use $sdata/clean/secc_`sector'_collapsed_block, clear

  /* merge in shrid data */
  merge m:1 pc11_state_id `locality' using $shrug/keys/shrug_pc11`l'_key, keep(master match) nogen
  
  /* generate collapse */
  gen_collapse_levels `sector'

  /* set the town identifying variable for rural vs. urban */
  if "`sector'" == "rural" {
    local upper subdistrict
  }
  
  if "`sector'" == "urban" {
    local upper town
  }

  /* keep only data needed to define the block groups */
  keep pc11_state_id pc11_district_id pc11_subdistrict_id `upper' `locality' pc11_ward_id pc11_block_id shrid block_pop

  /* drop missing values */
  drop if mi(shrid)
  drop if mi(block_pop)

  /* get block groupings */
  /* the first four digits of this seem to imply EB code and the digits after the underscore imply the sub eb code.*/
  gen eb_id = substr(pc11_block_id, 1, 4)

  /* order blocks such that geographically adjacent blocks are in order */
  gsort `upper' shrid `locality' pc11_subdistrict_id pc11_district_id pc11_state_id pc11_ward_id eb_id block_pop
  drop eb_id

  /* create town or village variable, we only want to pool blocks that are in the same town/village */
  /* An earlier version of this pooled neighborhoods within wards within towns and villages, but not anymore */
  egen town_village = group(shrid pc11_state_id pc11_district_id pc11_subdistrict_id pc11_ward_id `locality' `upper')

  /***************/
  /* Pool blocks */
  /***************/

  /* create variable to define eb grouping, and call it the neighborhood */
  gen nbd = .

  /* define local to count and assign neighborhoods */
  local nbd_id = 0

  /* define local to cumulatively add block population within a neighborhood */
  local nbd_pop = 0

  /* cycle through all rows; `i' is indexing through the blocks */
  local N = _N
  forvalues i = 1/`N' {
    
    /* add the population of this block to the nbd population counter */
    local nbd_pop = `nbd_pop' + block_pop[`i']

    /* check to see if the nbd population is above the minimum needed to define a nbd */
    if `nbd_pop' >= `bgroup' {

      /* pool this block with the nbd stored in `nbd_id' */
      qui replace nbd = `nbd_id' in `i'

      /* add one to the nbd id counter as the next block will start a new nbd */
      local nbd_id = `nbd_id' + 1

      /* reset the nbd population counter for the new nbd */
      local nbd_pop = 0
    }

    /* else if the nbd population is under the nbd minimum */
    else {

      /* check to see if this block is in the same town_village as the next block
      if so, these blocks may be pooled together */
      if town_village[`i'] == town_village[`i' + 1] {
        
        /* pool this block with the nbd stored in `nbd_id' */    
        qui replace nbd = `nbd_id' in `i'
      }

      /* else if the town_village is not the same as the town_village in the next block */
      else {

        /* Since town_villages are changing, and we're below threshold, this will lead to an outlier case of a
        nbd having less than the threshold population.*/
        /* We will assign this nbd the current nbd id */
        qui replace nbd = `nbd_id' in `i'

        /* reset the nbd population counter for the new nbd, as a new town_village means a new nbd */
        local nbd_pop = 0

        /* increment the nbd id as we move to the next block nbd, in the next town_village */
        local nbd_id = `nbd_id' + 1
      }
    }
  }

  /* calculate the total population for each nbd */
  bys nbd: egen nbd_pop = sum(block_pop)

  /* save data */
  compress
  save $tmp/secc/block_to_nbd/secc_`sector'_block_to_nbd_`bgroup'_key, replace

  /************************************/
  /* Collapse blocks to neighborhoods */
  /************************************/

  /* set locality ID */
	if "`sector'" == "urban" {
    local locality pc11_town_id
    local l u
  }
  if "`sector'" == "rural" {
    local locality pc11_village_id
    local l r
  }

  local merge_vars pc11_state_id pc11_district_id pc11_subdistrict_id `locality' pc11_ward_id

  /* use EC SECC block level data */
  use $tmp/secc/secc_ec_blockdata_`sector', clear
  cap drop _merge

  /* merge in shrids from pc11 key */
  merge m:1 pc11_state_id `locality'  using $shrug/keys/shrug_pc11`l'_key, keep(master match) keepusing(shrid) nogen
  
  /* merge in the block_to_nbd key, keep( master match) ensures we keep all SECC Blocks, even those that don't have EB blocks */
  merge m:1 `merge_vars' shrid  pc11_block_id using $tmp/secc/block_to_nbd/secc_`sector'_block_to_nbd_`bgroup'_key , keep(master match) nogen
  
  /* by nbd, take the weighted mean of percap cons term, weighted by number of households in each block */
  foreach var in sc muslim nonscmuslim bothscmuslim  {

    bysort nbd: egen _temp = wtmean(cons_pc_`var'), weight(hh_`var')
    replace cons_pc_`var' =  _temp
    drop _temp
  }
  
  /* now non-disaggregated pv and conspc */
  bysort nbd: egen _temp = wtmean(cons_pc), weight(hh)
  replace cons_pc =  _temp
  drop _temp

  /* by nbd take father/moter/son/daughter education */
  /* loop over parent/child */
  foreach pchild in father_ed_m mother_ed_m father_ed_f mother_ed_f son_ed daughter_ed {
    bysort nbd: egen _temp = wtmean(`pchild'), weight(hh)
    replace `pchild' = _temp
    drop _temp

    /* loop over demographics */
    foreach demo in sc muslim nonscmuslim {
      cap bysort nbd: egen _temp = wtmean(`pchild'_`demo'), weight(hh_`demo')
      cap replace `pchild'_`demo' = _temp
      cap drop _temp

      /* loop over age slices */
      foreach age in age_1518 age_1618 age_1718 {
        bysort nbd: egen _temp = wtmean(`pchild'_`age'_`demo'), weight(hh_`demo')
        replace `pchild'_`age'_`demo' = _temp
        drop _temp
      }
    }
  }

  /* loop over more education variables to be weighted */
  /* loop over base name */
  foreach ed in ed_yrs_m1718 ed_yrs_f1718 ed_yrs_father_m1718 ed_yrs_mother_m1718 ed_yrs_father_f1718 ed_yrs_mother_f1718  {
    cap bysort nbd: egen _temp = wtmean(`ed'), weight(hh)
    cap replace `ed' = _temp
    cap drop _temp
    /* loop over demo */
    foreach demo in sc muslim nonscmuslim {
      bysort nbd: egen _temp = wtmean(`ed'_`demo'), weight(hh_`demo')
      replace `ed'_`demo' = _temp
      drop _temp
    }
  }

  
  /* get non-percapita cons vars into a local */
  local gross_cons_vars cons consr
  foreach demo in muslim nonscmuslim bothscmuslim sc {
    local gross_cons_vars `gross_cons_vars' cons_`demo' consr_`demo'
  }
  
  /* Generate a numeric block variable so we can calculate missing entries per nbd */
  gen pc11_block_id_num = subinstr(pc11_block_id, "_", "", .)
  destring pc11_block_id_num, replace


  /* collapse urban data */
  if "`sector'" == "urban"{
    /* loop over the urban sanitation and electricity variables */
    /* loop over sanitation variables */
    foreach urban_var in closed_drain wat_source_home latrine_home light_source_elec  {
      
      bysort nbd: egen _temp = wtmean(`urban_var'), weight(hh)
      replace `urban_var' = _temp
      drop _temp

      /* loop over demographic to weight by hh_`demo' */
      /* loop over demo */
      foreach demo in sc muslim nonscmuslim {
        bysort nbd: egen _temp = wtmean(`urban_var'_`demo'), weight(hh)
        replace `urban_var'_`demo' = _temp
        drop _temp
      }
    }

    /* Sort slum */
    bysort nbd: egen _temp = wtmean(slum), weight(hh)
    replace slum = _temp
    drop _temp

    /* collapse data */
    local collapse_vars pc11_state_id pc11_district_id pc11_subdistrict_id shrid `upper' pc11_town_id pc11_ward_id nbd
    ds shrid pc11*id  pc11_block_id_num `upper' town_village nbd  cons_pc nbd_pop father_ed* mother_ed* son_ed* daughter_ed* ed_yrs* closed_drain* wat_source_home* latrine_home* light_source_elec* slum , not
    local sum_vars `r(varlist)'
    gcollapse (nansum) `sum_vars' (first) cons_pc nbd_pop father_ed* mother_ed* son_ed* daughter_ed* ed_yrs* closed_drain* wat_source_home* latrine_home* light_source_elec* slum pc11_block_id_num, by(`collapse_vars')
  }


  /* collapse rural data */
  if "`sector'" == "rural" {

    /* create a local with all the ids to collapse on */
    local collapse_vars pc11_state_id pc11_district_id pc11_subdistrict_id shrid `upper' pc11_village_id pc11_ward_id  nbd 
    
    /* collapse by sums */
    ds shrid pc11*id  pc11_block_id_num `upper' town_village nbd  cons_pc nbd_pop father_ed* mother_ed* son_ed* daughter_ed* ed_yrs* , not
    local sum_vars `r(varlist)'
    gcollapse (nansum) `sum_vars' (first) cons_pc nbd_pop father_ed* mother_ed* son_ed* daughter_ed* ed_yrs* pc11_block_id_num, by(`collapse_vars')
  }
  
  /* add in nbd  */
  rename nbd block_no

  /* save the pooled block results */
  
  save `outfile', replace
  
end
/* ************************** END program create_block_groups ***************************************** */

/*******************************************************************************************************************************/
/*

program coef_pg_muslim_normalized: This function takes a public good and local name as inputs and then creates a measure for
the muslim coefficient normalised (divided) by the mean. It can be interpreted as a percentage change in the provision of a public good when a neighborhood goes from 0% muslim to 100% muslim.

*/
/*******************************************************************************************************************************/
cap prog drop coef_pg_muslim_normalized
prog def coef_pg_muslim_normalized, rclass
    
    syntax, pg(string) local_name(string) fe(string) [percent(real 1) ]

    
    /* use dataset */
    use $tmp/secc/segregation_blockdata_urban_200, clear
    
    /* run regression for pg on nbd share, save the Beta coefficient*/
    areg `pg' sc_share  muslim_share log_block_pop, absorb(`fe') r
    local pg_muslim_share = _b[muslim_share]*`percent'
    return local N_`local_name' = `e(N)'
    return local pg_muslim_share = `pg_muslim_share'*100

    /* get the average of pg across all neighborhoods */
    sum `pg'
    local pg_mean =  `r(mean)'
    return local pg_mean = `pg_mean'*100

    /* get 0-100 muslim share*/
    local pg_muslim_100 = `pg_muslim_share'/`pg_mean'

    /* also save this to user specified local */
    return local `local_name' =  `pg_muslim_100'*100

end
/** END program coef_pg_muslim_normalized *****************************************************************************************/

/********************************************************************************************/
/* program calc_mean_median_nbd_shares: Calculate the mean and median neighborhood shares   */
/********************************************************************************************/
cap prog drop calc_mean_median_nbd_shares
prog def calc_mean_median_nbd_shares, rclass
  
  syntax, sector(string) group(string)

  use $tmp/secc/segregation_blockdata_`sector'_200, clear

  /* calculate the average neighborhood share of the average person in the social group */
  sum `group'_share [aw=`group'_share]
  local mean_group_share: di %5.2f `r(mean)' * 100
  return local mean_group_share = `mean_group_share'
  
  /* generate a cumulative count of social group members */
  sort `group'_share
  gen `group'_count_cum = sum(block_pop_`group')
  
  /* identify the median person in the social group */
  sum `group'_count_cum
  local group_count = `r(max)'
  local median_group = round(`group_count') / 2
  
  /* find the neighborhood closest to the median person in the social group */
  gen dist = abs(`median_group' - `group'_count_cum)
  sum dist
  gen median_nbd = dist == `r(min)'
  sum `group'_share if median_nbd == 1
  local median_group_share: di %5.2f `r(mean)' * 100
  local N `r(N)'
  return local median_group_share = `median_group_share'
  return local N = `N'

end
/** END program calc_mean_median_nbd_shares *************************************************/

/************************************************************************************************/
/* program get_city_age_coefficient: program to get the coefficient on city_origin_decade for
paper stats.
*/
/************************************************************************************************/
cap prog drop get_city_age_coefficient
prog def get_city_age_coefficient, rclass

  syntax, group(string) [controls(string) percent(real 1)]

  /* load dataset */
  use $tmp/secc/segregation_citydata_urban_200, clear

  /* dvidide decade by 10 */
  gen city_origin_decade = city_origin_year/10

  /* regress the coefficients */
  reg city_dissim_`group' city_origin_decade `controls'

  /* local to save century's worth of changes */
  local century_change = _b[city_origin_decade]*`percent'
  local N = `e(N)'
    
  /* return the coefficient on city_origin_decade */
  return local city_`group'_coef: di %10.2f `century_change'
  return local N `N'
    
end
/** END program get_city_age_coefficient ********************************************************/
  

/***********************************************************************************************************************/
/* program get_pe_coefs: this is a wrapper function to ensure we manage to get the pe coefs referenced in the paper.
This can be reused to get new coefficients if the paper is edited to add more/different ones*/
/***********************************************************************************************************************/
cap prog drop get_pe_coefs
prog def get_pe_coefs, rclass
  syntax, group(string) pg(string) privpub(string)

  /* read in relevant file, if it doesn't exist, run analysis makefile.
  More specifically as of June 13th 2023, run $scode/a/graph_pe_functions.do */
  import delimited $tmp/alphas_urban_`group'_`pg'_`privpub'.csv, clear

  /* return total */
  sum value if category == "Total"
  return local total: di %10.2f `r(mean)'

  /* return state */
  sum value if category == "x-state"
  return local state: di %10.2f `r(mean)'

  /* return district */
  sum value if category == "x-district"
  return local district: di %10.2f `r(mean)'

  /* return town */
  sum value if category == "x-town"
  return local town: di %10.2f `r(mean)'
  return local shrug_town_id: di %10.2f `r(mean)'
  
  /* return block */
  sum value if category == "x-block"
  return local block: di %10.2f `r(mean)'
end
/** END program get_pe_coefs *******************************************************************************************/


  /*************************************************************/
  /* program prep_demo_interactions_for_collapse: sets social group interaction variables from zero to missing, so that the group
                                                  means get calculated correctly */
  /*************************************************************/
  cap prog drop prep_collapse_demo_interactions
  prog def prep_collapse_demo_interactions
    
    /* do the same thing for the infrastructure variables */
    foreach v in wat_source_home light_source_elec latrine_home closed_drain cons cons_pc {
      foreach demo in sc muslim nonsc nonmuslim nonscmuslim bothscmuslim {
        replace `v'_`demo' = . if `demo' == 0
      }
    }
      
  end
  /** END program prep_interaction_vars_for_collapse ***********/

  /***********************************************************************/
  /* program get_entropy_weights: merge in shrid-level entropy weights   */
  /***********************************************************************/
  cap prog drop get_entropy_weights
  prog def get_entropy_weights
    syntax, loc(string)
    
    cap confirm variable shrid
    if _rc {
      gen shrid = town
    }

    if "`loc'" == "rural" {
      gen ewt = 1
      cap gen ewt_sc = city_pop_sc
      cap gen ewt_muslim = city_pop_muslim
    }
    else {
      merge m:1 shrid using $tmp/entropy_weights, keep(match master) nogen
    }
  end
  /** END program get_entropy_weights ************************************/


  /************************************************************************/
  /* program check_file_update_status: fail if file is missing or stale   */
  /************************************************************************/
  cap prog drop check_file_update_status
  prog def check_file_update_status
    syntax anything(name=filepath) [, MINutes(integer 5)]

    if `minutes' <= 0 {
      di as err "check_file_update_status: minutes() must be > 0"
      exit 198
    }

    tempfile file_status
    shell /bin/bash -lc "if test -f `filepath' && find `filepath' -mmin -`minutes' | grep -q .; then echo OK > \"`file_status'\"; else echo FAIL > \"`file_status'\"; fi"

    tempname sfh
    file open `sfh' using "`file_status'", read text
    file read `sfh' status_line
    file close `sfh'

    if "`status_line'" != "OK" {
      noi di as error "Python output missing or stale (> `minutes' minutes): `filepath'"
      error 9
    }
  end
  /** END program check_file_update_status ********************************/
