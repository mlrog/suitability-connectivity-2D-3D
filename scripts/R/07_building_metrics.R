# =============================================================
# Building Structure Metrics — 100 m Grid
# =============================================================
# Purpose: Processes building footprint polygons to derive
#          three 3D structural metrics aggregated to a 100 m
#          grid for use as environmental predictors in MaxEnt
#          habitat suitability modeling:
#
#            - Mean building height (m) per 100 m cell
#            - SD of building height (m) per 100 m cell
#            - Total building volume (m³) per 100 m cell
#
#          Building height and volume are derived from LiDAR-
#          based building footprint data (LARIAC4) for the
#          City of Los Angeles (Los Angeles GeoHub 2017).
#
# NA conventions:
#          Mean and SD building height are set to NA for cells
#          containing no buildings. 
#
#          Total building volume is set to 0 for empty cells
#          because a cell with no buildings has zero
#          building volume.
#
# Inputs:  - Building footprint shapefile (see CONFIGURATION)
#          - Study area boundary shapefile (see CONFIGURATION)
#
# Outputs: Three GeoTIFFs at 100 m resolution (EPSG:26911):
#            - building_height_mean_100m.tif
#            - building_height_sd_100m.tif
#            - building_volume_100m.tif
#
# Paper:   Rogers, M. L., Frazier, A. E., Zellmer, A. J., & 
#          Lerman, S. B. (2026). Sensitivity of habitat 
#          suitability-derived connectivity models to 
#          three-dimensional measures of urban landscape structure. 
#          Urban Ecosystems, 29(3), 121. 
#          https://doi.org/10.1007/s11252-026-01948-y

# =============================================================


# =============================================================
# SETUP
# =============================================================

library(sf)
library(terra)
library(dplyr)
library(data.table)


# =============================================================
# CONFIGURATION — update file paths before running
# =============================================================

# Path to building footprint shapefile
# Source: LARIAC4 LiDAR-derived building footprints
# (Los Angeles GeoHub 2017)
BUILDINGS_PATH <- "path/to/your_building_footprints.shp"

# Path to study area boundary shapefile (projected, EPSG:26911)
BOUNDARY_PATH <- "path/to/your_study_boundary.shp"

# Output directory for raster files
OUTPUT_DIR <- "outputs/building_metrics"

# Output grid resolution (meters)
GRID_RES <- 100

# Projected CRS for all spatial operations (UTM Zone 11N).
# EPSG:26911 is used because building area and volume calculations
# require a projected CRS with linear units (meters). Outputs are
# later reprojected to WGS 84 (EPSG:4326) for use as MaxEnt
# environmental predictors (see Banta Lab preprocessing scripts).
TARGET_CRS <- 26911

# Minimum building area to retain (m²) — removes artifact structures
MIN_AREA_M2 <- 20

# Minimum building height to retain (m) — removes artifact structures
MIN_HEIGHT_M <- 2

# Create output directory if it does not exist
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)


# =============================================================
# LOAD & PREPROCESS BUILDING FOOTPRINTS
# =============================================================

# Load building footprints and reproject to target CRS
buildings_raw <- st_read(BUILDINGS_PATH, quiet = TRUE)
buildings <- st_transform(buildings_raw, TARGET_CRS)

# Verify CRS
st_crs(buildings)

# Remove courtyard polygons — these are interior voids within
# building footprints, not structures, and would skew metrics
buildings <- buildings %>%
  filter(CODE != "Courtyard")

# Convert units from feet to meters
# HEIGHT and AREA fields are in imperial units in the source data
buildings <- buildings %>%
  mutate(
    height_m = HEIGHT * 0.3048,   # feet to meters
    area_m2  = AREA   * 0.092903  # square feet to square meters
  )

# QA: check height and area distributions before filtering
cat("Height and area summary before filtering:\n")
summary(buildings$height_m)
summary(buildings$area_m2)

# Remove artifact structures below minimum size and height thresholds
# These likely represent data artifacts rather than real structures
buildings <- buildings %>%
  filter(
    area_m2  >= MIN_AREA_M2,
    height_m >= MIN_HEIGHT_M
  )

# QA: check distributions and row count after filtering
cat("Height and area summary after filtering:\n")
summary(buildings$height_m)
summary(buildings$area_m2)
cat("Buildings retained:", nrow(buildings), "\n")


# =============================================================
# CREATE 100 m GRID RASTER TEMPLATE
# =============================================================

# Load study area boundary
boundary <- st_read(BOUNDARY_PATH, quiet = TRUE)

# Verify CRS and geometry type
st_crs(boundary)
st_geometry_type(boundary)

# Build 100 m raster template snapped to round coordinates.
# Extent is expanded to the nearest 100 m to ensure full
# coverage of the study area boundary.
r_template <- rast(
  xmin       = floor(ext(boundary)[1]   / GRID_RES) * GRID_RES,
  xmax       = ceiling(ext(boundary)[2] / GRID_RES) * GRID_RES,
  ymin       = floor(ext(boundary)[3]   / GRID_RES) * GRID_RES,
  ymax       = ceiling(ext(boundary)[4] / GRID_RES) * GRID_RES,
  resolution = GRID_RES,
  crs        = crs(boundary)
)

# Convert raster template to polygon grid for spatial intersection
grid_100m <- as.polygons(r_template)
grid_100m$cell_id <- seq_len(nrow(grid_100m))
grid_100m_sf <- st_as_sf(grid_100m)

# QA: verify cell count and area (~10,000 m² expected per cell)
cat("Total grid cells:", nrow(grid_100m_sf), "\n")
cat("Cell area (m²):", as.numeric(st_area(grid_100m_sf)[1]), "\n")

# Clip grid to study area boundary
grid_100m_sf <- st_intersection(grid_100m_sf, boundary)


# =============================================================
# SPATIAL INTERSECTION: BUILDINGS × 100 m GRID
# =============================================================

# Intersect building footprints with grid cells.
# Buildings spanning multiple cells are split into fragments,
# one fragment per cell, preserving the geometry of overlap.
bldg_fragments <- st_intersection(buildings, grid_100m_sf)

# Compute the area of each fragment from its clipped geometry
bldg_fragments <- bldg_fragments %>%
  mutate(
    fragment_area_m2 = as.numeric(st_area(geometry))
  )

# QA: fragment area range (max should be ≤ 10,000 m²)
cat("Fragment area summary:\n")
summary(bldg_fragments$fragment_area_m2)
cat("Max fragment area:", max(bldg_fragments$fragment_area_m2), "\n")

# QA: area conservation check on a random sample of buildings.
# The ratio of summed fragment areas to original building area
# should be tightly clustered around 1.0, confirming that
# splitting buildings across cells preserves total area.
set.seed(42)
sample_ids <- sample(unique(bldg_fragments$BLD_ID), size = 1000)

area_check_sample <- bldg_fragments %>%
  filter(BLD_ID %in% sample_ids) %>%
  group_by(BLD_ID) %>%
  summarise(
    fragment_area_sum = sum(fragment_area_m2),
    original_area_m2  = first(area_m2),
    .groups = "drop"
  )

cat("Area conservation ratios (expect values near 1.0):\n")
summary(area_check_sample$fragment_area_sum /
          area_check_sample$original_area_m2)

# Remove zero-area fragments (slivers from intersection)
bldg_fragments <- bldg_fragments %>%
  filter(fragment_area_m2 > 1e-6)

cat("Fragments retained after sliver removal:",
    nrow(bldg_fragments), "\n")


# =============================================================
# COMPUTE FRAGMENT-LEVEL BUILDING VOLUME
# =============================================================

# Volume = height × clipped fragment area (m³)
# This distributes a building's volume proportionally across
# the grid cells it overlaps
bldg_fragments <- bldg_fragments %>%
  mutate(
    fragment_volume_m3 = height_m * fragment_area_m2
  )

# QA: volume summary
cat("Fragment volume summary:\n")
summary(bldg_fragments$fragment_volume_m3)


# =============================================================
# AGGREGATE BUILDING METRICS TO 100 m GRID CELLS
# =============================================================

# Convert to data.table for efficient aggregation
dt <- as.data.table(bldg_fragments)

# Deduplicate to one row per building per cell before computing
# height statistics. A building spanning multiple cells contributes
# its height once per cell, not once per fragment.
bldg_cell_heights <- dt[
  , .(height_m = height_m[1]),
  by = .(cell_id, BLD_ID)
]

# QA: confirm deduplication removed only duplicate rows
cat("Fragments before deduplication:", nrow(bldg_fragments), "\n")
cat("Rows after deduplication:", nrow(bldg_cell_heights), "\n")
cat("Rows removed:", nrow(bldg_fragments) - nrow(bldg_cell_heights), "\n")

# QA: confirm no remaining duplicates (expect 0 rows)
setDT(bldg_cell_heights)
duplicates <- bldg_cell_heights[, .N, by = .(cell_id, BLD_ID)][N > 1]
cat("Duplicate (cell_id, BLD_ID) pairs (expect 0):", nrow(duplicates), "\n")

# QA: height distributions should match before and after deduplication
cat("Height summary — fragments:\n")
summary(bldg_fragments$height_m)
cat("Height summary — deduplicated:\n")
summary(bldg_cell_heights$height_m)

# Compute mean and SD of building height per 100 m cell.
# NA convention: cells with no buildings retain NA (not 0) to
# avoid deflating the mean or inflating variance with non-data.
bldg_height_stats <- bldg_cell_heights[
  , .(
    bldg_ht_mean = mean(height_m),
    bldg_ht_sd   = if (.N > 1) sd(height_m) else 0
  ),
  by = cell_id
]

cat("Mean building height summary:\n")
summary(bldg_height_stats$bldg_ht_mean)
cat("SD building height summary:\n")
summary(bldg_height_stats$bldg_ht_sd)

# Compute total building volume per 100 m cell.
# 0 convention: cells with no buildings are assigned 0 because
# the absence of buildings represents a true zero volume,
# not missing data.
bldg_volume <- dt[
  , .(bldg_volume_m3 = sum(fragment_volume_m3)),
  by = cell_id
]

cat("Building volume summary:\n")
summary(bldg_volume$bldg_volume_m3)


# =============================================================
# JOIN METRICS TO FULL 100 m GRID
# =============================================================

# Join height stats and volume to the full grid.
# Cells with no buildings will have NA for height metrics
# and will be assigned 0 for volume after the join.
grid_dt <- as.data.table(grid_100m_sf)

grid_bldg_metrics <- merge(grid_dt, bldg_height_stats,
                           by = "cell_id", all.x = TRUE)
grid_bldg_metrics <- merge(grid_bldg_metrics, bldg_volume,
                           by = "cell_id", all.x = TRUE)

# Assign 0 to cells with no building volume (true zero, not missing)
grid_bldg_metrics[is.na(bldg_volume_m3), bldg_volume_m3 := 0]

# Convert back to sf for rasterization
grid_bldg_metrics_sf <- st_as_sf(
  grid_bldg_metrics,
  sf_column_name = attr(grid_100m_sf, "sf_column"),
  crs = st_crs(grid_100m_sf)
)

# QA: final metric summaries
cat("Final grid metric summaries:\n")
summary(grid_bldg_metrics_sf$bldg_ht_mean)
summary(grid_bldg_metrics_sf$bldg_ht_sd)
summary(grid_bldg_metrics_sf$bldg_volume_m3)

# Volume conservation check: ratio of gridded total to
# raw building total should be close to 1.0
conservation_ratio <- sum(grid_bldg_metrics$bldg_volume_m3) /
  sum(buildings$height_m * buildings$area_m2)
cat("Volume conservation ratio (expect ~1.0):",
    conservation_ratio, "\n")


# =============================================================
# RASTERIZE TO 100 m GRID
# =============================================================

grid_bldg_vect <- vect(grid_bldg_metrics_sf)

# QA: verify CRS and resolution match template
cat("Vector CRS:", crs(grid_bldg_vect, describe = TRUE)$code, "\n")
cat("Template resolution:", res(r_template), "\n")

# Rasterize mean building height
bldg_ht_mean_r <- rasterize(grid_bldg_vect, r_template,
                            field = "bldg_ht_mean")

# Rasterize SD of building height
bldg_ht_sd_r <- rasterize(grid_bldg_vect, r_template,
                          field = "bldg_ht_sd")

# Rasterize total building volume
bldg_volume_r <- rasterize(grid_bldg_vect, r_template,
                           field = "bldg_volume_m3")


# =============================================================
# PREPARE MAXENT-READY OUTPUTS
# =============================================================

# Mean and SD building height: replace NA with 0 for MaxEnt.
# NA cells represent areas with no buildings
bldg_ht_mean_maxent <- bldg_ht_mean_r
bldg_ht_mean_maxent[is.na(bldg_ht_mean_maxent)] <- 0

bldg_ht_sd_maxent <- bldg_ht_sd_r
bldg_ht_sd_maxent[is.na(bldg_ht_sd_maxent)] <- 0

# QA: confirm expected ranges
cat("Mean building height range:\n")
global(bldg_ht_mean_maxent, range)
cat("SD building height range:\n")
global(bldg_ht_sd_maxent, range)

# Mask all rasters to study area boundary
bldg_ht_mean_maxent <- mask(bldg_ht_mean_maxent, boundary)
bldg_ht_sd_maxent   <- mask(bldg_ht_sd_maxent,   boundary)
bldg_volume_maxent  <- mask(bldg_volume_r,        boundary)


# =============================================================
# EXPORT
# =============================================================

writeRaster(
  bldg_ht_mean_maxent,
  file.path(OUTPUT_DIR, "building_height_mean_100m.tif"),
  overwrite = TRUE
)

writeRaster(
  bldg_ht_sd_maxent,
  file.path(OUTPUT_DIR, "building_height_sd_100m.tif"),
  overwrite = TRUE
)

writeRaster(
  bldg_volume_maxent,
  file.path(OUTPUT_DIR, "building_volume_100m.tif"),
  overwrite = TRUE
)

cat("Outputs written to:", OUTPUT_DIR, "\n")
