
***************************************************************************************************
//Program: hlm-setup-rebuild_AND_reweight_GENERAL.do  											  *
//Task:    MASTER do-file, generalized for ANY year 2004-2013. Performs BOTH steps:               *
//                                                                                                *
//         PART A) PROVINCE IDENTIFICATION (81 provinces, pure plaka order):                      *
//           - Sequential ascending sweep by plaka (with wraparound), with no manual swaps.       *
//           - The 6 plaka-contiguous pairs are separated via a POPULATION-PROPORTIONAL SPLIT     *
//             within each merged block, using the OFFICIAL POPULATION OF THE CORRESPONDING YEAR  *
//             (from the province_2000_2013_FINAL.dta table).                                     *
//                                                                                                *
//         PART B) RE-WEIGHTING (province x urban/rural):                                         *
//           - The REAL NUTS2 x urban/rural totals are computed DIRECTLY from the active dataset  *
//             (no external table needed for this -- "rural" and "subregion" are already in the   *
//             microdata).                                                                        *
//           - The TARGET population by province x urban/rural comes from the                     *
//             province_2000_2013_FINAL.dta table, filtered by the "year" of the active dataset.  *
//           - Factor = target_population / observed_weight, by cell. Falls back to province-level*
//             re-weighting if any cell (urban or rural) has 0 observations that year.            *
//                                                                                                *
//         REQUIREMENTS:                                                                          *
//           - The active dataset must have: subregion, weight, rural, year (year must be CONSTANT*
//             within the dataset, a single year per run).                                        *
//           - The file "province_2000_2013_FINAL.dta" must be in the working directory,          *
//             or adjust the path further below.                                                  *
//Project: Harmonized Labour Force Microdata.                                                           *
//Author:  Luis Pinedo Caro.         		         						   			          *
//Date created:     17/08/2026.																      *
***************************************************************************************************

global HLM_DIR "."

capture confirm variable subregion
if _rc {
    display as error "The active dataset does not have a 'subregion' variable. Aborting."
    exit 111
}
capture confirm variable rural
if _rc {
    display as error "The active dataset does not have a 'rural' (urban/rural) variable. Aborting."
    exit 111
}
capture confirm variable year
if _rc {
    display as error "The active dataset does not have a 'year' variable. Aborting."
    exit 111
}
capture confirm variable weight
if _rc {
    display as error "The active dataset does not have a 'weight' variable. Aborting."
    exit 111
}

*--- Safety check: drop variables this do-file will (re)create, if they already existed ---
foreach v in block nuts2 plaka province reweighted_weight reweighting_factor {
    capture confirm variable `v'
    if _rc == 0 {
        display as error "WARNING: variable '`v'' already existed in the dataset -- it will be " ///
            "dropped and recreated from scratch by this do-file."
        drop `v'
    }
}

*--- Check the actual labels of 'rural', to catch matching problems early ---
display as text "Observed values of 'rural' in this dataset:"
capture confirm string variable rural
if _rc == 0 {
    quietly levelsof rural, local(rural_levels)
    display as text "`rural_levels'"
}
else {
    quietly levelsof rural, local(rural_levels)
    label list `: value label rural'
}
display as text "(the code below compares against the exact string 'Rural' -- if it does not " ///
    "appear as such above, the code must be adjusted before proceeding)"
quietly levelsof year, local(years_present)
local n_years : word count `years_present'
if `n_years' != 1 {
    display as error "The active dataset has more than one value of 'year' (" `n_years' "). " ///
        "This do-file expects a single year per run. Aborting."
    exit 198
}
local current_year = `years_present'
display as text "Processing year: `current_year'"

*=====================================================================================================
* PART A: PROVINCE IDENTIFICATION
*=====================================================================================================

capture confirm string variable subregion
if _rc == 0 {
    quietly gen str60 __subregion_str = subregion
}
else {
    quietly decode subregion, generate(__subregion_str)
}
quietly gen byte __change = (__subregion_str != __subregion_str[_n-1]) if _n > 1
quietly replace __change = 1 if _n == 1
quietly gen long block = sum(__change)
drop __change
quietly gen str6 nuts2 = subinstr(word(__subregion_str,1), "-", "", .)
drop __subregion_str

tempfile __main __blocks_id
save `__main'

quietly contract block nuts2, freq(block_size)
sort block
quietly gen long plaka = .

mata:
    nuts2_canon = J(81,1,"")
    nuts2_canon[1]="TR62";  nuts2_canon[2]="TRC1";  nuts2_canon[3]="TR33";  nuts2_canon[4]="TRA2"
    nuts2_canon[5]="TR83";  nuts2_canon[6]="TR51";  nuts2_canon[7]="TR61";  nuts2_canon[8]="TR90"
    nuts2_canon[9]="TR32";  nuts2_canon[10]="TR22"; nuts2_canon[11]="TR41"; nuts2_canon[12]="TRB1"
    nuts2_canon[13]="TRB2"; nuts2_canon[14]="TR42"; nuts2_canon[15]="TR61"; nuts2_canon[16]="TR41"
    nuts2_canon[17]="TR22"; nuts2_canon[18]="TR82"; nuts2_canon[19]="TR83"; nuts2_canon[20]="TR32"
    nuts2_canon[21]="TRC2"; nuts2_canon[22]="TR21"; nuts2_canon[23]="TRB1"; nuts2_canon[24]="TRA1"
    nuts2_canon[25]="TRA1"; nuts2_canon[26]="TR41"; nuts2_canon[27]="TRC1"; nuts2_canon[28]="TR90"
    nuts2_canon[29]="TR90"; nuts2_canon[30]="TRB2"; nuts2_canon[31]="TR63"; nuts2_canon[32]="TR61"
    nuts2_canon[33]="TR62"; nuts2_canon[34]="TR10"; nuts2_canon[35]="TR31"; nuts2_canon[36]="TRA2"
    nuts2_canon[37]="TR82"; nuts2_canon[38]="TR72"; nuts2_canon[39]="TR21"; nuts2_canon[40]="TR71"
    nuts2_canon[41]="TR42"; nuts2_canon[42]="TR52"; nuts2_canon[43]="TR33"; nuts2_canon[44]="TRB1"
    nuts2_canon[45]="TR33"; nuts2_canon[46]="TR63"; nuts2_canon[47]="TRC3"; nuts2_canon[48]="TR32"
    nuts2_canon[49]="TRB2"; nuts2_canon[50]="TR71"; nuts2_canon[51]="TR71"; nuts2_canon[52]="TR90"
    nuts2_canon[53]="TR90"; nuts2_canon[54]="TR42"; nuts2_canon[55]="TR83"; nuts2_canon[56]="TRC3"
    nuts2_canon[57]="TR82"; nuts2_canon[58]="TR72"; nuts2_canon[59]="TR21"; nuts2_canon[60]="TR83"
    nuts2_canon[61]="TR90"; nuts2_canon[62]="TRB1"; nuts2_canon[63]="TRC2"; nuts2_canon[64]="TR33"
    nuts2_canon[65]="TRB2"; nuts2_canon[66]="TR72"; nuts2_canon[67]="TR81"; nuts2_canon[68]="TR71"
    nuts2_canon[69]="TRA1"; nuts2_canon[70]="TR52"; nuts2_canon[71]="TR71"; nuts2_canon[72]="TRC3"
    nuts2_canon[73]="TRC3"; nuts2_canon[74]="TR81"; nuts2_canon[75]="TRA2"; nuts2_canon[76]="TRA2"
    nuts2_canon[77]="TR42"; nuts2_canon[78]="TR81"; nuts2_canon[79]="TRC1"; nuts2_canon[80]="TR63"
    nuts2_canon[81]="TR42"

    nv = st_sdata(., "nuts2")
    plaka_out = J(rows(nv),1,.)
    cursor = 0
    for (i=1; i<=rows(nv); i++) {
        target = strtrim(nv[i])
        found  = 0
        for (step=1; step<=81; step++) {
            idx = mod(cursor + step - 1, 81) + 1
            if (nuts2_canon[idx] == target) {
                found = idx
                break
            }
        }
        if (found > 0) {
            plaka_out[i] = found
            cursor = found
        }
    }
    st_store(., "plaka", plaka_out)
end

keep block plaka
save `__blocks_id'

use `__main', clear
quietly merge m:1 block using `__blocks_id', nogenerate
drop nuts2

*--- Official population for the current year, for the 12 provinces forming the 6 ambiguous pairs ---
* (taken from the same province_2000_2013_FINAL.dta table, filtered by year and plate)
preserve
    use "$HLM_DIR/data/province_2000_2013_FINAL.dta", clear
    keep if year == `current_year'
    keep plate total
    tempfile __year_pop
    save `__year_pop'
restore

* Pass the population of each of the 12 troublesome plakas into locals, reading from the year-specific table
foreach p in 24 25 28 29 50 51 52 53 72 73 75 76 {
    preserve
        use `__year_pop', clear
        quietly keep if plate == `p'
        quietly summarize total
        local pop_`p' = r(mean)
    restore
}

quietly gen double __w = weight
quietly bysort block: egen double block_weight = total(__w)
quietly bysort block: gen double __cumulative = sum(__w) if inlist(plaka,24,25,28,29,50,51,52,53,72,73,75,76)

quietly gen long province = plaka

foreach par in "24 25" "28 29" "50 51" "52 53" "72 73" "75 76" {
    tokenize `"`par'"'
    local p_small `1'
    local p_large `2'
    local pop_small  `pop_`p_small''
    local pop_large `pop_`p_large''
    local pop_total = `pop_small' + `pop_large'

    quietly replace province = `p_small'  if plaka==`p_small' & __cumulative <= block_weight*(`pop_small'/`pop_total')
    quietly replace province = `p_large' if plaka==`p_small' & __cumulative >  block_weight*(`pop_small'/`pop_total')
}

drop __w block_weight __cumulative plaka block

capture label drop province_lbl
label define province_lbl ///
    1  "Adana"          2  "Adıyaman"       3  "Afyonkarahisar" ///
    4  "Ağrı"            5  "Amasya"         6  "Ankara"         ///
    7  "Antalya"         8  "Artvin"         9  "Aydın"          ///
    10 "Balıkesir"       11 "Bilecik"        12 "Bingöl"         ///
    13 "Bitlis"          14 "Bolu"           15 "Burdur"         ///
    16 "Bursa"           17 "Çanakkale"      18 "Çankırı"        ///
    19 "Çorum"           20 "Denizli"        21 "Diyarbakır"     ///
    22 "Edirne"          23 "Elazığ"         24 "Erzincan"       ///
    25 "Erzurum"         26 "Eskişehir"      27 "Gaziantep"      ///
    28 "Giresun"         29 "Gümüşhane"      30 "Hakkari"        ///
    31 "Hatay"           32 "Isparta"        33 "Mersin"         ///
    34 "İstanbul"        35 "İzmir"          36 "Kars"           ///
    37 "Kastamonu"       38 "Kayseri"        39 "Kırklareli"     ///
    40 "Kırşehir"        41 "Kocaeli"        42 "Konya"          ///
    43 "Kütahya"         44 "Malatya"        45 "Manisa"         ///
    46 "Kahramanmaraş"   47 "Mardin"         48 "Muğla"          ///
    49 "Muş"             50 "Nevşehir"       51 "Niğde"          ///
    52 "Ordu"            53 "Rize"           54 "Sakarya"        ///
    55 "Samsun"          56 "Siirt"          57 "Sinop"          ///
    58 "Sivas"           59 "Tekirdağ"       60 "Tokat"          ///
    61 "Trabzon"         62 "Tunceli"        63 "Şanlıurfa"      ///
    64 "Uşak"            65 "Van"            66 "Yozgat"         ///
    67 "Zonguldak"       68 "Aksaray"        69 "Bayburt"        ///
    70 "Karaman"         71 "Kırıkkale"      72 "Batman"         ///
    73 "Şırnak"          74 "Bartın"         75 "Ardahan"        ///
    76 "Iğdır"           77 "Yalova"         78 "Karabük"        ///
    79 "Kilis"           80 "Osmaniye"       81 "Düzce"
label values province province_lbl
label variable province "Province (plaka), pure sequential order, no manual swaps"

display as text "===== PART A completed: province identification (year `current_year') ====="
tabulate province, missing

*=====================================================================================================
* PART B: RE-WEIGHTING (province x urban/rural)
*=====================================================================================================
* NOTE: the merge with the target population table is ALWAYS done using the numeric plaka code
* (variable "province", already numeric 1-81), NEVER by text name -- to avoid Turkish character
* encoding issues (İ, ı, ş, ğ, ü, ö, ç) between files.

*--- Normalize 'rural' to string, regardless of its original format (string vs numeric+labels) ---
capture confirm string variable rural
if _rc == 0 {
    quietly gen byte __is_rural = (rural=="Rural") if !missing(rural)
}
else {
    quietly decode rural, generate(__rural_str)
    quietly gen byte __is_rural = (__rural_str=="Rural") if !missing(__rural_str)
    drop __rural_str
}

preserve
    tempfile __with_target __complete_levels

    * Target table for the current year: total/urban/rural population by province, indexed by
    * "plate" (numeric)
    use "$HLM_DIR/data/province_2000_2013_FINAL.dta", clear
    keep if year == `current_year'
    drop province
    rename plate province
    rename urban urban_final
    rename rural rural_final
    keep province urban_final rural_final
    tempfile __year_target
    save `__year_target'

    restore
    preserve

    collapse (sum) observed_weight=weight, by(province __is_rural)
    quietly merge m:1 province using `__year_target', keep(master match) nogenerate
    quietly gen double cell_target = urban_final if __is_rural==0
    quietly replace cell_target = rural_final if __is_rural==1
    quietly gen double cell_factor = cell_target/observed_weight

    quietly bysort province: gen byte __n_cells = _N
    quietly gen byte __incomplete = (__n_cells < 2)

    count if __incomplete
    if r(N) > 0 {
        display as error "WARNING: " r(N) " provinces have an empty urban/rural cell this year -- " ///
            "province-level re-weighting is applied as a fallback in these cases:"
        list province if __incomplete
    }
    save `__complete_levels'

    * Province-level factor (fallback), using the TOTAL target from the original table
    use `__complete_levels', clear
    collapse (sum) observed_weight, by(province)
    rename observed_weight observed_weight_province
    quietly merge 1:1 province using `__year_target', keep(master match) nogenerate
    quietly gen double province_target = urban_final + rural_final
    quietly gen double province_factor = province_target/observed_weight_province
    keep province observed_weight_province province_target province_factor
    tempfile __province_factor
    save `__province_factor'

    use `__complete_levels', clear
    quietly merge m:1 province using `__province_factor', nogenerate
    quietly gen double reweighting_factor = cell_factor
    quietly replace reweighting_factor = province_factor if __incomplete

    keep province __is_rural reweighting_factor
    save `__with_target'
restore

quietly merge m:1 province __is_rural using `__with_target', nogenerate

quietly gen double reweighted_weight = weight * reweighting_factor
quietly replace reweighted_weight = weight if missing(reweighting_factor)

label variable reweighted_weight "Re-weighted weight (province x urban/rural, calibrated to the corresponding year)"
label variable reweighting_factor "Re-weighting factor applied = target population / observed weight"

drop __is_rural

display as text "===== PART B completed: province x urban/rural re-weighting (year `current_year') ====="
quietly summarize reweighted_weight
display as text "Total sum of reweighted_weight (before NUTS2 calibration): " r(sum)

*=====================================================================================================
* PART C: FINAL NUTS2-LEVEL CALIBRATION (optional, recommended)
*=====================================================================================================
* Forces the sum of re-weighted provinces WITHIN each subregion (NUTS2) to match EXACTLY the real
* observed total for that subregion (sum of the original "weight", not re-weighted -- this is the
* number the survey itself already calibrates correctly, according to its own NUTS2 x urban/rural
* design).
*
* If any member province of a NUTS2 is absent that year (e.g. Kilis in 2004), its OFFICIAL
* population (from the table) is subtracted from that subregion's target before comparing -- i.e.
* the remaining provinces of the NUTS2 (e.g. Gaziantep+Adıyaman) are calibrated against
* "subregion minus Kilis", not against the subregion's full total.

*--- 2) Map of province (plaka) -> NUTS2, and official population of each province (needed to
*        subtract absent ones from the NUTS2 target) ---
tempfile __main_c
save `__main_c'

clear
input long province str6 nuts2map
    1 "TR62"
    2 "TRC1"
    3 "TR33"
    4 "TRA2"
    5 "TR83"
    6 "TR51"
    7 "TR61"
    8 "TR90"
    9 "TR32"
    10 "TR22"
    11 "TR41"
    12 "TRB1"
    13 "TRB2"
    14 "TR42"
    15 "TR61"
    16 "TR41"
    17 "TR22"
    18 "TR82"
    19 "TR83"
    20 "TR32"
    21 "TRC2"
    22 "TR21"
    23 "TRB1"
    24 "TRA1"
    25 "TRA1"
    26 "TR41"
    27 "TRC1"
    28 "TR90"
    29 "TR90"
    30 "TRB2"
    31 "TR63"
    32 "TR61"
    33 "TR62"
    34 "TR10"
    35 "TR31"
    36 "TRA2"
    37 "TR82"
    38 "TR72"
    39 "TR21"
    40 "TR71"
    41 "TR42"
    42 "TR52"
    43 "TR33"
    44 "TRB1"
    45 "TR33"
    46 "TR63"
    47 "TRC3"
    48 "TR32"
    49 "TRB2"
    50 "TR71"
    51 "TR71"
    52 "TR90"
    53 "TR90"
    54 "TR42"
    55 "TR83"
    56 "TRC3"
    57 "TR82"
    58 "TR72"
    59 "TR21"
    60 "TR83"
    61 "TR90"
    62 "TRB1"
    63 "TRC2"
    64 "TR33"
    65 "TRB2"
    66 "TR72"
    67 "TR81"
    68 "TR71"
    69 "TRA1"
    70 "TR52"
    71 "TR71"
    72 "TRC3"
    73 "TRC3"
    74 "TR81"
    75 "TRA2"
    76 "TRA2"
    77 "TR42"
    78 "TR81"
    79 "TRC1"
    80 "TR63"
    81 "TR42"
end
tempfile __nuts2_map
save `__nuts2_map'

* Official population of each province this year
use "$HLM_DIR/data/province_2000_2013_FINAL.dta", clear
keep if year == `current_year'
drop province
rename plate province
keep province total
rename total official_pop
tempfile __official_pop_prov
save `__official_pop_prov'

*--- 3) Small, clean table: 1 row per province, with its observed weight (post Part B) and its
*        official population, flagging whether it is present (>0 obs) or absent (0, e.g. Kilis) ---
use `__main_c', clear
collapse (sum) observed_prov_weight=reweighted_weight, by(province)
quietly merge 1:1 province using `__nuts2_map', nogenerate
quietly merge 1:1 province using `__official_pop_prov', nogenerate
quietly gen double official_pop_present = official_pop if observed_prov_weight > 0
tempfile __clean_prov_table
save `__clean_prov_table'

*--- 4) Small table by NUTS2 (26 rows): real observed weight + adjusted target + factor ---
use `__main_c', clear
capture confirm string variable subregion
if _rc == 0 {
    quietly gen str60 __subregion_str2 = subregion
}
else {
    quietly decode subregion, generate(__subregion_str2)
}
quietly gen str6 nuts2map = subinstr(word(__subregion_str2,1), "-", "", .)
drop __subregion_str2
collapse (sum) real_nuts2_weight=weight, by(nuts2map)

quietly merge 1:m nuts2map using `__clean_prov_table', nogenerate
quietly bysort nuts2map: egen double adjusted_nuts2_target = total(official_pop_present)
collapse (first) real_nuts2_weight adjusted_nuts2_target, by(nuts2map)
quietly gen double nuts2_factor = real_nuts2_weight/adjusted_nuts2_target
keep nuts2map nuts2_factor
tempfile __nuts2_factor_final
save `__nuts2_factor_final'

*--- 5) Merge nuts2_factor back onto the main dataset and apply it ---
use `__main_c', clear
capture confirm string variable subregion
if _rc == 0 {
    quietly gen str60 __subregion_str3 = subregion
}
else {
    quietly decode subregion, generate(__subregion_str3)
}
quietly gen str6 nuts2map = subinstr(word(__subregion_str3,1), "-", "", .)
drop __subregion_str3

quietly merge m:1 nuts2map using `__nuts2_factor_final', nogenerate

quietly replace reweighted_weight = reweighted_weight * nuts2_factor
drop nuts2map nuts2_factor

label variable reweighted_weight "FINAL re-weighted weight (province x urban/rural, + calibrated to the real NUTS2 total)"

display as text "===== PART C completed: final NUTS2-level calibration (year `current_year') ====="
quietly summarize reweighted_weight
display as text "Total sum of reweighted_weight (final, after NUTS2 calibration): " r(sum)
quietly summarize weight
display as text "Total sum of weight (original): " r(sum)
