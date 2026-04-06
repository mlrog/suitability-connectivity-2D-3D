# Data

This directory contains the occurrence data and model outputs
associated with:

> Rogers, M. L., Frazier, A. E., Zellmer, A. J., & Lerman, S. B.
> (in press). Sensitivity of habitat suitability-derived
> connectivity models to three-dimensional measures of urban
> landscape structure. *Urban Ecosystems*.
> [DOI to be added upon publication]

---

## Directory Structure
```
data/
├── occurrence/           # Species occurrence records
├── habitat_suitability/  # MaxEnt habitat suitability outputs
└── connectivity/         # Omniscape connectivity outputs
```

---

## Occurrence Data

### Files
| File | Species | Records |
|------|---------|---------|
| `western_bluebird_occurrences.csv` | Western Bluebird (*Sialia mexicana*) | 280 |
| `acorn_woodpecker_occurrences.csv` | Acorn Woodpecker (*Melanerpes formicivorus*) | 199 |

### Fields
| Field | Description |
|-------|-------------|
| `decimalLatitude` | Latitude in decimal degrees (WGS 84) |
| `decimalLongitude` | Longitude in decimal degrees (WGS 84) |

### Data Source and Processing
Occurrence records were obtained from iNaturalist via the Global
Biodiversity Information Facility (GBIF). Records were filtered
to include only research grade observations with valid geographic
coordinates for the years 2020–2024, within the City of Los
Angeles. Only records with a reported coordinate uncertainty of
50 m or less were retained. Records were then spatially thinned
to one occurrence per 100 m raster cell to reduce spatial
clustering arising from sampling bias using the R package spThin.

The files in this repository represent the post-thinning filtered
occurrence records used for MaxEnt habitat suitability modeling.

### Citations
> GBIF.org (04 February 2026) GBIF Occurrence Download —
> Western Bluebird (*Sialia mexicana*).
> https://doi.org/10.15468/dl.er62wc

> GBIF.org (04 February 2026) GBIF Occurrence Download —
> Acorn Woodpecker (*Melanerpes formicivorus*).
> https://doi.org/10.15468/dl.j9dty3

---

## Habitat Suitability

### Files
| File | Species | Model | Variables |
|------|---------|-------|-----------|
| `2D_bluebird_suitability.asc` | Western Bluebird (*Sialia mexicana*) | 2D | 7 |
| `3D_bluebird_suitability.asc` | Western Bluebird (*Sialia mexicana*) | 3D | 9 |
| `2D_woodpecker_suitability.asc` | Acorn Woodpecker (*Melanerpes formicivorus*) | 2D | 7 |
| `3D_woodpecker_suitability.asc` | Acorn Woodpecker (*Melanerpes formicivorus*) | 3D | 9 |

### Format
- Format: Arc/Info ASCII Grid (.asc)
- Resolution: ~100 m (0.000964°)
- Extent: City of Los Angeles, CA
- CRS: WGS 84 (EPSG:4326) 
- Value range: 0 (least suitable) to 1 (most suitable)
- Output type: cloglog (complementary log-log)

### Environmental Variables

**2D models (both species):**
| Variable | Description |
|----------|-------------|
| Developed open space | Proportion of NLCD class 21 per 100 m cell |
| Grass | Proportion of NLCD class 71 per 100 m cell |
| Shrub | Proportion of NLCD class 52 per 100 m cell |
| Water | Proportion of NLCD class 11 per 100 m cell |
| Impervious | Proportion of impervious surface per 100 m cell |
| Tree canopy | Proportion of tree canopy cover per 100 m cell |
| Protected open space | Proportion of CPAD protected open space per 100 m cell |

**Additional 3D variables — Western Bluebird:**
| Variable | Description |
|----------|-------------|
| SD tree height | Standard deviation of tree canopy height per 100 m cell |
| Mean building height | Mean building height per 100 m cell |

**Additional 3D variables — Acorn Woodpecker:**
| Variable | Description |
|----------|-------------|
| Mean tree height | Mean tree canopy height per 100 m cell |
| Mean building height | Mean building height per 100 m cell |

### Model Selection
The best performing model for each species and dimensional
representation (2D and 3D) was selected based on AUC training,
AUC test, AUC difference, and TSS. See the manuscript for full
model performance metrics and candidate model details.

---

## Connectivity

### Files
| File | Species | Model |
|------|---------|-------|
| `2D_bluebird_cum_currmap.tif` | Western Bluebird (*Sialia mexicana*) | 2D |
| `3D_bluebird_cum_currmap.tif` | Western Bluebird (*Sialia mexicana*) | 3D |
| `2D_woodpecker_cum_currmap.tif` | Acorn Woodpecker (*Melanerpes formicivorus*) | 2D |
| `3D_woodpecker_cum_currmap.tif` | Acorn Woodpecker (*Melanerpes formicivorus*) | 3D |

### Format
- Format: GeoTIFF (.tif)
- Resolution: ~100 m (0.000964°)
- Extent: City of Los Angeles, CA
- CRS: WGS 84 (EPSG:4326)
- Value range: continuous positive values representing cumulative
  current flow across the landscape
- Output type: Omniscape cumulative current flow

### Connectivity Modeling
Connectivity was modeled using Omniscape.jl v0.6.2 in Julia
v1.12.4 with a 1 km moving window radius. Habitat suitability
rasters served as both the source layer and the basis for
resistance surfaces. Resistance surfaces were derived from
MaxEnt cloglog outputs using a linear inverse transformation
(see `scripts/R/11_resistance_transformation.R`). See the
manuscript for full Omniscape parameterization details and
`scripts/julia/omniscape_config.ini` for the configuration
file used.

---

## License

Data are released under CC BY 4.0.
See [LICENSE-DATA](../LICENSE-DATA) for details.
