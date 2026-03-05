/* prep input dataset */
import delimited using $tmp/master.csv, clear varnames(1)
save $tmp/master, replace

import delimited using $tmp/using.csv, clear varnames(1)
save $tmp/using_data, replace



/* do the merge */
use $tmp/master, clear

masala_merge state using $tmp/using_data, s1(name) idmaster(idmaster) idusing(idusing) nopreserve
