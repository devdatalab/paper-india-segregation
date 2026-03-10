
global estout_params       cells(b(fmt(3) star) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(N r2, fmt(0 2)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\$^{*}p<0.10, ^{**}p<0.05, ^{***}p<0.01\$} \\" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
global estout_params_no_p  cells(b(fmt(3) star) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(N r2, fmt(0 2)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
global estout_params_np    cells(b(fmt(3) star) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(N r2, fmt(0 2)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline)                 postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\$^{*}p<0.10, ^{**}p<0.05, ^{***}p<0.01\$} \\" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
global estout_params_scr   cells(b(fmt(3) star) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(N r2, fmt(0 2)) collabels(none)
global estout_params_txt   cells(b(fmt(3) star) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(N r2, fmt(0 2)) collabels(none) replace
global ep_txt $estout_params_txt
global estout_params_excel cells(b(fmt(3) star) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(N r2, fmt(0 2)) collabels(none) style(tab)  replace
global estout_params_html  cells(b(fmt(3) star) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(N r2, fmt(0 2)) collabels(none) style(html) replace prehead("<html><body><table style='border-collapse:collapse;' border=1") postfoot("</table></body></html>")
global estout_params_fstat cells(b(fmt(3) star) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(f_stat N r2, labels("F Statistic" "N" "R2" suffix(\hline)) fmt(%9.4g)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{$^{*}p<0.10, ^{**}p<0.05, ^{***}p<0.01$} \\" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
global tex_p_value_line "\multicolumn{@span}{p{\linewidth}}{\$^{*}p<0.10, ^{**}p<0.05,^{***}p<0.01\$} \\"
global esttab_params       prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
/***********************************************************************************************/
/* program name_clean : standardize format of indian place names before merging                */
/***********************************************************************************************/
capture program drop name_clean
program def name_clean
  {
    syntax varname, [dropparens GENerate(name) replace]
    tokenize `varlist'
    local name = "`1'"

    if mi("`generate'") & mi("`replace'") {
      display as error "name_clean: generate or replace must be specified"
      exit 1
    }

    /* if no generate specified, make replacements to same variable */
    if mi("`generate'") {
      local name = "`1'"
    }

    /* if generate specified, copy the variable and then slowly change it */
    else {
      gen `generate' = `1'
      local name = "`generate'"
    }

    qui {
      /* lowercase, trim, trim sequential spaces */
      replace `name' = trim(itrim(lower(`name')))

      /* parentheses should be spaced as follows: "word1 (word2)" */
      /* [ regex correctly treats second parenthesis with everything else in case it is missing ] */
      replace `name' = regexs(1) + " (" + regexs(2) if regexm(`name', "(.*[a-z])\( *(.*)")

      /* drop spaces before close parenthesis */
      replace `name' = subinstr(`name', " )", ")", .)

      /* name_clean removes ALL special characters including parentheses but leaves dashes only for -[0-9]*/
      /* parentheses are removed at the very end to facilitate dropparens and numbers changes */

      /* convert punctuation to spaces */
      /* we don't use regex here because we would need to loop to get all replacements made */
      replace `name' = subinstr(`name',"*"," ",.)
      replace `name' = subinstr(`name',"#"," ",.)
      replace `name' = subinstr(`name',"@"," ",.)
      replace `name' = subinstr(`name',"$"," ",.)
      replace `name' = subinstr(`name',"&"," ",.)
      replace `name' = subinstr(`name', "-", " ", .)
      replace `name' = subinstr(`name', ".", " ", .)
      replace `name' = subinstr(`name', "_", " ", .)
      replace `name' = subinstr(`name', "'", " ", .)
      replace `name' = subinstr(`name', ",", " ", .)
      replace `name' = subinstr(`name', ":", " ", .)
      replace `name' = subinstr(`name', ";", " ", .)
      replace `name' = subinstr(`name', "*", " ", .)
      replace `name' = subinstr(`name', "|", " ", .)
      replace `name' = subinstr(`name', "?", " ", .)
      replace `name' = subinstr(`name', "/", " ", .)
      replace `name' = subinstr(`name', "\", " ", .)
      replace `name' = subinstr(`name', `"""', " ", .)
        * `"""' this line to correct emacs syntax highlighting) '

      /* replace square and curly brackets with parentheses */
      replace `name' = subinstr(`name',"{","(",.)
      replace `name' = subinstr(`name',"}",")",.)
      replace `name' = subinstr(`name',"[","(",.)
      replace `name' = subinstr(`name',"]",")",.)
      replace `name' = subinstr(`name',"<","(",.)
      replace `name' = subinstr(`name',">",")",.)

      /* trim once now and again at the end */
      replace `name' = trim(itrim(`name'))

      /* punctuation has been removed, so roman numerals must be separated by spaces */

      /* to be replaced, roman numerals must be preceded by ward, pt, part, no or " " */

      /* roman numerals to digits when they appear at the end of a string */
      /* require a space in front of the ones that could be ambiguous (e.g. town ending in 'noi') */
      replace `name' = regexr(`name', "(ward ?| pt ?| part ?| no ?| )i$", "1")
      replace `name' = regexr(`name', "(ward ?| pt ?| part ?| no ?| )ii$", "2")
      replace `name' = regexr(`name', "(ward ?| pt ?| part ?| no ?| )iii$", "3")
      replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?| )iv$", "4")
      replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?| )iiii$", "4")
      replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?)v$", "5")
      replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?| )iiiii$", "5")
      replace `name' = regexr(`name', "(ward ?|pt ?|part ?| no ?| )vi$", "6")
      replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?| )vii$", "7")
      replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?| )viii$", "8")
      replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?| )ix$", "9")
      replace `name' = regexr(`name', "(ward ?|pt ?|part ?| no ?| )x$", "10")
      replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?| )xi$", "11")

      /* replace roman numerals in parentheses */
      replace `name' = subinstr(`name', "(i)",     "1", .)
      replace `name' = subinstr(`name', "(ii)",    "2", .)
      replace `name' = subinstr(`name', "(iii)",   "3", .)
      replace `name' = subinstr(`name', "(iv)",    "4", .)
      replace `name' = subinstr(`name', "(iiii)",  "4", .)
      replace `name' = subinstr(`name', "(v)",     "5", .)
      replace `name' = subinstr(`name', "(iiiii)", "5", .)

      /* prefix any digits with a dash, unless the number is right at the start */
      replace `name' = regexr(`name', "([0-9])", "-" + regexs(1)) if regexm(`name', "([0-9])") & mi(real(substr(`name', 1, 1)))

      /* but change numbers that are part of names to be written out */
      replace `name' = subinstr(`name', "-24", "twenty four", .)

      /* don't leave a space before a dash [the only dashes left were inserted by the # steps above] */
      replace `name' = subinstr(`name', " -", "-", .)

      /* standardize trailing instances of part/pt to " part" */
      replace `name' = regexr(`name', " pt$", " part")
      replace `name' = regexr(`name', " \(pt\)$", " part")
      replace `name' = regexr(`name', " \(part\)$", " part")

      /* take important words out of parentheses */
      replace `name' = subinstr(`name', "(urban)", "urban", .)
      replace `name' = subinstr(`name', "(rural)", "rural", .)
      replace `name' = subinstr(`name', "(east)", "east", .)
      replace `name' = subinstr(`name', "(west)", "west", .)
      replace `name' = subinstr(`name', "(north)", "north", .)
      replace `name' = subinstr(`name', "(south)", "south", .)

      /* drop anything in parentheses?  do it twice in case of multiple parentheses. */
      /* NOTE: this may result in excess matches. */
      if "`dropparens'" == "dropparens" {
        replace `name' = regexr(`name', "\([^)]*\)", "")
        replace `name' = regexr(`name', "\([^)]*\)", "")
        replace `name' = regexr(`name', "\([^)]*\)", "")
        replace `name' = regexr(`name', "\([^)]*\)", "")
      }

      /* drop the word "village" and "vill" */
      replace `name' = regexr(`name', " vill(age)?", "")

      /* after making all changes that rely on parentheses, remove parenthese characters */
      /* since names with parens are already formatted word1 (word2) replace as "" */
      replace `name' = subinstr(`name',"(","",.)
      replace `name' = subinstr(`name',")"," ",.)

      /* trim again */
      replace `name' = trim(itrim(`name'))
    }
  }
end
/* *********** END program name_clean ***************************************** */


  /**********************************************************************************/
  /* program append_to_file : Append a passed in string to a file                   */
  /**********************************************************************************/
  cap prog drop append_to_file
  prog def append_to_file
  {
    syntax using/, String(string) [format(string) erase]

    tempname fh

    cap file close `fh'

    if !mi("`erase'") cap erase `using'

    file open `fh' using `using', write append
    file write `fh'  `"`string'"'  _n
    file close `fh'
  }
  end
  /* *********** END program append_to_file ***************************************** */


  /**********************************************************************************/
  /* program disp_nice : Insert a nice title in stata window */
  /***********************************************************************************/
  cap prog drop disp_nice
  prog def disp_nice
  {
    di _n "+--------------------------------------------------------------------------------------" _n `"| `1'"' _n  "+--------------------------------------------------------------------------------------"
  }
  end
  /* *********** END program disp_nice ***************************************** */


/**********************************************************************************/
/* program label_from_csv : Apply variable labels from a local two-column CSV     */
/***********************************************************************************/
cap prog drop label_from_csv
prog def label_from_csv
  {
    syntax using/

    tempname fh
    tempfile label_cmds

    cap confirm file `"`using'"'
    if _rc {
      di as error "label_from_csv: csv file not found: `using'"
      exit 601
    }

    preserve
      quietly import delimited using `"`using'"', clear varnames(nonames) stringcols(_all)

      cap confirm variable v2
      if _rc {
        restore
        di as error "label_from_csv: expected at least two columns in `using'"
        exit 198
      }

      keep v1 v2
      rename v1 __label_varname
      rename v2 __label_text

      replace __label_varname = strtrim(__label_varname)
      replace __label_text = strtrim(__label_text)

      /* handle files with an explicit header row */
      drop if _n == 1 & inlist(lower(__label_varname), "var_name (name of variables)", "var_name", "varname", "variable") ///
        & (strpos(lower(__label_text), "description") | strpos(lower(__label_text), "label"))

      drop if mi(__label_varname) | mi(__label_text)

      file open `fh' using `label_cmds', write replace text
      quietly count
      local n = r(N)

      forvalues i = 1/`n' {
        local varname = __label_varname[`i']
        local varlabel = __label_text[`i']
        local varlabel = subinstr(`"`varlabel'"', `"""', "'", .)

        if !mi("`varname'") & !mi("`varlabel'") {
          file write `fh' `"capture label variable `varname' "`varlabel'""' _n
        }
      }
      file close `fh'
    restore

    do `label_cmds'
  }
end
/* *********** END program label_from_csv ***************************************** */


/**********************************************************************************/
/* program flag_outliers : Mark outliers */
/***********************************************************************************/
cap prog drop flag_outliers
prog def flag_outliers
  {
    syntax varlist(min=1), range(numlist) [badvar(name)] [pct] [drop]

    if mi("`badvar'") {
      local badvar __bad
      cap drop __bad
    }

    tokenize `range'

    /* create flag variable if it doesn't exist yet */
    cap gen `badvar' = 0
    assert inlist(`badvar', 0, 1)

    foreach var of varlist `varlist' {

      if !mi("`pct'") {
        qui centile `var', centile(`1' `2')
        di "Flagging observations of `var' not in range(`r(c_1)', `r(c_2)')..."
        replace `badvar' = 1 if !inrange(`var', `r(c_1)', `r(c_2)') & !mi(`var')
      }
      else {
        di "Flagging observations of `var' not in range(`1', `2')..."
        replace `badvar' = 1 if !inrange(`var', `1', `2') & !mi(`var')
      }
    }
    if !mi("`drop'") {
      drop if `badvar' == 1
      drop `badvar'
    }
  }
end
/* *********** END program flag_outliers ***************************************** */


  /**********************************************************************************/
  /* program capdrop : Drop a bunch of variables without errors if they don't exist */
  /**********************************************************************************/
  cap prog drop capdrop
  prog def capdrop
  {
    syntax anything
    foreach v in `anything' {
      cap drop `v'
    }
  }
  end
  /* *********** END program capdrop ***************************************** */


  /*********************************************************************************/
  /* program winsorize: replace variables outside of a range(min,max) with min,max */
  /*********************************************************************************/
  cap prog drop winsorize
  prog def winsorize
  {
    syntax anything,  [REPLace GENerate(name) centile]

    tokenize "`anything'"

    /* require generate or replace [sum of existence must equal 1] */
    if (!mi("`generate'") + !mi("`replace'") != 1) {
      display as error "winsorize: generate or replace must be specified, not both"
      exit 1
    }

    if ("`1'" == "" | "`2'" == "" | "`3'" == "" | "`4'" != "") {
      di "syntax: winsorize varname [minvalue] [maxvalue], [replace generate] [centile]"
      exit
    }
    if !mi("`replace'") {
      local generate = "`1'"
    }
    tempvar x
    qui gen `x' = `1'


    /* reset bounds to centiles if requested */
    qui if !mi("`centile'") {

      centile `x', c(`2')
      local 2 `r(c_1)'

      centile `x', c(`3')
      local 3 `r(c_1)'
    }

    qui replace `x' = `2' if `x' < `2'
    qui replace `x' = `3' if `x' > `3' & !mi(`x')

    if !mi("`replace'") {
      replace `1' = `x'
    }
    else {
      generate `generate' = `x'
    }
  }
  end
  /* *********** END program winsorize ***************************************** */


  /********************************************************************************************/
  /* program is_unique : Asserts that a variable combination uniquely identifies observations */
  /********************************************************************************************/
  cap prog drop is_unique
  prog def is_unique
  {
    syntax varlist
    bys `varlist': assert _N == 1
  }
  end
  /* *********** END program is_unique ***************************************** */


/********************************************************************************/
/* program town_name_clean : extension of name_clean with town-specific changes */
/********************************************************************************/
/* clean town names using standard name_clean program + town-specific changes   */
/*   dropabbrev - always specify unless specific reason to keep civic status    */
/*   droppart - specify after inspecting 'part' 'minor/major part' instances    */
/*   dropstatus - specify for base town name, compatability to outside sources, */
/*                not for merging purposes                                      */
/*   dropcantt - drops ' cantonment$', separated from dropstatus for importance */
/*   dropparens - drops everything enclosed in parentheses                      */
/*                                                                              */
/* standard usage: town_name_clean pc01_town_name, droppart dropabbrev replace  */
cap prog drop town_name_clean
prog def town_name_clean
  {
    syntax varname, [dropparens droppart dropabbrev dropstatus dropcantt GENerate(name) replace]
    tokenize `varlist'
    local name = "`1'"

    /* if no generate specified, make replacements to same variable */
    if mi("`generate'") {
      local name = "`1'"
    }

    /* if generate specified, copy the variable and then slowly change it */
    else {
      gen `generate' = `1'
      local name = "`generate'"
    }

    /* call main name clean program */
    name_clean `name', replace `dropparens'

    /* standardize all town status abbreviations/occurences */

    /* standardize and write out all usages of Cantonment */
    replace `name' = regexr(`name', " cantonmen$", " cantonment")
    replace `name' = regexr(`name', " cantontment", " cantonment")
    replace `name' = regexr(`name', "cantt$", " cantonment")
    replace `name' = regexr(`name', " cant$", " cantonment")
    replace `name' = regexr(`name', " cantt ", " cantonment ")
    replace `name' = regexr(`name', " cantonment board", " cantonment")
    replace `name' = regexr(`name', " cb$", " cantonment") if !regexm(`name', "cantonment")
    replace `name' = regexr(`name', " c b$", " cantonment") if !regexm(`name', "cantonment")
    replace `name' = regexr(`name', " cb$", "") if regexm(`name', "cantonment")
    replace `name' = regexr(`name', " c b$", "") if regexm(`name', "cantonment")
    /* standardize mid-word cantonment usages for town names with trailing " part$" */
    replace `name' = regexr(`name', " cb", " cantonment") if !regexm(`name', "cantonment") & regexm(`name', "part")
    replace `name' = regexr(`name', " c b", " cantonment") if !regexm(`name', "cantonment") & regexm(`name', "part")
    replace `name' = regexr(`name', " cb", "") if regexm(`name', "cantonment") & regexm(`name', "part")
    replace `name' = regexr(`name', " c b", "") if regexm(`name', "cantonment") & regexm(`name', "part")

    /* write out important names */
    replace `name' = subinstr(`name', "metro", "metropolitan", .) if !regexm(`name', "metropolitan")
    replace `name' = subinstr(`name', " settlemen", " settlement", .) if !regexm(`name', "settlement")
    replace `name' = subinstr(`name', " settlem", " settlement", .) if !regexm(`name', "settlement")
    replace `name' = subinstr(`name', " settl", " settlement", .) if !regexm(`name', "settlement")
    replace `name' = regexr(`name', " ng$", " nagar")
    replace `name' = regexr(`name', "rly ", "railway ") if regexm(`name', "(\+| )+(rly )") | regexm(`name', "^rly ")

    /* write out important abbreviations */
    replace `name' = regexr(`name', "^n ", "north ") if regexm(`name', "^n [a-z][a-z]") & !regexm(`name', "n d") & !regexm(`name', "ndmc")
    replace `name' = regexr(`name', "b h e l ", "bharat heavy electricals")
    replace `name' = regexr(`name', "ltd ", "limited ")
    replace `name' = regexr(`name', " r f c$", " right flank colony")
    replace `name' = regexr(`name', " clny$", " colony")
    replace `name' = regexr(`name', " cly$", " colony")

    /* concat mid-name abbrevations */
    replace `name' = regexr(`name', " h q ", " hq ")
    replace `name' = regexr(`name', " m c ", " mc ")
    replace `name' = regexr(`name', " i o c ", " ioc ")
    replace `name' = regexr(`name', " d f ", " df ")
    replace `name' = regexr(`name', " t p ", " tp ")

    /* concat trailing abbreviations */
    replace `name' = regexr(`name', " i n a$", " ina")
    replace `name' = regexr(`name', " u a$", " ua")
    replace `name' = regexr(`name', " o g$", " og")

    /* remove trailing instances of "urban", differentiated from "suburban$" with a space */
    replace `name' = regexr(`name', " urban$", "")

    /* drop trailing circle, block, etc. */
    replace `name' = regexr(`name', " subdivision$", "")
    replace `name' = regexr(`name', " division$", "")
    replace `name' = regexr(`name', " div$", "")
    replace `name' = regexr(`name', " sub$", "")
    replace `name' = regexr(`name', " new$", "")

    /* standardize important prefixes: sas nagar (sas nagar mohali) */
    replace `name' = regexr(`name', "s a s nagar", "sas nagar")

    /* standardize important abbreviations: m, ina, ct */
    replace `name' = regexr(`name', " ina ina$", " ina")
    replace `name' = regexr(`name', " c t$", " ct")
    replace `name' = regexr(`name', " census town$", " ct")

    /* drop non-essential trailing abbreviations found in district/subdistrict and town names */
    replace `name' = regexr(`name', " s t$", "")
    replace `name' = regexr(`name', " st$", "")
    replace `name' = regexr(`name', " tc$", "")
    replace `name' = regexr(`name', " p s$", "")
    replace `name' = regexr(`name', " tp$", "")
    replace `name' = regexr(`name', " p$", "")
    replace `name' = regexr(`name', " t$", "")

    /* drop non-essential town-specific number/status abbreviations ex. "hq bl i-7" or "m corp part eb no-23" */
    replace `name' = regexr(`name', "( hq)(.*[a-z])(\-[0-9])", "")
    replace `name' = regexr(`name', "( m corp)(.*[a-z])(\-[0-9])", "")
    replace `name' = regexr(`name', "( m )(.*[a-z])(\-[0-9])(.*[0-9]$)", "")
    replace `name' = regexr(`name', "( ward)(.*)(\-([0-9]+)$)", "")
    replace `name' = regexr(`name', "( eb no)(.*)(\-([0-9]+)$)", "")
    replace `name' = regexr(`name', "( no)( |\-)+(i|1)+", "")

    /* standardize/replace unrecognized characters: "á"/ char\341 */
    qui charlist `name'
    replace `name' = subinstr(`name', "`=char(225)'", "a", .)
    replace `name' = subinstr(`name', "á", "a", .)

    /* drop dash off beginning of town name that starts with number */
    replace `name' = regexr(`name', "^\-", "")

    /* add option to drop trailing part instances before dropping town abbreviations */
    /* NOTE: only use this option after parts have been reviewed */
    if "`droppart'" == "droppart" {
      replace `name' = regexr(`name', " minor part$", "")
      replace `name' = regexr(`name', " major part$", "")
      replace `name' = regexr(`name', " part$", "")
    }

    /* drop civic status abbreviations specific only to town names, mostly non-essential */
    /* NOTE: this may result in excess matches or non-unique town names */
    if "`dropabbrev'" == "dropabbrev" {
      replace `name' = regexr(`name', " \+ og$", "")
      replace `name' = regexr(`name', "\+og$", "")
      replace `name' = regexr(`name', " og$", "")
      replace `name' = regexr(`name', " h q$", "")
      replace `name' = regexr(`name', " hq$", "")
      replace `name' = regexr(`name', " amc$", "")
      replace `name' = regexr(`name', " iw$", "")
      replace `name' = regexr(`name', " gp$", "")
      replace `name' = regexr(`name', " na$", "")
      replace `name' = regexr(`name', " nt$", "")
      replace `name' = regexr(`name', " np$", "")
      replace `name' = regexr(`name', " npp$", "")
      replace `name' = regexr(`name', " n$", "")
      replace `name' = regexr(`name', " nm$", "")
      replace `name' = regexr(`name', " ci$", "")
      replace `name' = regexr(`name', " cmc$", "")
      replace `name' = regexr(`name', " tmc$", "")
      replace `name' = regexr(`name', " tc$", "")
      replace `name' = regexr(`name', " m cl$", "")
      replace `name' = regexr(`name', " m corp$", "")
      replace `name' = regexr(`name', " mci$", "")
      replace `name' = regexr(`name', " mcl$", "")
      replace `name' = regexr(`name', " mc$", "") if !regexm(`name', "n d mc")
      replace `name' = regexr(`name', " m c$", "") if !regexm(`name', "n d m c")
      replace `name' = regexr(`name', " mb$", "")
      replace `name' = regexr(`name', " m$", "")
      replace `name' = regexr(`name', " its$", "")
      replace `name' = regexr(`name', " ts$", "")
      replace `name' = regexr(`name', " rs$", "")
      replace `name' = regexr(`name', " s$", "")
      replace `name' = regexr(`name', " nac$", "")
      replace `name' = regexr(`name', " vp$", "")
      replace `name' = regexr(`name', " v$", "")
    }

    /* drop all remaining instances of town civic status left after dropabbrev */
    /* drop abbreviations verified as non-essential for matching to outside sources (Google, WB, etc.) */
    /* but drop separately from dropabbrev, because these status abbreviations may be important for matching */
    /*   (Notes: dropped abbreviations have been inspected via Google Maps to ensure refer to the same town) */
    /*   (inspected: oil town -> oil OK, hindusthan cables OK, bokaro steel OK, remove township nta ina, etc. good) */
    /*   (need: " ioc$" (only remaining status abbrev)) */
    /*   (cantonment: " cantonment$" increases coordinate accuracy, recognized by outside sources, do not drop) */
    if "`dropstatus'" == "dropstatus" {
      di "Warning: Dropping all civic status abbreviations! (except 'cantonment$')"
      di "Dropping city, town, nta, spl, ct, right flank colony"
      di "Keeping township, ina, cantonment"
      di "These trailing abbreviations may be important for matching. Use only for outside sources."
      replace `name' = regexr(`name', " ct$", "")
      replace `name' = regexr(`name', " city$", "")
      replace `name' = regexr(`name', " limited township$", "")
      replace `name' = regexr(`name', " right flank colony township$", "")
      replace `name' = regexr(`name', " spl$", "")
      replace `name' = regexr(`name', " town$", "")
      replace `name' = regexr(`name', " nta$", "")
    }
    /* drop 'cantonment' status from end of town name separately from dropstatus due to importance of cantonment */
    /* if specified with dropabbrev + dropstatus, this removes all civic status, only remaining: ' ioc' */
    if "`dropcantt'" == "dropcantt" {
      di "Warning: Dropping ' cantonment' from town names!"
      di "Cantonment is usually important to identifying towns, not recommended."
      replace `name' = regexr(`name', " cantonment$", "")
    }

    /* write out and standardize important large town names after dropping abbreviations */
    /* standardize large towns by spelling out abbreviations */
    replace `name' = "new delhi municipal council" if `name' == "n d mc" | `name' == "n d m c" | `name' == "ndmc"
    replace `name' = "new delhi municipal council part" if ((regexm(`name', "n d m c") | regexm(`name', "ndmc")) & regexm(`name', " part$"))
    replace `name' = "delhi municipal corporation" if `name' == "dmc" | `name' == "dmc u" | `name' == "d m c"
    replace `name' = "delhi municipal corporation part" if (regexm(`name', "dmc") & regexm(`name', " part$"))
    replace `name' = "greater hyderabad municipal corporation" if `name' == "ghmc"
    replace `name' = "greater hyderabad municipal corporation part" if `name' == "ghmc part"
    replace `name' = "greater visakhapatnam municipal corporation" if `name' == "gvmc"
    replace `name' = "greater visakhapatnam municipal corporation part" if `name' == "gvmc part"
    replace `name' = "bruhat bengaluru mahanagara palike" if `name' == "bbmp"
    replace `name' = "bruhat bengaluru mahanagara palike part" if `name' == "bbmp part"

    /* trim */
    replace `name' = trim(itrim(`name'))
  }
end

/** END program town_name_clean ************************************************************/


  /*********************************************************************************************************/
  /* program ddrop : drop any observations that are duplicated - not to be confused with "duplicates drop" */
  /*********************************************************************************************************/
  cap prog drop ddrop
  cap prog def ddrop
  {
    syntax varlist(min=1) [if]

    /* do nothing if no observations */
    if _N == 0 exit

    /* `0' contains the `if', so don't need to do anything special here */
    duplicates tag `0', gen(ddrop_dups)
    drop if ddrop_dups > 0 & !mi(ddrop_dups)
    drop ddrop_dups
  }
end
/* *********** END program ddrop ***************************************** */


  /**********************************************************************************/
  /* program group : Fast way to use egen group()                  */
  /**********************************************************************************/
  cap prog drop regroup
  prog def regroup
    syntax anything [if]
    group `anything' `if', drop
  end

  cap prog drop group
  prog def group
  {
    syntax anything [if], [drop, varname(string)]

    tokenize "`anything'"

    local x = ""
    while !mi("`1'") {

      if regexm("`1'", "pc[0-9][0-9][ru]?_") {
        local x = "`x'" + substr("`1'", strpos("`1'", "_") + 1, 1)
      }
      else {
        local x = "`x'" + substr("`1'", 1, 1)
      }
      mac shift
    }

   /* define new variable name */
   if "`varname'" == "" {
     local varname `x'group
   }

    if ~mi("`drop'") cap drop `varxname'

    display `"RUNNING: egen int `varname' = group(`anything')" `if''
    egen int `varname' = group(`anything') `if'


  }
  end
  /* *********** END program group ***************************************** */


/**********************************************************************************/
/* program fail : Fail with an error message */
/***********************************************************************************/
cap prog drop fail
prog def fail
  syntax anything
  display as error "`anything'"
  error 345
end
/* *********** END program fail ***************************************** */


/**********************************************************************************/
/* program estout_default : Run default estout command with (1), (2), etc. column headers.
Generates a .tex and .html file. "using" should not have an extension.
*/
/***********************************************************************************/
cap prog drop estout_default
prog def estout_default
  {
    syntax [anything] using/ , [KEEP(passthru) MLABEL(passthru) ORDER(passthru) TITLE(passthru) HTMLonly PREFOOT(passthru) EPARAMS(string)]

    /* if mlabel is not specified, generate it as "(1)" "(2)" */
    if mi(`"`mlabel'"') {

      /* run script to get right number of column headers that look like (1) (2) (3) etc. */
      get_ecol_header_string

      /* store in a macro since estout is rclass and blows away r(col_headers) */
      local mlabel `"mlabel(`r(col_headers)')"'
    }

    /* if keep not specified, set to the same as order */
    if mi("`keep'") & !mi("`order'") {
      local keep = subinstr("`order'", "order", "keep", .)
    }

    /* set eparams string if not specified */
    //   if mi(`"`eparams'"') {
      //     local eparams `"$estout_params"'
      //   }

    /* if prefoot() is specified, pull it out of estout_params */
    if !mi("`"prefoot"'") {
      local eparams = subinstr(`"$estout_params"', "prefoot(\hline)", `"`prefoot'"', .)
    }

    //  if !mi("`prefoot'") {
      //    local eparams = subinstr(`"`eparams'"', "prefoot(\hline)", `"`prefoot'"', .)
      // }
    //  di `"`eparams'"'

    /* output tex file */
    if mi("`htmlonly'") {
      // di `" estout using "`using'.tex", `mlabel' `keep' `order' `title' `eparams' "'
      estout `anything' using "`using'.tex", `mlabel' `keep' `order' `title' `eparams'
    }

    /* output html file for easy reading */
    estout `anything' using "`using'.html", `mlabel' `keep' `order' `title' $estout_params_html

    /* if HTMLVIEW is on, copy the html file to caligari/ */
    if ("$HTMLVIEW" == "1") {

      /* make sure output folder exists */
      cap confirm file ~/public_html/html/
      if _rc shell mkdir ~/public_html/html/

      /* copy the file to HTML folder */
      shell cp  `using'.html ~/public_html/html/

      /* strip path component from the link */
      local filepart = regexr("`using'", ".*/", "")
      if !strpos("`using'", "/") local filepart `using'
      local linkpath "http://caligari.dartmouth.edu/~`c(username)'/html/`filepart'.html"
      di "View table at `linkpath'"
    }
  }
end

/* *********** END program estout_default ***************************************** */



cap pr drop graphout
pr def graphout
  syntax anything, [pdf QUIetly]
  tokenize `anything'
  graph export $out/`1'.pdf, replace
end


  /**********************************************************************************/
  /* program append_est_to_file : Appends a regression estimate to a csv file       */
  /**********************************************************************************/
  cap prog drop append_est_to_file
  prog def append_est_to_file
  {
    syntax using/, b(string) Suffix(string)

    /* get number of observations */
    qui count if e(sample)
    local n: di %15.0f (`r(N)')

    /* get b and se from estimate */
    local beta = _b["`b'"]
    local se   = _se["`b'"]

    /* get p value */
    qui test `b' = 0
    local p = `r(p)'
    if "`p'" == "." {
      local p = 1
      local beta = 0
      local se = 0
    }
    append_to_file using `using', s("`beta',`se',`p',`n',`suffix'")
  }
  end
  /* *********** END program append_est_to_file ***************************************** */


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


  /**********************************************************************************************/
  /* program quireg : display a name, beta coefficient and p value from a regression in one line */
  /***********************************************************************************************/
  cap prog drop quireg
  prog def quireg, rclass
  {
    syntax varlist(fv ts) [pweight aweight] [if], [cluster(varlist) title(string) vce(passthru) noconstant s(real 40) absorb(varlist) disponly robust]
    tokenize `varlist'
    local depvar = "`1'"
    local xvar = subinstr("`2'", ",", "", .)

    if "`cluster'" != "" {
      local cluster_string = "cluster(`cluster')"
    }

    if mi("`disponly'") {
      if mi("`absorb'") {
        cap qui reg `varlist' [`weight' `exp'] `if',  `cluster_string' `vce' `constant' robust
        if _rc == 1 {
          di "User pressed break."
        }
        else if _rc {
          display "`title': Reg failed"
          exit
        }
      }
      else {
        /* if absorb has a space (i.e. more than one var), use reghdfe */
        if strpos("`absorb'", " ") {
          cap qui reghdfe `varlist' [`weight' `exp'] `if',  `cluster_string' `vce' absorb(`absorb') `constant'
        }
        else {
          cap qui areg `varlist' [`weight' `exp'] `if',  `cluster_string' `vce' absorb(`absorb') `constant' robust
        }
        if _rc == 1 {
          di "User pressed break."
        }
        else if _rc {
          display "`title': Reg failed"
          exit
        }
      }
    }
    local n = `e(N)'
    cap local b = _b[`xvar']
    if _rc {
      di %`s's "`title' `xvar': omitted or not estimated (n=" %6.0f `n' ")"
      return scalar b = .
      return scalar se = .
      return scalar n = `n'
      return scalar p = .
      exit
    }
    local se = _se[`xvar']

    quietly test `xvar' = 0
    local star = ""
    if r(p) < 0.10 {
      local star = "*"
    }
    if r(p) < 0.05 {
      local star = "**"
    }
    if r(p) < 0.01 {
      local star = "***"
    }
    di %`s's "`title' `xvar': " %10.5f `b' " (" %10.5f `se' ")  (p=" %5.2f r(p) ") (n=" %6.0f `n' ")`star'"
    return scalar b = `b'
    return scalar se = `se'
    return scalar n = `n'
    return scalar p = r(p)
  }
  end
  /* *********** END program quireg **********************************************************************************************/


  /******************************************************************************************************/
  /* program pyfunc: Run externally defined python function without silent failures.   */
  /******************************************************************************************************/
  /* note: pyfunc exists in ~/ddl/tools/do/ado/, which is auto-loaded on polaris */
  /****** END program pyfunc ****************/


/**********************************************************************************/
/* program estmod_footer : add a footer row to an estout set */
/***********************************************************************************/
cap prog drop estmod_footer
prog def estmod_footer
  syntax using/, cstring(string)

  /* add .tex suffix to using if not there */
  if !regexm("`using'", "\.tex$") local using `using'.tex

  shell python ~/ddl/tools/py/scripts/est_modify.py -c footer -i `using' -o `using' --cstring "`cstring'"
end
/* *********** END program estmod_footer ***************************************** */


  /**********************************************************************************/
  /* program tag : Fast way to run egen tag(), using first letter of var for tag    */
  /**********************************************************************************/
  cap prog drop tag
  prog def tag
  {
    syntax anything [if]

    tokenize "`anything'"

    local x = ""
    while !mi("`1'") {

      if regexm("`1'", "pc[0-9][0-9][ru]?_") {
        local x = "`x'" + substr("`1'", strpos("`1'", "_") + 1, 1)
      }
      else {
        local x = "`x'" + substr("`1'", 1, 1)
      }
      mac shift
    }

    display `"RUNNING: egen `x'tag = tag(`anything') `if'"'
    egen `x'tag = tag(`anything') `if'
  }
  end
  /* *********** END program tag ***************************************** */
