/* refresh programs and variable generation settings. note that
variables to generate (for collapses) are specified in
ec_collapse_settings. */
qui do ~/ddl/core/ec/utils/ec_progs.do
qui do ~/ddl/core/ec/utils/generate_ec_variables.do
qui do ~/ddl/core/ec/utils/ec_collapse_settings.do

/************/
/* PROGRAMS */
/************/

/**************************************************************************************************/
/* program ec_data_prep - aggregates a single year of EC data from all state files                  */
/**************************************************************************************************/

cap prog drop ec_data_prep
prog def ec_data_prep
{

  /* define syntax for entering the required argument, and optional
  'state' name */
  syntax, Year(string) Filename(string)

  /* display what the program does, and the time */
  disp_nice "PREPARING EC`year' DATA: $S_TIME"

  /* open up file to be cleaned */
  use ~/iec/ec/ec`year'/ec`year'data/`filename'.dta
    
  /* run the data cleaning program */
  noi disp "Cleaning the data"
  ec_clean, year("`year'")

  /* move NIC08 = 744 (nonexistent) into 749, the catch-all for 74*
  codes. this is an EC13-specific data entry error. */
  if "`year'" == "13" {  
    replace NIC08_3d = "749" if NIC08_3d == "744"
  }

  /* get nic var and list of hired employment vars into locals */
  prep_ec_nic_collapse_locals `year'
  
  /* merge in our NIC code supergroups. this depends on keys created
  by prep_ec_NIC_keys (defined in this file) */
  merge m:1 `nic_var' using $keys/`nic_var'_shric_key.dta, keepusing(shric)

  /* instead of dropping unmatched observations, replace employment
  variables with zeroes - because we know that these villages were
  visited, and that they have zero employment in non-agricultural
  industries. but also add the ag totals to new vars so they are
  available if needed. */
  foreach var in `ec_emp_vars' {

    /* create ag vars, labelled correctly */
    local label : var label `var'
    gen ag_`var' = `var' if _merge == 1
    label var ag_`var' "`label': ag codes"

    /* remove ag employment from main emp vars */
    replace `var' = 0 if _merge == 1
  }

  /* remove merge variable, and and shrics that have no representation in the raw data */
  drop if _merge == 2
  drop _merge

  /* generate additional vars */
  generate_ec_variables ${gen_tab_vars_`year'}, year(`year')
  generate_ec_variables ${gen_only_vars_`year'}, year(`year')

  /* now confirm we don't have duplicate emp vars - just want "emp" */
  drop emp_all

  /* encode power and finance which shouldn't be in strings */
  foreach v in power finance {
    cap encode `v', gen(`v'_enc)
    cap drop `v'
    cap ren `v'_enc `v'
  }

  /* encode caste back into a categorical for efficiency */
  /* hack: keep st / sc vars to let collapse expansions run. some
  data duplication in clean files, but inefficiency not worth the
  time to fix */
  cap drop caste
  cap gen caste = 1 if gen == 1
  cap gen caste = 1 if other == 1
  replace caste = 3 if sc == 1
  replace caste = 4 if st == 1
  cap replace caste = 5 if obc == 1
  assert sc == 0 & st == 0 if caste == 1
  cap label drop caste
  label define caste 1 "1 General" 3 "3 SC" 4 "4 ST" 5 "5 OBC"
  label values caste caste

  /* reorder vars to put IDs first */
  compress
  order *id, first
}
end
/* *********** END program ec_data_prep ***************************************** */


/**************************************************************************************************/
/* program ec_clean - cleans and standardizes a single year of EC data                            */
/**************************************************************************************************/

/* adapted from PN and KN code, with additions for EC13 consistency
and other modifications. note that many of these labels were pulled
from ~/iec/ec/ec05/ec059890_code_correspondence.xls and the deprecated
code in create_ec_varlab_correspondence.do */
cap prog drop ec_clean
program def ec_clean
{

  /* only required argument is EC year - passed in as two digits */
  syntax, Year(string) [Quiet]
  
  /* make the program quiet */
//  qui {

    /* this is all code required for ec90-05 - ec13 doesn't need this stuff. */
    if "`year'" != "13" {
      
      replace village = subinstr(village, " ", "0", .)
      ren village ec`year'_village_id

      /* replace spaces as '0's for ids that are the correct stringlength but contain spaces instead of 0s */
      ren tehsil subdistrict
      replace subdistrict = subinstr(subdistrict, " ", "0", .)
      replace state = subinstr(state, " ", "0", .)
      replace district = subinstr(district, " ", "0", .)
      
      /* rename common location ids */
      ren state ec`year'_state_id
      ren district ec`year'_district_id
      ren subdistrict ec`year'_subdistrict_id

      /* destring employment count variables. first get vars into a local */
      prep_ec_nic_collapse_locals `year'

      /* loop over emp vars for this year */
      foreach var in `ec_emp_vars' {

        /* we need to destring into a new variable in case there are
        non-numeric characters. we know this is the case in at least
        one instance: ec98 female_child_hired has a non-numeric
        special character. this is a generalized solution. */
        destring `var', gen(tmp) force

        /* replace non-numeric with missing */
        replace `var' = "" if tmp >= .

        /* now destring */
        destring `var', replace
        drop tmp
      }
      
      /* drop record id */
      cap: drop ID

      /* we want to remove observations with zero employment in the
      raw data - before we make an adjustments regarding ag/nonag
      labor in further cleaning steps */
      drop if emp_all == 0
    }


    /* YEAR-SPECIFIC CODE */
    
    /* start with EC90 */
    if "`year'" == "90" {

      /* town stuff */
      gen ec`year'_town_id = ec`year'_village_id
      
      /* generate 3-digit activity code according to 1987 structure used by 3rd and 4th EC */
      /* take 3-digit code because 3-digit NIC 1987 is what corresponds to 4-digit NIC 2004 */
      gen NIC87 = substr(act, 1, 3)

      /* merge in official codes keeping only those that match official */
      merge m:1 NIC87 using $keys/NICmaster87.dta, nogen keep(match)

      /* fix orissa which matches on blocks, not subdistricts */
      if "`state'" == "19" {
        replace tehsil = block
      }

      /* flag government firms */
      gen gov = type == "3"

      /* standardize variable name for non-regulated firms (informal) - 90 */
      ren direct reg
      
      destring serial_prem, replace
      destring serial_noprem, replace
      gen premise = "1" if serial_prem == 0 & serial_noprem > 0 & !mi(serial_noprem)
      replace premise = "2" if serial_noprem == 0 & serial_prem > 0 & !mi(serial_prem)

      replace premise = "no_premise" if premise == "1"
      replace premise = "premise" if premise == "2"
      replace nature = "perennial" if nature == "1"
      replace nature = "seasonal" if nature == "2"
      replace type = "private" if type == "1"
      replace type = "co_op" if type == "2"
      replace type = "public" if type == "3"
      replace caste = "sc" if caste == "1"
      replace caste = "st" if caste == "2"
      replace caste = "gen" if caste == "3"
      replace power = "none" if power == "1"
      replace power = "elec" if power == "2"
      replace power = "coal" if power == "3"
      replace power = "petrol" if power == "4" | power == "8"
      replace power = "gas" if power == "5"
      replace power = "wood" if power == "6"
      replace power = "animal" if power == "9"
      replace power = "non_convent" if power == "7"
      replace power = "other" if power == "0"
      replace class = "ag" if class == "1"
      replace class = "non_ag" if class == "2"
      replace reg = "none" if reg == "2" | reg == "3"
      replace reg = "registered" if reg == "1"

      foreach var of varlist premise nature type reg caste power class {
        replace `var' = trim(`var')
        replace `var' = "" if regexm(`var', "^[0-9]$")
      }

      /* shorten a bunch of the variable labels */
      label var class "Ag or non-ag ent"
      label var nature "Perenn or Seas ent"
      label var type "Type of ownership"
      label var caste "Social group of owner"
      label var power "Power used for ent"
      label var male_all "Males inc unpaid"
      label var female_all "Femalse inc unpaid"
      label var emp_hired "M + F hired"
    }

    if "`year'" == "98" {

      /* town stuff */
      gen town = ec`year'_village_id
      replace town = substr(town, 1, 2)
      ren town ec`year'_town_id
      
      /* generate 3-digit activity code according to 1987 structure used by 3rd and 4th EC */
      /* take 3-digit code because 3-digit NIC 1987 is what corresponds to 4-digit NIC 2004 */
      gen NIC87 = substr(act, 1, 3)

      /* merge in official codes keeping only those that match official */
      merge m:1 NIC87 using $keys/NICmaster87.dta, nogen keep(match)

      replace premise = "no_premise" if premise == "1"
      replace premise = "premise" if premise == "2"
      replace nature = "perennial" if nature == "1"
      replace nature = "seasonal" if nature == "2"
      replace type = "government" if type == "4"
      replace type = "non_profit_priv" if type == "1"
      replace type = "unincorp_proprietary" if type == "2"
      replace type = "unincorp_partnership" if type == "2"
      replace type = "corp_nonfin" if type == "2"
      replace type = "corp_fin" if type == "2"
      replace type = "co_op" if type == "3"
      replace caste = "female_st" if caste == "1"
      replace caste = "female_sc" if caste == "3"
      replace caste = "female_obc" if caste == "5"
      replace caste = "female_other" if caste == "7"
      replace caste = "male_st" if caste == "2"
      replace caste = "male_sc" if caste == "4"
      replace caste = "male_obc" if caste == "6"
      replace caste = "male_other" if caste == "8"
      replace caste = "other" if caste == "9"
      replace power = "none" if power == "0"
      replace power = "elec" if power == "1"
      replace power = "coal" if power == "2"
      replace power = "petrol" if power == "3" | power == "6"
      replace power = "gas" if power == "4"
      replace power = "wood" if power == "5"
      replace power = "animal" if power == "7"
      replace power = "non_convent" if power == "8"
      replace power = "other" if power == "9"
      replace reg = "none" if reg == "0" | reg == "00"
      replace reg = "factory_1948" if reg == "1"
      replace reg = "state_direc_ind" if reg == "2"
      replace reg = "kvic_kviv" if reg == "3"
      replace reg = "powerloom_handloom" if reg == "4" | reg == "5"
      replace reg = "textile_commissioner" if reg == "6"
      replace reg = "other" if reg == "7"
      replace reg = "other" if reg == "8"
      replace reg = "other" if reg == "9"
      replace reg = "other" if reg == ""
      replace finance = "none_self" if finance == "5"
      replace finance = "gov" if finance == "1" | finance == "2"
      replace finance = "bank" if finance == "3"
      replace finance = "informal" if finance == "4"
      replace finance = "other" if finance == "6"
      replace class = "ag" if class == "1"
      replace class = "non_ag" if class == "2"

      foreach var of varlist premise nature type reg caste finance power class {
        replace `var' = trim(`var')
        replace `var' = "" if regexm(`var', "^[0-9]$")
      }

      /* shorten a bunch of the variable labels */
      label var class "Ag or non-ag ent"
      label var nature "Perenn or Seas ent"
      label var type "Type of ownership"
      label var caste "Social group of owner"
      label var power "Power used for ent"
      label var male_adult_hired "Hired adult M usually working"
      label var female_adult_hired "Hired adult F usually working"
      label var male_child_hired "Hired child M usually working"
      label var female_child_hired "Hired child F usually working"
      label var emp_hired "M + F + C hired"
      label var formal "Formality of ent"
    }

    if "`year'" == "05" {

      /* fix town */
      cap replace town = subinstr(town, " ", "0", .)
      cap ren town ec`year'_town_id
      
      /* rename activity code given according to NIC 2004 Structure */
      ren act NIC04

      /* standardize variable name for non-regulated firms (informal) - 05 */
      ren reg1 reg
      
      /* keep only codes that merge with official structure to ensure correct code */
      merge m:1 NIC04 using $keys/NICmaster04.dta, nogen keep(match)

      replace premise = "no_premise" if premise == "1"
      replace premise = "premise" if premise == "2"
      replace nature = "perennial" if nature == "1"
      replace nature = "seasonal" if nature == "2"
      replace type = "government" if type == "1"
      replace type = "non_profit_priv" if type == "2"
      replace type = "unincorp_proprietary" if type == "3"
      replace type = "unincorp_partnership" if type == "4"
      replace type = "corp_nonfin" if type == "5"
      replace type = "corp_fin" if type == "6"
      replace type = "co_op" if type == "7"
      replace caste = "female_st" if caste == "1"
      replace caste = "female_sc" if caste == "2"
      replace caste = "female_obc" if caste == "3"
      replace caste = "female_other" if caste == "4"
      replace caste = "male_st" if caste == "5"
      replace caste = "male_sc" if caste == "6"
      replace caste = "male_obc" if caste == "7"
      replace caste = "male_other" if caste == "8"
      replace caste = "other" if caste == "9"
      replace power = "none" if power == "1"
      replace power = "elec" if power == "2"
      replace power = "coal" if power == "3"
      replace power = "petrol" if power == "4"
      replace power = "gas" if power == "5"
      replace power = "wood" if power == "6"
      replace power = "animal" if power == "7"
      replace power = "non_convent" if power == "8"
      replace power = "other" if power == "9"
      replace reg = "none" if reg == "0"
      replace reg = "factory_1948" if reg == "1"
      replace reg = "state_direc_ind" if reg == "2"
      replace reg = "kvic_kviv" if reg == "3"
      replace reg = "powerloom_handloom" if reg == "4"
      replace reg = "textile_commissioner" if reg == "5"
      replace reg = "other" if reg == "6"
      replace reg = "other" if reg == "7"
      replace reg = "other" if reg == "8"
      replace reg = "other" if reg == "9"
      replace finance = "none_self" if finance == "0"
      replace finance = "gov" if finance == "1"
      replace finance = "bank" if finance == "2"
      replace finance = "informal" if finance == "3"
      replace finance = "other" if finance == "9"
      replace class = "ag" if class == "1"
      replace class = "non_ag" if class == "2"

      foreach var of varlist premise nature type reg caste finance power class {
        replace `var' = trim(`var')
        replace `var' = "" if regexm(`var', "^[0-9]$")
      }

      /* New code */

      /* gen 4d nomenclature for nic04 in case it is needed by other
      code */
      gen NIC04_4d = NIC04
      
      /* shorten a bunch of the variable labels */
      label var class "Ag or non-ag ent"
      label var premise "Premise code"
      label var nature "Perenn or Seas ent"
      label var type "Type of ownership"
      label var caste "Social group of owner"
      label var power "Power used for ent"
      label var male_adult_all "Adult M usually working"
      label var female_adult_all "Adult F usually working"
      label var male_child_all "Child M usually working"
      label var female_child_all "Child F usually working"
      label var emp_all "Tot M + F + C employees"
      label var male_adult_non "Adult M nonhired usually working"
      label var female_adult_non "Adult F nonhired usually working"
      label var male_child_non "Child M nonhired usually working"
      label var female_child_non "Child F nonhired usually working"
      label var emp_non "M + F + C  nonhired usually working"
    }

    if "`year'" == "13" {

      /* give ourselves a town ID for merging */
      gen ec13_town_id = ec13_village_id
      
      /* remove ec13 prefixes for processing consistency with other ec
      years. */
      foreach var in emp* sector finance nature religion caste sex ownership handicraft nic activity insidehh house ebx* {
        rename ec13_`var' `var'
      }

      /* ec13 is the only ec year that has sector as numeric. change
      to string for consistency */
      tostring sector, gen(sctr)
      drop sector
      rename sctr sector
      
      /* rename some variables for consistency with other EC years */
      rename ownership type
      rename activity act
      
      /* shorten some labels */
      label var emp_hired_m "Tot. emp. hired (m)"
      label var emp_hired_f "Tot. emp. hired (f)"
      label var emp_unhired_m "Tot. emp. unhired (m)"
      label var emp_unhired_f "Tot. emp. unhired (f)"
      label var emp_all "Tot. employment"
      
      /* Create 3-digit NIC var */
      gen NIC08_3d = string(nic, "%03.0f")
    }
//  }
}
end
/* *********** END program ec_clean ***************************************** */
