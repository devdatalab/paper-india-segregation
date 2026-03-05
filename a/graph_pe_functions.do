/***********************************************************************/
/* AI SUMMARY                                                          */
/* INPUTS:                                                             */
/*   - $tmp/secc/segregation_blockdata_{urban,rural}_200.dta          */
/* OUTPUTS:                                                            */
/*   - $out/pe_*_{state,district,town,subdistrict,village,block,total,all}.pdf */
/* GOAL:                                                               */
/*   Estimate/plot PE functions across geographies and fixed effects.   */
/*                                                                     */
/* Estimate PE decompositions across geographies and FE structures.    */
/***********************************************************************/

/*************************************************************************************/
/* program prep_data: Perform basic data operations required before every analysis   */
/*************************************************************************************/
cap prog drop prep_data
prog def prep_data

  /* drop blocks outside a reasonable population range (approx 1/99th percentile) */
  keep if inrange(block_pop, 150, 1000)

  /* loop over public and private */
  foreach pubpriv in pub priv {
  
    capdrop *_emp_*_pcap  
    /* recalculate per capita public facility numbers just to be safe */
    qui foreach v in primary secondary hospital {
      
      /* calculate per capita employment in public facility */
      gen `v'_emp_`pubpriv'_pcap = `v'_emp_`pubpriv' / block_pop
      
    }
  
    /* winsorize level public facility variables based on per capita employment in non-missing places.
    We don't want a handful of overprovisioned neighborhoods (or data errors)
    to drive the results --- we care mainly about missing results anyway. */
    foreach v in primary secondary hospital {
      
      qui sum `v'_emp_`pubpriv'_pcap if `v'_emp_`pubpriv'_pcap != 0, d
    
      /* note we replace the level, not the per capita variable, since that is what get collapsed all the way down. */
      replace `v'_emp_`pubpriv' = `r(p99)' * block_pop if `v'_emp_`pubpriv'_pcap > `r(p99)' & !mi(`v'_emp_`pubpriv'_pcap)
    }    
  }
  
end
/** END program prep_data ************************************************************/


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

/*********************************************************************/
/* program graph_pe_function: Graph the political economy function   */
// 
// given a demographic group (demo), a public service (pg), rural/urban (loc),
// and public/private (pubpriv), this reads an existing coefficient file (named alphas_*),
// and generates all the "political economy function" graphs. Each call generates
// ~5 partial graphs (for the presentation), and then the "_all" graph for the paper.
// 
// The "fast" parameter tells it to skip the partial graphs and generate the "_all"
// graph only
// 
/*********************************************************************/
cap prog drop graph_pe_function
prog def graph_pe_function

  syntax, demo(string) pg(string) loc(string) pubpriv(string) fast

  import delimited using $tmp/alphas_`loc'_`demo'_`pg'_`pubpriv'.csv, clear varnames(1)

  /* set some labels */
  local lprimary "Primary schools"
  local lsecondary "Secondary schools"
  local lhospital "Hospitals"

  local lsprimary "primary schools"
  local lssecondary "secondary schools"
  local lshospital "hospitals"

  local lsc "SC"
  local lmuslim "Muslim"

    /* town/subdistrict locals */
  if "`loc'" == "rural" {
    local lupper subdistrict
  }

  if "`loc'" == "urban" {
    local lupper town
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

  sum l1 if category != "Total"
  local low = `r(min)'
  di "`low'"
  sum l2 if category != "Total"
  local high = `r(max)'
  di "`high'"

  // range of 60 --> nudge value of 2
  // range of 100 --> nudge value of 3
  local range = `high' - `low'
  local nudge = `range' / 20

  sum l1 
  local ylow = `r(min)'*1.5
  di "`ylow'"
  sum l2 
  local yhigh = `r(max)'*1.5
  di "`yhigh'"

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
  
  /* set ylab and ylab2 for putting labels on the rbars with category/value */
  /* initialise empty variables */
  gen ylab = .
  gen ylab2 = .
  
  /* when the graph shows an increase in values */
  replace ylab = high + `nudge'*2 if high >= low 
  replace ylab2 = high + `nudge' if high >= low 

  /* when the graph shows a decrease in values */
  replace ylab = high - `nudge' if high < low
  replace ylab2 = high - `nudge'*2 if high < low
  
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

  /* generate variable to place every text box */
  gen mid_point =  (`yhigh' + `ylow')/2

  if "`fast'" == "" {
    /**********************/
    /* Make x-state graph */
    /**********************/
    di "the y limits are `ylow' and `yhigh'"  
    /* create local for text box */  
    local y_text = round(mid_point[1], 0.01)
    local x_text = id[1] + 1.85
    local box_coords " `y_text' `x_text'"
  
    /* add text box input */
    local change_value = round(value[1]/10 , 0.01)
    if `change_value' > 0 local text_change = "`change_value' " + "more"
    if `change_value' < 0 local text_change = "`change_value' " + "fewer"
  
    global box `""Within the country, states with" "10% more `l`demo'''s have" "`text_change' `ls`pg'''" "per 100000 people""'
  
    /* make just the x-state graph */
    twoway ///
        (rbar low high id if group == "pos" &  id == 1, color("144 238 144")) ///
        (rbar low high id if group == "neg" & id == 1, color("136 8 8")) ///
        (rbar low high id if group == "total" & id == 1, lwidth(thick) lcolor(black) color(gs3)) ///
        (pcarrow low arrow_x high arrow_x if id == 1, lwidth(thick) color(black) msize(2) mlwidth(medthick)) ///
        (pcspike high li_start high li_end if id == 1, lwidth(medium) color(black)) ///
        (scatter ylab id if id == 1, mlabsize(medsmall) mlab(category) mlabcolor(black) mlabpos(0) mc(none) ) ///
        (scatter ylab2 id if id == 1, mlabsize(medsmall) mlab(value_string) mlabcolor(black) mlabpos(0) mc(none)) ///
        , xscale(range(0 7)) xlabel(none) ///
        ysc(r(`ylow' `yhigh')) ///
        legend(off) xtitle("") ///
        text(`box_coords'  $box, $textboxoptions) ///
        ytitle("`l`pg'' per 100,000 people" "Coefficient on `l`demo'' share", size(medlarge)) ///
        yline(0, lwidth(medthick) lcolor(black)) 

    graphout pe_`pubpriv'_`loc'_`demo'_`pg'_state, pdf
  
    /**********************************/
    /* Plot x-State + x-District bars */
    /**********************************/
    di "the y limits are `ylow' and `yhigh'"
    
      /* create local for text box */  
    local y_text = round(mid_point[2], 0.01)
    local x_text = id[2] + 1.85
    local box_coords " `y_text' `x_text'"
  
    /* add text box input */
    local change_value = round(value[2]/10 , 0.001)
    if `change_value' > 0 local text_change = "`change_value' " + "more"
    if `change_value' < 0 local text_change = "`change_value' " + "fewer"
  
    global box `""Within states, districts with" "10% more `l`demo'''s have" "`text_change' `ls`pg'''" "per 100000 people""'
    
    /* make the x-state and x-district graph */
    twoway ///
        (rbar low high id if group == "pos" &  inlist(id,1,2), color("144 238 144")) ///
        (rbar low high id if group == "neg" & inlist(id,1,2), color("136 8 8")) ///
        (rbar low high id if group == "total" & inlist(id,1,2), lwidth(thick) lcolor(black) color(gs3)) ///
        (pcarrow low arrow_x high arrow_x if inlist(id,1,2), lwidth(thick) color(black) msize(2) mlwidth(medthick)) ///
        (pcspike high li_start high li_end if inlist(id,1,2), lwidth(medium) color(black)) ///
        (scatter ylab id if inlist(id,1,2), mlabsize(medsmall) mlab(category) mlabcolor(black) mlabpos(0) mc(none) ) ///
        (scatter ylab2 id if inlist(id,1,2), mlabsize(medsmall) mlab(value_string) mlabcolor(black) mlabpos(0) mc(none)) ///
        , xscale(range(0 7)) xlabel(none) ysc(r(`ylow' `yhigh')) ///
        legend(off) xtitle("") ///
        text(`box_coords'  $box, $textboxoptions) ///
        ytitle("`l`pg'' per 100,000 people" "Coefficient on `l`demo'' share", size(medlarge)) ///
        yline(0, lwidth(medthick) lcolor(black)) 
    
    
    graphout pe_`pubpriv'_`loc'_`demo'_`pg'_district, pdf
  
    if "`loc'" == "urban" {   
  
      /*******************************************************/
      /* Plot x-state x-district and x-town/subdistrict bars */
      /*******************************************************/
      /* create local for text box */  
      local y_text = round(mid_point[3], 0.01)
      local x_text = id[3] + 1.85
      local box_coords " `y_text' `x_text'"
  
      /* add text box input */
      local change_value = round(value[3]/10 , 0.001)
      if `change_value' > 0 local text_change = "`change_value' " + "more"
      if `change_value' < 0 local text_change = "`change_value' " + "fewer"
  
      global box `""Within districts, `lupper's with" "10% more `l`demo'''s have" "`text_change' `ls`pg'''" "per 100000 people""'
      
      /* make just the graph up to subdistricts */
      twoway ///
          (rbar low high id if group == "pos" &  inlist(id,1,2,3), color("144 238 144")) ///
          (rbar low high id if group == "neg" & inlist(id,1,2,3), color("136 8 8")) ///
          (rbar low high id if group == "total" & inlist(id,1,2,3), lwidth(thick) lcolor(black) color(gs3)) ///
          (pcarrow low arrow_x high arrow_x if inlist(id,1,2,3), lwidth(thick) color(black) msize(2) mlwidth(medthick)) ///
          (pcspike high li_start high li_end if inlist(id,1,2,3), lwidth(medium) color(black)) ///
          (scatter ylab id if inlist(id,1,2,3), mlabsize(medsmall) mlab(category) mlabcolor(black) mlabpos(0) mc(none) ) ///
          (scatter ylab2 id if inlist(id,1,2,3), mlabsize(medsmall) mlab(value_string) mlabcolor(black) mlabpos(0) mc(none)) ///
          , xscale(range(0 7)) xlabel(none) ysc(r(`ylow' `yhigh'))  ///
          legend(off) xtitle("") ///
          text(`box_coords'  $box, $textboxoptions) ///
          ytitle("`l`pg'' per 100,000 people" "Coefficient on `l`demo'' share", size(medlarge)) ///
          yline(0, lwidth(medthick) lcolor(black)) 
      
      
      graphout pe_`pubpriv'_`loc'_`demo'_`pg'_town, pdf
  
  
      /*****************************************************/
      /* Plot x-state, x-district, x-town and x-block bars */
      /*****************************************************/
      di "the y limits are `ylow' and `yhigh'"  
      
      /* create local for text box */  
      local y_text = round(mid_point[4], 0.01)
      local x_text = id[4] + 1.85
      local box_coords " `y_text' `x_text'"
  
      /* add text box input */
      local change_value = round(value[4]/10 , 0.001)
      if `change_value' > 0 local text_change = "`change_value' " + "more"
      if `change_value' < 0 local text_change = "`change_value' " + "fewer"
  
      global box `""Within `lupper's, blocks with" "10% more `l`demo'''s have" "`text_change' `ls`pg'''" "per 100000 people""'
      
      /* make just the graph up to towns */
      twoway ///
          (rbar low high id if group == "pos" &  inlist(id,1,2,3,4), color("144 238 144")) ///
          (rbar low high id if group == "neg" & inlist(id,1,2,3,4), color("136 8 8")) ///
          (rbar low high id if group == "total" & inlist(id,1,2,3,4), lwidth(thick) lcolor(black) color(gs3)) ///
          (pcarrow low arrow_x high arrow_x if inlist(id,1,2,3,4), lwidth(thick) color(black) msize(2) mlwidth(medthick)) ///
          (pcspike high li_start high li_end if inlist(id,1,2,3,4), lwidth(medium) color(black)) ///
          (scatter ylab id if inlist(id,1,2,3,4), mlabsize(medsmall) mlab(category) mlabcolor(black) mlabpos(0) mc(none) ) ///
          (scatter ylab2 id if inlist(id,1,2,3,4), mlabsize(medsmall) mlab(value_string) mlabcolor(black) mlabpos(0) mc(none)) ///
          , xscale(range(0 7)) xlabel(none) ysc(r(`ylow' `yhigh')) ///
          legend(off) xtitle("") ///
          text(`box_coords'  $box, $textboxoptions) ///
          ytitle("`l`pg'' per 100,000 people" "Coefficient on `l`demo'' share", size(medlarge)) ///
          yline(0, lwidth(medthick) lcolor(black)) 
      
      
      graphout pe_`pubpriv'_`loc'_`demo'_`pg'_block, pdf
  
      
      /*****************/
      /* Plot all bars */
      /*****************/
      di "the y limits are `ylow' and `yhigh'"
      /* create local for text box */  
      local y_text = round(mid_point[5], 0.01)
      local x_text = id[5] + 1.85
      local box_coords " `y_text' `x_text'"
  
      /* add text box input */
      local change_value = round(value[5]/10 , 0.001)
      if `change_value' > 0 local text_change = "`change_value' " + "more"
      if `change_value' < 0 local text_change = "`change_value' " + "fewer"
  
      global box `""The net effect is" "that blocks with" "10% more `l`demo'''s" "have `text_change'" "`ls`pg'''" "per 100000 people""'
      
      /* make just graph with all bars including total */
      twoway ///
          (rbar low high id if group == "pos", color("144 238 144")) ///
          (rbar low high id if group == "neg" , color("136 8 8")) ///
          (rbar low high id if group == "total" , lwidth(thick) lcolor(black) color(gs3)) ///
          (pcarrow low arrow_x high arrow_x , lwidth(thick) color(black) msize(2) mlwidth(medthick)) ///
          (pcspike high li_start high li_end , lwidth(medium) color(black)) ///
          (scatter ylab id , mlabsize(medsmall) mlab(category) mlabcolor(black) mlabpos(0) mc(none) ) ///
          (scatter ylab2 id , mlabsize(medsmall) mlab(value_string) mlabcolor(black) mlabpos(0) mc(none)) ///
          , xscale(range(0 7.2)) xlabel(none) ysc(r(`ylow' `yhigh'))  ///
          legend(off) xtitle("") ///
          text(`box_coords'  $box, $textboxtotaloptions) ///
          ytitle("`l`pg'' per 100,000 people" "Coefficient on `l`demo'' share", size(medlarge)) ///
          yline(0, lwidth(medthick) lcolor(black)) 
      
      
      graphout pe_`pubpriv'_`loc'_`demo'_`pg'_total, pdf
    } 
  
    if "`loc'" == "rural" {   
  
      /**************************************************/
      /* Plot x-state x-district and x-subdistrict bars */
      /**************************************************/
      /* create local for text box */  
      local y_text = round(mid_point[3], 0.01)
      local x_text = id[3] + 1.85
      local box_coords " `y_text' `x_text'"
  
      /* add text box input */
      local change_value = round(value[3]/10 , 0.001)
      if `change_value' > 0 local text_change = "`change_value' " + "more"
      if `change_value' < 0 local text_change = "`change_value' " + "fewer"
  
      global box `""Within districts, `lupper's with" "10% more `l`demo'''s have" "`text_change' `ls`pg'''" "per 100000 people""'
      
      /* make just the x-state graph */
      twoway ///
          (rbar low high id if group == "pos" &  inlist(id,1,2,3), color("144 238 144")) ///
          (rbar low high id if group == "neg" & inlist(id,1,2,3), color("136 8 8")) ///
          (rbar low high id if group == "total" & inlist(id,1,2,3), lwidth(thick) lcolor(black) color(gs3)) ///
          (pcarrow low arrow_x high arrow_x if inlist(id,1,2,3), lwidth(thick) color(black) msize(2) mlwidth(medthick)) ///
          (pcspike high li_start high li_end if inlist(id,1,2,3), lwidth(medium) color(black)) ///
          (scatter ylab id if inlist(id,1,2,3), mlabsize(medsmall) mlab(category) mlabcolor(black) mlabpos(0) mc(none) ) ///
          (scatter ylab2 id if inlist(id,1,2,3), mlabsize(medsmall) mlab(value_string) mlabcolor(black) mlabpos(0) mc(none)) ///
          , xscale(range(0 7)) xlabel(none) ysc(r(`ylow' `yhigh'))  ///
          legend(off) xtitle("") ///
          text(`box_coords'  $box, $textboxoptions) ///
          ytitle("`l`pg'' per 100,000 people" "Coefficient on `l`demo'' share", size(medlarge)) ///
          yline(0, lwidth(medthick) lcolor(black)) 
      
      /* save graph */
      graphout pe_`pubpriv'_`loc'_`demo'_`pg'_subdistrict, pdf
  
      /**************************************************************/
      /* Plot x-state, x-district, x-subdistrict and x-village bars */
      /**************************************************************/
      /* create local for text box */  
      local y_text = round(mid_point[4], 0.01)
      local x_text = id[4] + 1.85
      local box_coords " `y_text' `x_text'"
  
      /* add text box input */
      local change_value = round(value[4]/10 , 0.001)
      if `change_value' > 0 local text_change = "`change_value' " + "more"
      if `change_value' < 0 local text_change = "`change_value' " + "fewer"
  
      global box `""Within `lupper's, villages with" "10% more `l`demo'''s have" "`text_change' `ls`pg'''" "per 100000 people""'
      
      /* make just the x-state graph */
      twoway ///
          (rbar low high id if group == "pos" &  inlist(id,1,2,3,4), color("144 238 144")) ///
          (rbar low high id if group == "neg" & inlist(id,1,2,3,4), color("136 8 8")) ///
          (rbar low high id if group == "total" & inlist(id,1,2,3,4), lwidth(thick) lcolor(black) color(gs3)) ///
          (pcarrow low arrow_x high arrow_x if inlist(id,1,2,3,4), lwidth(thick) color(black) msize(2) mlwidth(medthick)) ///
          (pcspike high li_start high li_end if inlist(id,1,2,3,4), lwidth(medium) color(black)) ///
          (scatter ylab id if inlist(id,1,2,3,4), mlabsize(medsmall) mlab(category) mlabcolor(black) mlabpos(0) mc(none) ) ///
          (scatter ylab2 id if inlist(id,1,2,3,4), mlabsize(medsmall) mlab(value_string) mlabcolor(black) mlabpos(0) mc(none)) ///
          , xscale(range(0 7)) xlabel(none) ysc(r(`ylow' `yhigh')) ///
          legend(off) xtitle("") ///
          text(`box_coords'  $box, $textboxoptions) ///
          ytitle("`l`pg'' per 100,000 people" "Coefficient on `l`demo'' share", size(medlarge)) ///
          yline(0, lwidth(medthick) lcolor(black)) 
      
      /* save graph */
      graphout pe_`pubpriv'_`loc'_`demo'_`pg'_village, pdf
  
      /********************************************************************/
      /* Plot x-state, x-district, x-subdistrict x-village and block bars */
      /********************************************************************/
      /* create local for text box */  
      local y_text = round(mid_point[5], 0.01)
      local x_text = id[5] + 2
      local box_coords " `y_text' `x_text'"
  
      /* add text box input */
      local change_value = round(value[5]/10 , 0.001)
      if `change_value' > 0 local text_change = "`change_value' " + "more"
      if `change_value' < 0 local text_change = "`change_value' " + "fewer"
  
      global box `""Within villages, blocks with" "10% more `l`demo'''s have" "`text_change' `ls`pg'''" "per 100000 people""'
      
      /* make just the x-state graph */
      twoway ///
          (rbar low high id if group == "pos" &  inlist(id,1,2,3,4,5), color("144 238 144")) ///
          (rbar low high id if group == "neg" &  inlist(id,1,2,3,4, 5) , color("136 8 8")) ///
          (rbar low high id if group == "total" &  inlist(id,1,2,3,4,5) , lwidth(thick) lcolor(black) color(gs3)) ///
          (pcarrow low arrow_x high arrow_x if  inlist(id,1,2,3,4,5), lwidth(thick) color(black) msize(2) mlwidth(medthick)) ///
          (pcspike high li_start high li_end if  inlist(id,1,2,3,4,5) , lwidth(medium) color(black)) ///
          (scatter ylab id if  inlist(id,1,2,3,4,5) , mlabsize(medsmall) mlab(category) mlabcolor(black) mlabpos(0) mc(none) ) ///
          (scatter ylab2 id if  inlist(id,1,2,3,4,5), mlabsize(medsmall) mlab(value_string) mlabcolor(black) mlabpos(0) mc(none)) ///
          , xscale(range(0 8.5)) xlabel(none) ysc(r(`ylow' `yhigh'))  ///
          legend(off) xtitle("") ///
          text(`box_coords'  $box, $textboxoptions) ///
          ytitle("`l`pg'' per 100,000 people" "Coefficient on `l`demo'' share", size(medlarge)) ///
          yline(0, lwidth(medthick) lcolor(black)) 
      
      graphout pe_`pubpriv'_`loc'_`demo'_`pg'_block, pdf
  
      /*****************/
      /* Plot all bars */
      /*****************/
      /* create local for text box */  
      local y_text = round(mid_point[6], 0.01)
      local x_text = id[6] + 1.7
      local box_coords " `y_text' `x_text'"
  
      /* add text box input */
      local change_value = round(value[6]/10 , 0.001)
      if `change_value' > 0 local text_change = "`change_value' " + "more"
      if `change_value' < 0 local text_change = "`change_value' " + "fewer"
  
      global box `""The net effect is" "that blocks with" "10% more `l`demo'''s" "have `text_change'" "`ls`pg'''" "per 100000 people""'
      
      /* make just the x-state graph */
      twoway ///
          (rbar low high id if group == "pos", color("144 238 144")) ///
          (rbar low high id if group == "neg" , color("136 8 8")) ///
          (rbar low high id if group == "total" , lwidth(thick) lcolor(black) color(gs3)) ///
          (pcarrow low arrow_x high arrow_x , lwidth(thick) color(black) msize(2) mlwidth(medthick)) ///
          (pcspike high li_start high li_end , lwidth(medium) color(black)) ///
          (scatter ylab id , mlabsize(medsmall) mlab(category) mlabcolor(black) mlabpos(0) mc(none) ) ///
          (scatter ylab2 id , mlabsize(medsmall) mlab(value_string) mlabcolor(black) mlabpos(0) mc(none)) ///
          , xscale(range(0 8.5)) xlabel(none) ysc(r(`ylow' `yhigh'))  ///
          legend(off) xtitle("") ///
          text(`box_coords'  $box, $textboxtotaloptions) ///
          ytitle("`l`pg'' per 100,000 people" "Coefficient on `l`demo'' share", size(medlarge)) ///
          yline(0, lwidth(medthick) lcolor(black)) 
      
      
      graphout pe_`pubpriv'_`loc'_`demo'_`pg'_total, pdf
    } 
  }

  /* take care of the exceptional cases where we have a zero coefficient */
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
      ytitle("`l`pg'' per 100,000 people" "Coefficient on `l`demo'' share", size(medlarge)) yline(0, lwidth(medthick) lcolor(black))


  graphout pe_`pubpriv'_`loc'_`demo'_`pg'_all, pdf
  
end
/** END program graph_pe_function ************************************/

/********/
/* MAIN */
/********/

/* don't loop over rural urban since the location lists are different */

/* GENERATE URBAN POLITICAL ECONOMY FUNCTION GRAPHS */
/* loop over public facilities */
qui foreach pg in primary secondary hospital  {

  /* loop over minority groups */
  foreach demo in sc muslim {

    /* loop over loc */
    foreach pubpriv in  private public {

      /* locals to deal with different public/private variables  */
      if "`pubpriv'" == "private" local pubpriv priv
      if "`pubpriv'" == "public" local pubpriv pub
      
      /* run the regression at each level of aggregation and store the coefficient */
      use $tmp/secc/segregation_blockdata_urban_200, clear
      prep_data
      gen_pcaps

      /***************************************************************************/
      /* Run Regressions with different fixed effects and save the differentials */
      /***************************************************************************/
      quireg `pg'_dum_`pubpriv'_pcap `demo'_share [aw=block_pop], absorb(pc11_state_id pc11_district_id pc11_subdistrict_id pc11_town_id)
      local b_fe_town = _b["`demo'_share"]
      quireg `pg'_dum_`pubpriv'_pcap `demo'_share [aw=block_pop], absorb(pc11_state_id pc11_district_id)
      local b_fe_dist = _b["`demo'_share"]
      quireg `pg'_dum_`pubpriv'_pcap `demo'_share [aw=block_pop], absorb(pc11_state_id)
      local b_fe_state = _b["`demo'_share"]
      quireg `pg'_dum_`pubpriv'_pcap `demo'_share [aw=block_pop]
      local b_fe_none = _b["`demo'_share"]
      
      /* calculate the alphas from the betas */
      local a_town  : di %5.1f `b_fe_town'
      local a_dist  : di %5.1f `b_fe_dist' - `b_fe_town'
      local a_state : di %5.1f `b_fe_state' - `b_fe_dist'
      local a_nation: di %5.1f `b_fe_none' - `b_fe_state'
      local total: di %5.1f `a_town' + `a_dist' + `a_state' + `a_nation'
      
      /* store the urban alphas in a dataset */
      cap file close fh
      file open fh using $tmp/alphas_urban_`demo'_`pg'_`pubpriv'.csv, write replace
      file write fh "category,value"      _n
      file write fh "x-state,`a_nation'"      _n
      file write fh "x-district,`a_state'"    _n
      file write fh "x-town,`a_dist'"         _n
      file write fh "x-block,`a_town'" _n
      file write fh "Total,`total'"           _n
      file close fh
      cat $tmp/alphas_urban_`demo'_`pg'_`pubpriv'.csv
      
      /******************/
      /* make the graph */
      /******************/
      graph_pe_function, demo(`demo') pg(`pg') loc(urban) pubpriv(`pubpriv') fast
      // billy write $out/pe_priv_urban_`demo'_`pg'_all.pdf
      // billy write $out/pe_own1_urban_`demo'_`pg'_all.pdf      
      
    }
  }
}

/**************************************************************/
/* generate mean values noisily, these go in the figure notes */
/**************************************************************/
use $tmp/secc/segregation_blockdata_urban_200, clear
prep_data
gen_pcaps

/* loop over private goods */
foreach pg in primary_dum_priv_pcap secondary_dum_priv_pcap hospital_dum_priv_pcap primary_dum_pub_pcap secondary_dum_pub_pcap hospital_dum_pub_pcap  {
  disp_nice `pg'
  sum `pg'
}

/* REPEAT ALL STEPS FOR RURAL AREAS, ONLY CHANGING RURAL LOCATION PROGRESSION */
/* loop over public goods */
qui foreach pg in primary secondary hospital {

  /* loop over minority groups */
  foreach demo in sc muslim {

    /* loop over pubpriv */
    foreach pubpriv in private public {

      /* locals to deal with different public/private variables  */
      if "`pubpriv'" == "private" local pubpriv priv
      if "`pubpriv'" == "public" local pubpriv pub

      /* run the regression at each level of aggregation and store the coefficient */
      use $tmp/secc/segregation_blockdata_rural_200, clear
      prep_data
      gen_pcaps
      
      quireg `pg'_dum_`pubpriv'_pcap `demo'_share [aw=block_pop], absorb(pc11_state_id pc11_district_id pc11_subdistrict_id pc11_village_id)
      local b_fe_village = _b["`demo'_share"]
      quireg `pg'_dum_`pubpriv'_pcap `demo'_share [aw=block_pop], absorb(pc11_state_id pc11_district_id pc11_subdistrict_id)
      local b_fe_subd = _b["`demo'_share"]
      quireg `pg'_dum_`pubpriv'_pcap `demo'_share [aw=block_pop], absorb(pc11_state_id pc11_district_id)
      local b_fe_dist = _b["`demo'_share"]
      quireg `pg'_dum_`pubpriv'_pcap `demo'_share [aw=block_pop], absorb(pc11_state_id)
      local b_fe_state = _b["`demo'_share"]
      quireg `pg'_dum_`pubpriv'_pcap `demo'_share [aw=block_pop]
      local b_fe_none = _b["`demo'_share"]
      
      /* calculate the alphas from the betas */
      local a_village  : di %5.1f `b_fe_village'
      local a_subd  : di %5.1f `b_fe_subd' - `b_fe_village'
      local a_dist  : di %5.1f `b_fe_dist' - `b_fe_subd'
      local a_state : di %5.1f `b_fe_state' - `b_fe_dist'
      local a_nation: di %5.1f `b_fe_none' - `b_fe_state'
      local total: di %5.1f `a_village' + `a_subd' + `a_dist' + `a_state' + `a_nation'
      
      /* store the rural alphas in a dataset */
      cap file close fh
      file open fh using $tmp/alphas_rural_`demo'_`pg'_`pubpriv'.csv, write replace
      file write fh "category,value"      _n
      file write fh "x-state,`a_nation'"      _n
      file write fh "x-district,`a_state'"    _n
      file write fh "x-subdist,`a_dist'"  _n
      file write fh "x-village,`a_subd'"         _n
      file write fh "x-block,`a_village'" _n
      file write fh "Total,`total'"           _n
      file close fh
      cat $tmp/alphas_rural_`demo'_`pg'_`pubpriv'.csv
      
      /******************/
      /* make the graph */
      /******************/
      graph_pe_function, demo(`demo') pg(`pg') loc(rural) pubpriv(`pubpriv') fast
      // billy write $out/pe_priv_rural_`demo'_`pg'_all.pdf
      // billy write $out/pe_own1_rural_`demo'_`pg'_all.pdf      

    }
  }
}


/**************************************************************/
/* generate mean values noisily, these go in the figure notes */
/**************************************************************/
use $tmp/secc/segregation_blockdata_rural_200, clear
prep_data
gen_pcaps

/* loop over private goods */
foreach pg in primary_dum_priv_pcap secondary_dum_priv_pcap hospital_dum_priv_pcap primary_dum_pub_pcap secondary_dum_pub_pcap hospital_dum_pub_pcap  {
  disp_nice `pg'
  sum `pg'
}
