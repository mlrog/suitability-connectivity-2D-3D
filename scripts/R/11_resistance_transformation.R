# =============================================================
# Habitat Suitability to Resistance Surface Transformation
# =============================================================
# Purpose: Converts MaxEnt cloglog habitat suitability outputs
#          (0–1) to resistance surfaces for use in Omniscape
#          connectivity modeling using a linear inverse
#          transformation:
#
#            R = 1 + (1 - H) * (R_max - 1)
#
#          where R is resistance, H is habitat suitability,
#          and R_max is the maximum resistance value.
#
#
# Inputs:  MaxEnt cloglog output rasters (.asc) for:
#            - 2D Western Bluebird (Sialia mexicana) model
#            - 3D Western Bluebird (Sialia mexicana) model
#            - 2D Acorn Woodpecker (Melanerpes formicivorus) model
#            - 3D Acorn Woodpecker (Melanerpes formicivorus) model
#
# Outputs: For each model — one GeoTIFF:
#            - *_resistance.tif  (resistance surface for
#                                 Omniscape input)
#
# Paper:   [Full citation or "In review, Journal of Urban Ecosystems"]
# =============================================================


# =============================================================
# SETUP
# =============================================================

library(terra)

# Maximum resistance value 
R_MAX <- 100


# =============================================================
# FUNCTION: SUITABILITY TO RESISTANCE
# =============================================================

# Applies the linear inverse transformation to a suitability
# raster and writes the resistance raster to disk.
#
# Arguments:
#   input_file  : path to MaxEnt cloglog .asc output (0-1)
#   output_stem : file path stem for output (no extension)
#                 e.g. "outputs/2D_bluebird" will produce:
#                      "outputs/2D_bluebird_resistance.tif"
#   r_max       : maximum resistance value (default: R_MAX)

suitability_to_resistance <- function(input_file,
                                      output_stem,
                                      r_max = R_MAX) {
  
  # Load MaxEnt cloglog habitat suitability raster (range: 0-1)
  # The cloglog output approximates probability of presence and
  # is already appropriately scaled for the resistance
  # transformation without further modification.
  hs <- rast(input_file)
  
  # Apply linear inverse transformation:
  # high suitability → low resistance; low suitability → high resistance
  resistance <- 1 + (1 - hs) * (r_max - 1)
  
  # Write resistance surface to disk
  writeRaster(resistance,
              paste0(output_stem, "_resistance.tif"),
              overwrite = TRUE)
  
  # QA: print range of suitability and resistance values
  cat("\n---", basename(output_stem), "---\n")
  cat("Suitability range:\n")
  print(global(hs, c("min", "max", "mean"), na.rm = TRUE))
  cat("Resistance range:\n")
  print(global(resistance, c("min", "max", "mean"), na.rm = TRUE))
  
  # Visual check
  plot(resistance, main = paste("Resistance:", basename(output_stem)))
}


# =============================================================
# CONFIGURATION — update file paths before running
# =============================================================

# Input: MaxEnt cloglog .asc output files
# Replace these paths with the locations of your MaxEnt outputs

inputs <- list(
  # Western Bluebird (Sialia mexicana)
  "2D_bluebird"   = "path/to/2D_bluebird_maxent_output.asc",
  "3D_bluebird"   = "path/to/3D_bluebird_maxent_output.asc",
  
  # Acorn Woodpecker (Melanerpes formicivorus)
  "2D_woodpecker" = "path/to/2D_woodpecker_maxent_output.asc",
  "3D_woodpecker" = "path/to/3D_woodpecker_maxent_output.asc"
)

# Output directory for resistance rasters
# Update this path to your desired output location
OUTPUT_DIR <- "outputs/resistance"

# Create output directory if it does not exist
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)


# =============================================================
# RUN TRANSFORMATION FOR ALL MODELS
# =============================================================

for (model_name in names(inputs)) {
  suitability_to_resistance(
    input_file  = inputs[[model_name]],
    output_stem = file.path(OUTPUT_DIR, model_name)
  )
}
