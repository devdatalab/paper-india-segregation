# This Readme has information about the makefile and figures and tables 

## Questions for analysis files that we don't use in the current version of the paper

### What  is upper?
The unit for town or subdistrict in urban or rural data respectively. This used to be called upper as a variable now it's saved as town or subdistrict variable in the data. However we still use upper as a local in programs that loop over rural and urban sector data which takes the value of town or subdistrict

### What happened to all the consumption graphs?
We don't have consumption binscatters, coefplots, and tables anymore. Find them in `$sc/a/old`
Consumption do files in `$sc/a/old` are:
1. block_cons_share_by_binscatter.do
2. block_cons_share_coefplot.do
3. block_cons_share_comparision_tables.do
4. city_cons_seg_binscatter.do

Consumption could be a result of so many things in and of itself and affect so many of the controls that we only use it as a control now. Not as an explanatory variable. 

### What happened to the graph showing younger cities are less segregated?
Not in the current draft of paper or results. Find older results in `~/old/city_dissim_age.do` 

### Where are the public and private good provision coefplots?
The neighborhood level story we're going with is the provision of public goods at the neighborhood level through a town/village political economy function. We just keep the binscatters for the public good provision from this pg good provision in `fig_5_block_pg_share_binscatter.do`. Coefplots for public and private good provision are in `~/old`. Files include:
1. block_pg_share_coefplot.do
2. block_pg_tables_different_collapses.do
3. block_private_public_share_coefplot_table.do
4. block_private_share_coefplot.do
5. city_pg_seg_coefplot.do

### What happened to the neighborhood level education regressions?
We decided we'll keep only the individual level regressions from `fig_7_block_individual_ed_coefplot.do`
The older nbd level regression in `block_ed_coefplot.do` is moved to `~/a/old`

### What are the census/ec kerela files in `~/a/old`
We tried to see if kerela which had more devolution of powers to panchayat's after the 71st amendment, had different public good allocations. Not so. These files are:
1. census_ec_pg_kerala_coefplot.do
2. census_pc_pg_kerala_coefplot.do

### What happened to population census based results
All in `~/old`
1. census_pc_pg_coefplot.do

### Other analysis moved to old:
1. city_seg_other_density.do: Helped us explore if other segregation measures showed muslim segregation > sc segregation in certain cases. This wasn't the case. 
2. block_group_share_histogram_density.do: Showed us the distribution (unweighted) of mg group population in different neighborhoods. 
3. tables_corr_seg.do: Tabulated correlation between different segregation measures.
4. shrid_name_match.do: Matches shrids to their names
5. tables_different_collapses.do
6. tables_ed_collapses.do
7. Segregation Maps.ipynb : An older interactive version of the seg_maps.py file

### Removing outlier blocks:
We remove blocks with `block_pop` < 150 | `block_pop` >1000, And if `bad_sc_share` > 50%`hhpop` where hhpop is the population of a block whose sc/muslim members are classified. `block_pop` on the other hand is all the people in the block we have any data from the SECC

### 

