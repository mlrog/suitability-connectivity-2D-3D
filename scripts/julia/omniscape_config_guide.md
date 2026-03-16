# Omniscape Configuration Guide

## Usage

Run this configuration file once per species and model type by:

1. Creating a folder for each model run containing:
   - `omniscape_config.ini`
   - `resistance.tif` (resistance surface from `11_resistance_transformation.R`)
   - `source.tif` (MaxEnt cloglog habitat suitability output)

2. Updating `project_name` in `omniscape_config.ini` for each run:
   - `2D_bluebird_results`
   - `3D_bluebird_results`
   - `2D_woodpecker_results`
   - `3D_woodpecker_results`

3. Launching Julia from Terminal:
```
julia
```

4. Running Omniscape:
```julia
using Omniscape
run_omniscape("path/to/omniscape_config.ini")
```

## Parameter Notes

| Parameter | Value | Description |
|-----------|-------|-------------|
| `radius` | 10 | Moving window radius in pixels (1 km at 100 m resolution) |
| `block_size` | 1 | Block size for computational efficiency |
| `source_from_resistance` | false | Source layer provided explicitly, not derived from resistance |
| `source_threshold` | 0 | Minimum source value |
| `r_cutoff` | 0 | Resistance cutoff value |
| `calc_flow_potential` | true | Calculate flow potential output |
| `calc_normalized_current` | true | Calculate normalized current output |
| `parallelize` | false | Parallel processing disabled |
| `write_raw_currmap` | true | Write raw cumulative current map |

## Paper
Rogers, M. L., Frazier, A. E., Zellmer, A. J., & Lerman, S. B. (in press).
Sensitivity of habitat suitability-derived connectivity models to
three-dimensional measures of urban landscape structure.
*Urban Ecosystems*. [DOI to be added upon publication]
