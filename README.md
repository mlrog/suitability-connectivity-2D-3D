# suitability-connectivity-2D-3D

## Sensitivity of Habitat Suitability-Derived Connectivity Models to Three-Dimensional Measures of Urban Landscape Structure

**Authors:** Morgan L. Rogers, Amy E. Frazier, Amanda J. Zellmer, Susannah B. Lerman

**Journal:** Urban Ecosystems (accepted)

**Paper DOI:** [To be added upon publication]

**Repository DOI:** [To be added upon Zenodo release]

---

## Overview

Ecological connectivity models commonly derive resistance surfaces from 
habitat suitability; however, it remains unclear how two-dimensional (2D) 
versus three-dimensional (3D) representations of landscape propagate through 
this modeling pipeline, particularly in urban environments. This study 
evaluated the sensitivity of habitat suitability and connectivity outputs 
derived from these models to the inclusion of 3D landscape structure for two 
bird species with contrasting habitat associations, the Western Bluebird 
(*Sialia mexicana*) and Acorn Woodpecker (*Melanerpes formicivorus*), in Los 
Angeles, California, USA.

---

## Repository Structure
```
suitability-connectivity-2D-3D/
│
├── scripts/
│   ├── gee/                          # Google Earth Engine scripts
│   │   ├── 01_nlcd_developed_open_space_prop.js
│   │   ├── 02_nlcd_grass_prop.js
│   │   ├── 03_nlcd_shrub_prop.js
│   │   ├── 04_nlcd_water_prop.js
│   │   ├── 05_nlcd_impervious_prop.js
│   │   └── 06_ndvi_annual_mean_100m.js
│   │
│   └── R/                            # R scripts
│       ├── 07_building_metrics.R
│       ├── 08_tree_canopy_proportion.R
│       ├── 09_tree_height_metrics.R
│       ├── 10_cpad_open_space_proportion.R
│       ├── 11_resistance_transformation.R
│       ├── 12_hellinger_niche_similarity.R
│       ├── 13_spearman_correlation.R
│       └── 14_connectivity_comparison.R
│
└── README.md
```

---

## Script Descriptions

### GEE Scripts — Environmental Predictors
Scripts 01–06 were developed and executed in the
[Google Earth Engine Code Editor](https://code.earthengine.google.com/).
They compute 2D environmental predictor rasters at 100 m resolution for use
as MaxEnt inputs.

| Script | Description |
|--------|-------------|
| `01_nlcd_developed_open_space_prop.js` | Proportion of NLCD class 21 (Developed, Open Space) per 100 m cell |
| `02_nlcd_grass_prop.js` | Proportion of NLCD class 71 (Grassland/Herbaceous) per 100 m cell |
| `03_nlcd_shrub_prop.js` | Proportion of NLCD class 52 (Shrub/Scrub) per 100 m cell |
| `04_nlcd_water_prop.js` | Proportion of NLCD class 11 (Open Water) per 100 m cell |
| `05_nlcd_impervious_prop.js` | Proportion of impervious surface per 100 m cell |
| `06_ndvi_annual_mean_100m.js` | Annual mean NDVI at 100 m from Sentinel-2 (2022) |

### R Scripts — Environmental Predictors
Scripts 07–10 process additional environmental predictor rasters at 100 m
resolution from locally held datasets.

| Script | Description |
|--------|-------------|
| `07_building_metrics.R` | Mean building height, SD of building height, and total building volume per 100 m cell from LiDAR-derived building footprints |
| `08_tree_canopy_proportion.R` | Proportion of tree canopy cover per 100 m cell from CTrees canopy polygons |
| `09_tree_height_metrics.R` | Mean and SD of tree canopy height per 100 m cell from CTrees canopy height model |
| `10_cpad_open_space_proportion.R` | Proportion of protected open space per 100 m cell from CPAD |

### R Scripts — Resistance Transformation
| Script | Description |
|--------|-------------|
| `11_resistance_transformation.R` | Converts MaxEnt cloglog habitat suitability outputs to resistance surfaces for Omniscape connectivity modeling |

### R Scripts — Analysis
| Script | Description |
|--------|-------------|
| `12_hellinger_niche_similarity.R` | Computes Hellinger-based niche similarity index (I) between 2D and 3D MaxEnt outputs for each species |
| `13_spearman_correlation.R` | Computes Spearman rank correlation between 2D and 3D MaxEnt suitability outputs |
| `14_connectivity_comparison.R` | Computes Pearson correlation between 2D and 3D Omniscape outputs and generates top 10% current flow difference maps |

---

## Dependencies

### R
- R v4.4.3
- `terra` v1.8.70
- `sf` v1.0.21
- `dplyr` v1.1.4
- `purrr` v1.1.0
- `tidyr` v1.3.1
- `data.table` v1.17.8

### Google Earth Engine
Scripts 01–06 require a Google Earth Engine account. Access is free for
research and education. Register at
[https://earthengine.google.com](https://earthengine.google.com).

---

## Data

### Publicly Available Data
The following datasets are publicly available and can be downloaded directly:

| Dataset | Source | Access |
|---------|--------|--------|
| National Land Cover Database (NLCD) 2021 | Dewitz (2023) | [MRLC](https://www.mrlc.gov/) |
| Sentinel-2 Level-2A surface reflectance | European Space Agency (2022) | [Google Earth Engine](https://developers.google.com/earth-engine/datasets/catalog/COPERNICUS_S2_SR_HARMONIZED) |
| California Protected Areas Database (CPAD) v2020b | GreenInfo Network (2023) | [CALands](https://www.calands.org/) |
| LARIAC4 Building Footprints | Los Angeles GeoHub (2017) | [LA GeoHub](https://geohub.lacity.org/) |

### Data Requiring Request
The following dataset is not publicly available for download and must be
requested directly from the data provider:

| Dataset | Source | Access |
|---------|--------|--------|
| CTrees Sub-Meter Canopy Height Model, Los Angeles (2022) | CTrees.org | Email: info@ctrees.org |

**Citation for CTrees dataset:**
> CTrees.org. (2022). Sub-Meter Canopy Tree Height of Los Angeles Urban
> Area, CA [Dataset]. Accessed 29 January 2026.

### Third-Party Scripts and Attribution
MaxEnt modeling and environmental layer preprocessing were conducted using
scripts from the Banta Lab. These scripts are not included in this repository
and must be obtained directly from the original authors:

- Banta, J. A. (2024). *How to run Maxent using R* [Computer software].
  Patreon. https://www.patreon.com/collection/625696
- Banta, J. A. (n.d.). *Environmental layer alignment tutorial* [R scripts].
  The Banta Lab. https://sites.google.com/site/thebantalab/tutorials

---

## Workflow

The scripts in this repository follow this pipeline order:
```
GEE Scripts (01–06)
        ↓
Environmental predictor rasters (.tif, 100 m, EPSG:26911)
        ↓
R Scripts (07–10)
        ↓
All environmental predictors aligned to WGS 84 via Banta Lab scripts
        ↓
MaxEnt habitat suitability modeling (via Banta Lab scripts)
        ↓
R Script (11): Resistance transformation
        ↓
Omniscape connectivity modeling (Julia)
        ↓
R Scripts (12–14): Analysis and comparison
```

---

## Citation

If you use the code in this repository, please cite both the associated
paper and the repository:

**Paper:**
> Rogers, M. L., Frazier, A. E., Zellmer, A. J., & Lerman, S. B. (in press).
> Sensitivity of habitat suitability-derived connectivity models to
> three-dimensional measures of urban landscape structure.
> *Urban Ecosystems*. [DOI to be added upon publication]

**Repository:**
> Rogers, M. L., Frazier, A. E., Zellmer, A. J., & Lerman, S. B. (2025).
> suitability-connectivity-2D-3D [Computer software]. Zenodo.
> [DOI to be added upon Zenodo release]

---

## License

- **Code:** MIT License — see [LICENSE](LICENSE)
- **Code:** CC BY 4.0 — see [LICENSE-DATA](LICENSE-DATA)
