# recovering-nuts3-hlfs

This repository is the replication package for: Pinedo Caro, L. (2026). [*Recovering Province Identifiers from Turkish Household Labour Force Survey Microdata*](https://betam.bahcesehir.edu.tr/en/2026/09/recovering-province-identifiers-from-turkish-household-labour-force-survey-microdata/). BETAM Working Paper WP202603.

Stata routine to recover NUTS-3 province identifiers (81 provinces) from Turkish Household Labour Force Survey (HLFS) microdata for 2004–2013, and to re-weight the sample at the province × urban/rural level.

Part of the **Harmonized Labour Force Microdata (HLM)** project.

## Background

The public-use HLFS microdata for 2004–2013 identify only the NUTS-2 region (`subregion`), not the province. This routine reconstructs the province (plaka code) of each observation and produces survey weights calibrated to official provincial population totals.

## Method

The do-file runs three steps on a single survey year:

**Part A – Province identification.** Observations are split into blocks where `subregion` changes and assigned to provinces by a sequential ascending sweep in plaka order (with wraparound), with no manual swaps. Six pairs of provinces with contiguous plaka codes (24–25, 28–29, 50–51, 52–53, 72–73, 75–76) cannot be separated this way; they are split in proportion to each province's official population for the corresponding year.

**Part B – Re-weighting (province × urban/rural).** For each province × urban/rural cell, the re-weighting factor is the official target population divided by the observed sum of weights. If a province has no urban or no rural observations in a given year, the routine falls back to province-level re-weighting.

**Part C – NUTS-2 calibration (recommended).** Re-weighted provincial totals are scaled so they add up exactly to the survey's own NUTS-2 totals (sum of the original `weight`). If a province is absent in a given year (e.g. Kilis in 2004), its official population is subtracted from the NUTS-2 target before calibrating the remaining provinces.

## Repository structure

    recovering-nuts3-hlfs/
    ├── code/
    │   └── hlm-setup-rebuild_provinces.do   # main routine (Parts A, B, C)
    ├── data/
    │   └── province_2000_2013_FINAL.dta     # official population by province, 2000–2013
    ├── LICENSE
    └── README.md

## Requirements

- Stata (version [X] or later).
- An HLFS microdata file for **one single year** (2004–2013) loaded in memory, containing the variables:
  - `subregion` – NUTS-2 region
  - `rural` – urban/rural indicator (values/labels must be `"Rural"` for rural areas)
  - `weight` – original survey weight
  - `year` – survey year (constant within the dataset)

The HLFS microdata are **not** included in this repository. They must be obtained from TurkStat.

## Usage

```stata
* 1. Set the working directory to the root of this repository
cd "C:/path/to/recovering-nuts3-hlfs"

* 2. Load one year of HLFS microdata
use "path/to/your/hlfs_2010.dta", clear

* 3. Run the routine
do "code/hlm-setup-rebuild_provinces.do"
```

If you keep the repository elsewhere, change the global `HLM_DIR` at the top of the do-file instead.

## Output

The routine adds the following variables to the dataset in memory:

| Variable | Description |
|---|---|
| `province` | Province plaka code (1–81) |
| `plaka` | Plaka code from the sequential sweep (before splitting contiguous pairs) |
| `nuts2` | NUTS-2 code |
| `block` | Block identifier used in the sweep |
| `reweighting_factor` | Target population / observed weight (Part B) |
| `reweighted_weight` | Final weight, province × urban/rural, calibrated to NUTS-2 totals |

If any of these variables already exist, they are dropped and recreated.

## Data

`data/province_2000_2013_FINAL.dta` contains total, urban and rural population for the 81 provinces of Turkey, 2000–2013 (1,134 rows; variables `plate`, `province`, `year`, `total`, `urban`, `rural`).

Source: [TurkStat – Census 2000 / ABPRS, and interpolation when needed].

## Validation

The identification is validated internally, using the structure of existing multi-province clusters, and externally against Census and ABPRS population data and Social Security Institution (SSI) records on major economic activities. See the working paper for details.

## Citation

If you use this routine, please cite the working paper:

> Pinedo Caro, L. (2026). *Recovering Province Identifiers from Turkish Household Labour Force Survey Microdata*. BETAM Working Paper WP202603. Bahçeşehir University Center for Economic and Social Research (BETAM), Istanbul. https://betam.bahcesehir.edu.tr/wp-content/uploads/2026/09/WP202603.pdf

## License

Code released under the MIT License. See [LICENSE](LICENSE).
