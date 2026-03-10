/***********************************************************************/
/* set_paths.do                                                        */
/*                                                                     */
/* Expected contract:                                                  */
/* 1) makefile sets: $scode and $base                                  */
/* 2) this file sets $sdata to raw root ($base/raw)                    */
/* 3) this file defines all derived globals from those two roots       */
/***********************************************************************/

/* data root */
global sdata "$base/raw"

/* code root aliases */
global sc "$scode"
global tools "$scode/tools"
global tmp "$base/tmp"
global out "$base/out"
global tex "$scode/tex"
global exhibits "$tex/exhibits"
global ado "$scode/ado"

/* data root aliases */
global raw "$sdata"
global seg "$sdata"
global shrug "$sdata/shrug"
global mobility "$sdata/mobility"
global pc11 "$sdata/pc11"
global pc01 "$sdata/pc01"

/* runtime folders */
cap mkdir "$tmp"
cap mkdir "$out"
