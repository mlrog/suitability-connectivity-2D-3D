# =============================================================
# Tree Canopy Cover — Proportion at 100 m
# =============================================================
# Purpose: Calculates the proportion of tree canopy cover
#          within each 100 m pixel over the study area
#          boundary using a high-resolution tree canopy
#          polygon layer derived from LiDAR.
#
#          The terra::rasterize() function with cover = TRUE
#          computes the fractional coverage of canopy polygons
#          within each 100 m cell directly, without requiring
#          an intermediate polygon intersection step.
#
# Data Access:
#          The tree canopy polygon layer is derived from the
#          CTrees sub-meter canopy height dataset for Los
#          Angeles. This dataset is not publicly available
#          for download and must be requested directly from
#          CTrees:
#
#            Email:  info@ctrees.org
#            Citation: CTrees.org. (2022). Sub-Meter Canopy
#            Tree Height of Los Angeles Urban Area, CA
#            [Dataset]. Accessed 29 January 2026.
#
# Inputs:  - Tree canopy polygon shapefile (CTrees-derived,
#            0.6 m source resolution — see Data Access above)
#          - Study area boundary shapefile
#
# Output:  - tree_canopy_proportion_100m.tif
#            Proportion of tree canopy cover per 100 m cell
#            Range: 0 (no canopy) to 1 (full canopy cover)
#            CRS: EPSG:26911 (UTM Zone 11N)
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

library(terra)


# =============================================================
# CONFIGURATION — update file paths before running
# =============================================================

# Path to tree canopy polygon shapefile (CTrees-derived)
# See Data Access note in header above for how to obtain
CANOPY_PATH <- "path/to/your_tree_canopy_polygons.shp"

# Path to study area boundary shapefile
BOUNDARY_PATH <- "path/to/your_study_boundary.shp"

# Output directory
OUTPUT_DIR <- "outputs/tree_canopy"

# Output grid resolution (meters)
GRID_RES <- 100

# Create output directory if it does not exist
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)


# =============================================================
# LOAD DATA
# =============================================================

# Load tree canopy polygons and study area boundary
canopy     <- vect(CANOPY_PATH)
boundary   <- vect(BOUNDARY_PATH)

# Verify CRS — both layers must match before rasterization
cat("Canopy CRS:\n")
crs(canopy, describe = TRUE)
cat("Boundary CRS:\n")
crs(boundary, describe = TRUE)


# =============================================================
# CREATE 100 m RASTER TEMPLATE
# =============================================================

# Build 100 m raster template snapped to round coordinates.
# Extent is expanded to the nearest 100 m to ensure full
# coverage of the study area boundary.
r_template <- rast(
  xmin       = floor(ext(boundary)[1]   / GRID_RES) * GRID_RES,
  xmax       = ceiling(ext(boundary)[2] / GRID_RES) * GRID_RES,
  ymin       = floor(ext(boundary)[3]   / GRID_RES) * GRID_RES,
  ymax       = ceiling(ext(boundary)[4] / GRID_RES) * GRID_RES,
  resolution = GRID_RES,
  crs        = crs(canopy)
)

# QA: verify resolution and CRS
cat("Template resolution (expect 100 100):", res(r_template), "\n")
cat("Template CRS:\n")
crs(r_template, describe = TRUE)


# =============================================================
# RASTERIZE CANOPY POLYGONS
# =============================================================

# Compute fractional canopy coverage per 100 m cell using
# cover = TRUE. This calculates the proportion of each cell's
# area covered by canopy polygons (range: 0-1), equivalent
# to an area-weighted aggregation from the 0.6 m source data.
canopy_prop <- rasterize(
  canopy,
  r_template,
  field = 1,
  cover = TRUE
)


# =============================================================
# MASK TO STUDY BOUNDARY & HANDLE NA VALUES
# =============================================================

# Mask to study area boundary
canopy_prop <- mask(canopy_prop, boundary)

# Set NA pixels within the boundary to 0.
# NA values within the boundary represent cells with no
# canopy polygons present, which is a true zero (no tree
# canopy), not missing data.
canopy_prop[is.na(canopy_prop)] <- 0


# =============================================================
# QA
# =============================================================

# Value range check — should be 0 to 1
cat("Canopy proportion range:\n")
global(canopy_prop, range, na.rm = TRUE)

# Cell count check
cat("Total non-NA cells:", global(!is.na(canopy_prop), "sum")[[1]], "\n")


# =============================================================
# EXPORT
# =============================================================

writeRaster(
  canopy_prop,
  file.path(OUTPUT_DIR, "tree_canopy_proportion_100m.tif"),
  overwrite = TRUE
)

cat("Output written to:", OUTPUT_DIR, "\n")
