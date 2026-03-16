# =============================================================
# Tree Canopy Height Metrics — Mean and SD at 100 m
# =============================================================
# Purpose: Derives two tree canopy height metrics aggregated
#          to 100 m resolution from a high-resolution (0.6 m)
#          canopy height model (CHM):
#
#            - Mean tree canopy height (m) per 100 m cell
#            - SD of tree canopy height (m) per 100 m cell
#
#          Both metrics are computed from trees-only pixels
#          (background value 0 excluded) so that mean and SD
#          reflect the distribution of tree heights within
#          each cell. 
#
# Data Access:
#          This dataset is not publicly available for download
#          and must be requested directly from CTrees:
#
#            Email:   info@ctrees.org
#            Citation: CTrees.org. (2022). Sub-Meter Canopy
#            Tree Height of Los Angeles Urban Area, CA
#            [Dataset]. Accessed 29 January 2026.
#
# NA conventions:
#          Mean and SD height are NA for cells with no trees,
#          then set to 0 in the final output. This prevents
#          non-tree pixels from deflating the mean or
#          artificially inflating variance. See building
#          metrics script for detailed explanation.
#
# Inputs:  - CTrees canopy height VRT (0.6 m, see Data Access)
#          - Study area boundary shapefile
#          - Mean canopy height raster (trees-only, produced
#            in Part 1 — required as input for Part 2)
#
# Outputs: Two GeoTIFFs at 100 m resolution (EPSG:26911):
#            - canopy_height_mean_100m.tif
#            - canopy_height_sd_100m.tif
#
# Paper:   [Full citation or "In review, Journal of Urban Ecosystems"]
# =============================================================


# =============================================================
# SETUP
# =============================================================

library(terra)

# Memory and processing options for large raster operations.
# memfrac: proportion of available RAM terra may use (0-1)
# progress: print progress bar for operations taking > 5 sec
terraOptions(
  memfrac = 0.7,
  progress = 5,
  tempdir  = tempdir()
)


# =============================================================
# CONFIGURATION — update file paths before running
# =============================================================

# Path to CTrees canopy height VRT (0.6 m resolution)
# See Data Access note in header above for how to obtain
VRT_PATH <- "path/to/trees_height.vrt"

# Path to study area boundary shapefile
BOUNDARY_PATH <- "path/to/your_study_boundary.shp"

# Output directory
OUTPUT_DIR <- "outputs/tree_height"

# Output grid resolution (meters)
GRID_RES <- 100

# NoData threshold — values at or above this are set to NA.
# 255 is the documented NoData value in the CTrees dataset.
# Threshold is set to 250 to catch any near-NoData artifacts.
NODATA_THRESHOLD <- 250

# Height cap (meters) — values above this are set to the cap.
# The CTrees dataset documents a maximum height of 35.2 m.
# Values above 40 m were identified as data artifacts during
# QA and are capped at this conservative threshold.
HEIGHT_CAP <- 40

# Create output directory if it does not exist
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)


# =============================================================
# PART 1: MEAN CANOPY HEIGHT AT 100 m
# =============================================================

# -------------------------------------------------------------
# Load data
# -------------------------------------------------------------

boundary <- vect(BOUNDARY_PATH)
chm_06m  <- rast(VRT_PATH)

# QA: verify CRS and resolution of source data
cat("CHM CRS:\n")
crs(chm_06m, describe = TRUE)
cat("CHM resolution:", res(chm_06m), "\n")
cat("CHM value range:\n")
print(global(chm_06m, "range", na.rm = TRUE))

# -------------------------------------------------------------
# Clean CHM values
# -------------------------------------------------------------

# Recode NoData values to NA
# 255 is the documented NoData value; threshold set to 250
# to catch near-NoData artifacts
chm_06m[chm_06m >= NODATA_THRESHOLD] <- NA

# Clip to study area boundary
chm_la <- crop(chm_06m, boundary)
chm_la <- mask(chm_la, boundary)

# Cap implausible height values identified during QA.
# values above 40 m are treated as data artifacts.
chm_la[chm_la > HEIGHT_CAP] <- HEIGHT_CAP

# Force floating point for subsequent calculations
chm_la <- as.numeric(chm_la)

# QA: confirm cleaned value range
cat("Cleaned CHM value range:\n")
print(global(chm_la, "range", na.rm = TRUE))

# -------------------------------------------------------------
# Trees-only CHM
# -------------------------------------------------------------

# Exclude background pixels (0 = no tree canopy).
# Mean and SD are computed only over tree-containing pixels
# so that non-tree areas do not dilute height statistics.
chm_trees_only <- chm_la
chm_trees_only[chm_trees_only == 0] <- NA

# QA: confirm trees-only range (expect > 0)
cat("Trees-only CHM range:\n")
print(global(chm_trees_only, "range", na.rm = TRUE))

# -------------------------------------------------------------
# Create 100 m raster template
# -------------------------------------------------------------

# Build 100 m template snapped to round coordinates
template_100m <- rast(
  ext        = ext(boundary),
  resolution = GRID_RES,
  crs        = crs(chm_la)
)

# Force stable origin so grid aligns exactly to 100 m cells
origin(template_100m) <- c(0, 0)

# QA: confirm resolution
cat("Template resolution (expect 100 100):", res(template_100m), "\n")

# -------------------------------------------------------------
# Compute mean canopy height at 100 m
# -------------------------------------------------------------

# Aggregate trees-only CHM to 100 m using area-weighted mean.
# NA cells (non-tree) are excluded from the mean calculation.
canopy_mean_100m <- resample(
  chm_trees_only,
  template_100m,
  method   = "average",
  filename = file.path(OUTPUT_DIR,
                       "canopy_height_mean_treesonly_100m.tif"),
  overwrite = TRUE,
  wopt = list(
    datatype = "FLT4S",
    gdal     = c("COMPRESS=LZW", "TILED=YES")
  )
)

# QA: verify resolution and value range
cat("Mean canopy height resolution:", res(canopy_mean_100m), "\n")
cat("Mean canopy height summary:\n")
print(global(canopy_mean_100m, c("min", "mean", "max"), na.rm = TRUE))

# -------------------------------------------------------------
# Reintroduce zeros and write final mean output
# -------------------------------------------------------------

# Set NA cells (no trees) to 0 for MaxEnt input.
# 0 represents true absence of tree canopy, not missing data.
canopy_mean_final <- canopy_mean_100m
canopy_mean_final[is.na(canopy_mean_final)] <- 0

writeRaster(
  canopy_mean_final,
  file.path(OUTPUT_DIR, "canopy_height_mean_100m.tif"),
  overwrite = TRUE,
  wopt = list(
    datatype = "FLT4S",
    gdal     = c("COMPRESS=LZW", "TILED=YES")
  )
)

cat("Mean output written to:", OUTPUT_DIR, "\n")


# =============================================================
# PART 2: SD OF CANOPY HEIGHT AT 100 m
# =============================================================

# -------------------------------------------------------------
# Reload cleaned CHM if needed
# -------------------------------------------------------------

# If running Part 2 in a fresh session, reload and clean
# the CHM as in Part 1. If running immediately after Part 1,
# chm_trees_only is already in memory — skip this block.

# chm_06m        <- rast(VRT_PATH)
# chm_06m[chm_06m >= NODATA_THRESHOLD] <- NA
# chm_la         <- crop(chm_06m, boundary)
# chm_la         <- mask(chm_la, boundary)
# chm_la[chm_la > HEIGHT_CAP] <- HEIGHT_CAP
# chm_la         <- as.numeric(chm_la)
# chm_trees_only <- chm_la
# chm_trees_only[chm_trees_only == 0] <- NA
# rm(chm_06m, chm_la)
# gc()

# -------------------------------------------------------------
# SD via variance identity: Var(X) = E(X²) - [E(X)]²
# -------------------------------------------------------------
# Direct SD calculation requires holding all 0.6 m pixels
# in memory simultaneously, which exceeds available RAM.
# The variance identity allows SD to be computed in two
# sequential resampling passes instead:
#   Pass 1: compute E(X²) — mean of squared heights at 100 m
#   Pass 2: subtract [E(X)]² using the already-computed mean
# Both passes use trees-only pixels (0s excluded) so the
# variance identity is applied consistently.

# Step 1: Square the trees-only CHM
chm_sq <- chm_trees_only ^ 2

# Step 2: Compute mean of squared heights at 100 m (numerator)
canopy_mean_sq <- resample(
  chm_sq,
  canopy_mean_100m,
  method   = "average",
  filename = file.path(OUTPUT_DIR,
                       "canopy_height_meanSq_100m.tif"),
  overwrite = TRUE,
  wopt = list(
    datatype = "FLT4S",
    gdal     = c("COMPRESS=LZW", "TILED=YES")
  )
)

rm(chm_sq)
gc()

# Step 3: Compute variance using trees-only mean for both terms.
# canopy_mean_100m has NAs for non-tree cells, ensuring
# the identity is applied only over tree-containing pixels.
canopy_var <- canopy_mean_sq - (canopy_mean_100m ^ 2)

# Numerical safety: floating point arithmetic can produce
# very small negative values — clamp to zero
canopy_var[canopy_var < 0] <- 0

# Step 4: SD = sqrt(variance)
canopy_sd <- sqrt(canopy_var)

# Step 5: Reintroduce zeros for non-tree cells
canopy_sd_final <- canopy_sd
canopy_sd_final[is.na(canopy_sd_final)] <- 0

# -------------------------------------------------------------
# Write final SD output
# -------------------------------------------------------------

writeRaster(
  canopy_sd_final,
  file.path(OUTPUT_DIR, "canopy_height_sd_100m.tif"),
  overwrite = TRUE,
  wopt = list(
    datatype = "FLT4S",
    gdal     = c("COMPRESS=LZW", "TILED=YES")
  )
)

# -------------------------------------------------------------
# QA
# -------------------------------------------------------------

cat("SD resolution:", res(canopy_sd_final), "\n")
cat("SD extent:\n")
print(ext(canopy_sd_final))
cat("SD value summary:\n")
print(global(canopy_sd_final, c("min", "mean", "max"), na.rm = TRUE))

cat("Output written to:", OUTPUT_DIR, "\n")
