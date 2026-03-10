/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_blockdata_urban_200.dta                 */
/* OUTPUTS:                                                            */
/*   - $out/pe_urban_`demo'_`pg'_all.pdf                                */
/* GOAL:                                                               */
/*   Estimate/plot PE functions for urban sanitation/access measures.   */
/*                                                                     */
/* Estimate sanitation/access PE decompositions across FE structures.  */
/***********************************************************************/

/**************************************/
/* program cleanup: fix some things   */
/**************************************/
cap prog drop cleanup
prog def cleanup
  drop if muslim_share > 1 | sc_share > 1
end
/** END program cleanup ***********/

/**********************************************************************/
/* program gen_pcaps: get per capita measures of schools, hospitals   */
/**********************************************************************/
cap prog drop gen_pcaps
prog def gen_pcaps

  capdrop *_emp_*_pcap sc_share muslim_share ln_block_pop

  foreach pubpriv in pub priv {
    
    /* loop over public facilities */
    qui foreach v in primary secondary hospital {
      
      /* calculate per capita employment in public facility */
      /* rescale by 100,000 to have interpretable coefficients */
      gen `v'_emp_`pubpriv'_pcap = `v'_emp_`pubpriv' / block_pop * 100000
      
      /* repeat for the dummy variable */
      gen `v'_dum_`pubpriv'_pcap = dum_`v'_`pubpriv' / block_pop * 100000
    }
  }
  
  /* calculate SC and Muslim share in this unit */
  qui foreach demo in sc muslim {
    gen `demo'_share = `demo' / block_pop
  }

  /* get log unit population  */
  gen ln_block_pop = log(block_pop)

end
/** END program gen_pcaps *********************************************/

/*************************************************************************************/
/* program prep_data: Perform basic data operations required before every analysis   */
/*************************************************************************************/
cap prog drop prep_data
prog def prep_data

  /* drop blocks outside a reasonable population range (approx 1/99th percentile) */
  keep if inrange(block_pop, 150, 1000)
  
  /* calculate SC and Muslim share in this unit */
  qui foreach demo in sc muslim {
    capdrop `demo'_share
    gen `demo'_share = `demo' / block_pop
  }

  /* get log unit population  */
  gen ln_block_pop = log(block_pop)
  
end
/** END program prep_data ************************************************************/

/*********************************************************************/
/* program graph_pe_function: Graph the political economy function   */
/*********************************************************************/
cap prog drop graph_pe_function
prog def graph_pe_function

  syntax, demo(string) pg(string) 

  import delimited using $tmp/alphas_urban_`demo'_`pg'.csv, clear varnames(1)

  /* options: closed_drain wat_source_home light_source_elec */
  
  /* set some labels */
  local llight_source_elec "electric light"
  local lclosed_drain "closed drainage"
  local lwat_source_home "piped water"
  local llatrine_home "latrines"

  local lsclosed_drain "closed drains"
  local lswat_source_home "water sources (home)"
  local lslatrine_home "latrines"

  local lsc "SC"
  local lmuslim "Muslim"


  local lupper town

  /* define custom y axes */
  /* create an empty local for the cases (of private goods) where we don't specify any range for y */
  local yaxislab ""
  
  /* Fig 6/Muslim Rural and Urban common axes */
  if "`pg'" == "closed_drain" {
    local yaxislab "ylab(0(0.1)-0.3)"
    local nudge 0.3/20
  }
  if "`pg'" == "wat_source_home"  {
    local yaxislab "ylab(0.1(0.05)-0.3)"
    local nudge 0.4/20
  }
  if "`pg'" == "light_source_elec"  {
    local yaxislab "ylab(0.02(0.02)-0.08)"
    local nudge 0.1/20
  }

  /* set an row number */
  gen id = _n
  
  /* set colors for positive and negative effects, and final value */
  gen     group = "pos" if value > 0
  replace group = "zero" if value == 0
  replace group = "neg" if value < 0
  replace group = "total" if category == "Total"
  
  /* calculate running total (assuming order is correct) */
  gen cumsum = sum(value)
  
  /* set low and high values for each of the rbars */
  /* low is running sum from previous obs, starting at 0 */
  gen low = 0 if id == 1
  replace low = cumsum[_n-1] if id != 1
  
  /* high is the running sum */
  gen high = cumsum if category != "Total"
  
  /* store the low and high values to get a sense of the scale of the graph */
  gen l1 = min(low, high)
  gen l2 = max(low, high)

  /* set the final total to a thick bar around the total value */
  replace low  = value - `nudge' * 0.5 if category == "Total"
  replace high = value + `nudge' * 0.5 if category == "Total"

  /* create x values and assign value labels with category names */
  gen x = id
  labmask x, val(category)
  
  /* calculate values to add some arrows to the graph */
  gen arrow_x = x - .55
  replace arrow_x = . if group == "total"
  
  /* calculate values to add some lines to the graph */
  gen li_start = x - .75
  gen li_end   = x - .35
  replace li_end = . if group == "total"
  
  /* set label position; above the bar if it's a net increase, and below it if it's a net decrease */
  /* ylab dictates postion of the label and ylab2 dictates the postion of its value */
  gen ylab = .
  gen ylab2 =.

  /* set a higher differential for muslim graphs because they're on a smaller scale
  and default text settings leads to them getting squeezed together*/

  /* when the graph shows an increase in values */
  replace ylab = high + `nudge'*2 if high >= low 
  replace ylab2 = high + `nudge' if high >= low 

  /* when the graph shows a decrease in values */
  replace ylab = high - `nudge' if high < low
  replace ylab2 = high - `nudge'*2 if high < low

  disp_nice "`demo' `pg'" high low
  noi li category ylab ylab2 high low
  
  /* nudge total so it's above the bar */
  replace ylab = high + `nudge' * 0.75 if group == "total"
  replace category = category + ":"
  
  /* create a string value label to go under the label */
  gen value_string = string(value)
  replace value_string = "+" + value_string if value > 0
  
  /* alter the total category to be all on one line */
  replace category = category + " " + value_string if group == "total"
  replace value_string = "" if group == "total"

  /* make everything bold */
  replace category = "{bf:" + category + "}"
  replace value_string = "{bf:" + value_string +  "}"

  /* box settings */
  global colorbox `""0 0 0""'
  global textboxsize size(small)
  global textboxoptions  box $textboxsize width(39) tstyle(smbody) margin(t+1) justification(left) fcolor(white) lwidth(medium) lcolor($colorbox)
  global textboxtotaloptions  box $textboxsize width(24) tstyle(smbody) margin(t+1) justification(left) fcolor(white) lwidth(medium) lcolor($colorbox)

  /* edit low high for the one zero value when high == low */
  replace high = high + 0.005 if low == high

  /* No break up graph */
  twoway ///
      (rbar low high id if group == "pos", color("144 238 144")) ///
      (rbar low high  id if group == "zero", color("144 238 144")) ///
      (rbar low high id if group == "neg", color("136 8 8")) ///
      (rbar low high id if group == "total", lwidth(thick) lcolor(black) color(gs3)) ///
      (pcarrow low arrow_x high arrow_x, lwidth(thick) color(black) msize(2) mlwidth(medthick)) ///
      (pcspike high li_start high li_end, lwidth(medium) color(black)) ///
      (scatter ylab id, mlabsize(medsmall) mlab(category) mlabcolor(black) mlabpos(0) mc(none)) ///
      (scatter ylab2 id, mlabsize(medsmall) mlab(value_string) mlabcolor(black) mlabpos(0) mc(none)) ///
      , xlabel(none) legend(off) xtitle("") ///
      `yaxislab' ytitle("Share of households with `l`pg''" "Coefficient on `l`demo'' share", size(medlarge)) yline(0, lwidth(medthick) lcolor(black))

  graphout pe_urban_`demo'_`pg'_all, pdf
  
end
/** END program graph_pe_function ************************************/

/********/
/* MAIN */
/********/

/* don't loop over rural urban since we only have sanitation variables in urban */
/* GENERATE URBAN POLITICAL ECONOMY FUNCTION GRAPHS */
/* loop over public goods */
foreach pg in closed_drain wat_source_home light_source_elec   {

  /* loop over minority groups */
  foreach demo in  sc muslim {
    
    /* run the regression at each level of aggregation and store the coefficient */
    use $tmp/secc/segregation_blockdata_urban_200, clear
    prep_data
    gen_pcaps
    
    quireg `pg' `demo'_share [aw=block_pop] if slum == 0, absorb(pc11_state_id pc11_district_id pc11_subdistrict_id pc11_town_id)
    local b_fe_town = _b["`demo'_share"]
    quireg `pg' `demo'_share [aw=block_pop] if slum == 0, absorb(pc11_state_id pc11_district_id)
    local b_fe_dist = _b["`demo'_share"]
    quireg `pg' `demo'_share [aw=block_pop] if slum == 0, absorb(pc11_state_id)
    local b_fe_state = _b["`demo'_share"]
    quireg `pg' `demo'_share [aw=block_pop] if slum == 0
    local b_fe_none = _b["`demo'_share"]
    
    /* calculate the alphas from the betas */
    local a_town  : di %6.3f `b_fe_town'
    local a_dist  : di %6.3f `b_fe_dist' - `b_fe_town'
    local a_state : di %6.3f `b_fe_state' - `b_fe_dist'
    local a_nation: di %6.3f `b_fe_none' - `b_fe_state'
    local total: di %6.3f `a_town' + `a_dist' + `a_state' + `a_nation'
    
    /* store the alphas in a dataset */
    cap file close fh
    file open fh using $tmp/alphas_urban_`demo'_`pg'.csv, write replace
    file write fh "category,value"      _n
    file write fh "x-state,`a_nation'"      _n
    file write fh "x-district,`a_state'"    _n
    file write fh "x-town,`a_dist'"         _n
    file write fh "x-block,`a_town'" _n
    file write fh "Total,`total'"           _n
    file close fh
    cat $tmp/alphas_urban_`demo'_`pg'.csv
    
    /******************/
    /* make the graph */
    /******************/
    graph_pe_function, demo(`demo') pg(`pg')
    // billy write $out/pe_urban_`demo'_`pg'_all.pdf
    
  }
}

/**************************************************************/
/* generate mean values noisily, these go in the figure notes */
/**************************************************************/
use $tmp/secc/segregation_blockdata_urban_200, clear
prep_data
gen_pcaps

/* loop over private goods */
foreach pg in closed_drain wat_source_home light_source_elec {
  disp_nice `pg'
  sum `pg'
}
