# =============================================================
# CPAD Open Space Cover — Proportion at 100 m
# =============================================================
# Purpose: Calculates the proportion of protected open space
#          cover within each 100 m pixel over the study area
#          boundary using the California Protected Areas
#          Database (CPAD).
#
#          CPAD Super Units are used rather than Holdings
#          because Super Units represent each park as a single
#          merged polygon. Holdings subdivide parks by owning
#          agency, access type, and county, which would
#          require dissolving before rasterization. Since only
#          polygon geometry is needed for proportional cover
#          calculation, Super Units are the appropriate
#          choice.
#
#          All protected areas are included regardless of
#          public access type (Open Access, Restricted, No
#          Public Access). The variable is intended to
#          represent potential green space availability for
#          wildlife.
#
#          The terra::rasterize() function with cover = TRUE
#          computes fractional coverage of CPAD polygons
#          within each 100 m cell directly, without requiring
#          an intermediate polygon intersection step.
#
# Data Access:
#          CPAD is publicly available through the California
#          Natural Resources Agency open data portal:
#            www.CALands.org
#
#          Citation: California Protected Areas Database
#          (CPAD) – www.calands.org (December 2020)
#
#          Dataset notes:
#            - Version: 2020b (released January 2021)
#            - Layer used: Super Units
#            - Covers all fee-owned protected open space
#              lands in California
#            - Published by GreenInfo Network
#
# NA conventions:
#          NA cells within the study boundary represent
#          areas with no CPAD polygons present, which is a
#          true zero (no protected open space). These are
#          set to 0 for MaxEnt input.
#
# Inputs:  - CPAD Super Units shapefile (statewide)
#          - Study area boundary shapefile
#
# Output:  - open_space_proportion_100m.tif
#            Proportion of protected open space cover per
#            100 m cell. Range: 0 (no open space) to 1
#            (full open space cover).
#            CRS: EPSG:26911 (UTM Zone 11N)
#
# Paper:   [Full citation or "In review, Journal of Urban Ecosystems"]
# =============================================================


# =============================================================
# SETUP
# =============================================================

library(terra)


# =============================================================
# CONFIGURATION — update file paths before running
# =============================================================

# Path to CPAD Super Units shapefile (statewide)
# Download from: www.CALands.org
CPAD_PATH <- "path/to/CPAD_2020b_SuperUnits.shp"

# Path to study area boundary shapefile
BOUNDARY_PATH <- "path/to/your_study_boundary.shp"

# Output directory
OUTPUT_DIR <- "outputs/open_space"

# Output grid resolution (meters)
GRID_RES <- 100

# Create output directory if it does not exist
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)


# =============================================================
# LOAD DATA
# =============================================================

cpad_ca  <- vect(CPAD_PATH)
boundary <- vect(BOUNDARY_PATH)

# Verify CRS of both layers
cat("CPAD CRS:\n")
crs(cpad_ca, describe = TRUE)
cat("Boundary CRS:\n")
crs(boundary, describe = TRUE)


# =============================================================
# REPROJECT CPAD TO MATCH BOUNDARY CRS
# =============================================================

# UTM Zone 11N (EPSG:26911) used here because area
# calculations require a projected CRS with linear units
# (meters). Outputs are later reprojected to WGS 84
# (EPSG:4326) for use as MaxEnt environmental predictors
# (see Banta Lab preprocessing scripts).
if (!same.crs(cpad_ca, boundary)) {
  cpad_ca <- project(cpad_ca, crs(boundary))
}

# QA: confirm CRS match after reprojection
cat("CPAD CRS after reprojection:\n")
crs(cpad_ca, describe = TRUE)


# =============================================================
# CLIP CPAD TO STUDY BOUNDARY
# =============================================================

# Intersect CPAD with study boundary to retain only
# protected areas within the study area
cpad_clipped <- terra::intersect(cpad_ca, boundary)

# Fix any geometry issues that may arise from intersection
cpad_clipped <- makeValid(cpad_clipped)

# QA: confirm output is a valid SpatVector
stopifnot(inherits(cpad_clipped, "SpatVector"))
cat("CPAD features within study boundary:",
    nrow(cpad_clipped), "\n")


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
  crs        = crs(boundary)
)

# QA: verify resolution and CRS
cat("Template resolution (expect 100 100):", res(r_template), "\n")
cat("Template CRS:\n")
crs(r_template, describe = TRUE)


# =============================================================
# RASTERIZE CPAD POLYGONS
# =============================================================

# Compute fractional open space coverage per 100 m cell.
# cover = TRUE calculates the proportion of each cell's area
# covered by CPAD polygons (range: 0-1).
cpad_prop <- rasterize(
  cpad_clipped,
  r_template,
  field = 1,
  cover = TRUE
)


# =============================================================
# MASK TO STUDY BOUNDARY & HANDLE NA VALUES
# =============================================================

# Mask to study area boundary
cpad_prop <- mask(cpad_prop, boundary)

# Set NA cells within the boundary to 0.
# NA values represent cells with no CPAD polygons present,
# which is a true zero (no protected open space), not
# missing data.
cpad_prop[is.na(cpad_prop)] <- 0


# =============================================================
# QA
# =============================================================

# Value range check — should be 0 to 1
cat("Open space proportion range:\n")
global(cpad_prop, range, na.rm = TRUE)

# Cell count check
cat("Total non-NA cells:",
    global(!is.na(cpad_prop), "sum")[[1]], "\n")


# =============================================================
# EXPORT
# =============================================================

writeRaster(
  cpad_prop,
  file.path(OUTPUT_DIR, "open_space_proportion_100m.tif"),
  overwrite = TRUE
)

cat("Output written to:", OUTPUT_DIR, "\n")
