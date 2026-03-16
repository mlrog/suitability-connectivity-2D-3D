# =============================================================
# Hellinger-Based Niche Similarity Analysis
# =============================================================
# Purpose: Quantifies niche similarity between 2D and 3D
#          MaxEnt habitat suitability models for each species
#          using the Hellinger-based similarity statistic I
#          (Warren et al. 2008).
#
#          I ranges from 0 (no overlap) to 1 (identical
#          distributions). Four comparisons are computed:
#            - Bluebird:   2D vs 3D
#            - Woodpecker: 2D vs 3D
#
#          The statistic is computed by normalizing each
#          cloglog suitability raster to a probability
#          distribution, then applying the Hellinger distance
#          formula. Only cells with valid values in both
#          rasters are included (intersection of support).
#
# Reference:
#          Warren, D. L., Glor, R. E., & Turelli, M. (2008).
#          Environmental niche equivalency versus conservatism:
#          quantitative approaches to niche evolution. Evolution,
#          62(11), 2868-2883. https://doi.org/10.1111/j.1558-5646.2008.00482.x
#
# Inputs:  Four MaxEnt cloglog output rasters (.asc):
#            - 2D bluebird
#            - 3D bluebird
#            - 2D woodpecker
#            - 3D woodpecker
#
# Outputs: - hellinger_within_species_2D_vs_3D.csv
#
# Paper:   [Full citation or "In review, Journal of Urban Ecosystems"]
# =============================================================


# =============================================================
# SETUP
# =============================================================

library(terra)
library(dplyr)
library(purrr)
library(tidyr)


# =============================================================
# CONFIGURATION — update file paths before running
# =============================================================

# Directory containing MaxEnt cloglog output rasters (.asc)
RASTER_DIR <- "path/to/your/maxent/outputs"

# Output directory for results
OUTPUT_DIR <- "outputs/hellinger"

# Create output directory if it does not exist
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)


# =============================================================
# HELLINGER SIMILARITY FUNCTION
# =============================================================

# Computes Hellinger-based niche similarity (I) between two
# suitability rasters following Warren et al. (2008).
#
# Arguments:
#   file_x : path to first suitability raster
#   file_y : path to second suitability raster
#
# Returns:
#   I : similarity statistic (0 = no overlap, 1 = identical)

hellinger_from_files <- function(file_x, file_y) {
  
  r_x <- rast(file_x)
  r_y <- rast(file_y)
  
  # Verify identical geometry before proceeding
  stopifnot(compareGeom(r_x, r_y, stopOnError = FALSE))
  
  # Enforce shared NA structure (intersection of support).
  # Only cells with valid values in both rasters contribute
  # to the similarity calculation.
  r_x[is.na(r_y)] <- NA
  r_y[is.na(r_x)] <- NA
  
  # Normalize to probability distributions (Warren et al. 2008)
  p_x <- r_x / global(r_x, "sum", na.rm = TRUE)[1, 1]
  p_y <- r_y / global(r_y, "sum", na.rm = TRUE)[1, 1]
  
  # Extract aligned non-NA values
  x_vals <- values(p_x, na.rm = TRUE)
  y_vals <- values(p_y, na.rm = TRUE)
  
  stopifnot(length(x_vals) == length(y_vals))
  
  # Hellinger distance and similarity statistic I
  H <- sqrt(sum((sqrt(x_vals) - sqrt(y_vals))^2))
  I <- 1 - 0.5 * H
  
  return(I)
}


# =============================================================
# LOAD RASTERS AND PARSE METADATA
# =============================================================

raster_files <- list.files(
  RASTER_DIR,
  pattern   = "\\.asc$",
  full.names = TRUE
)

# Parse species and model type from filenames.
# Expects filenames beginning with "2D_" or "3D_" and
# containing "blue" or "wood" (case-insensitive).
models <- tibble(
  file = raster_files,
  name = basename(raster_files)
) %>%
  mutate(
    model = case_when(
      grepl("^2D_", name)               ~ "2D",
      grepl("^3D_", name)               ~ "3D",
      TRUE                               ~ NA_character_
    ),
    species = case_when(
      grepl("blue", name, ignore.case = TRUE) ~ "bluebird",
      grepl("wood", name, ignore.case = TRUE) ~ "woodpecker",
      TRUE                                     ~ NA_character_
    )
  )

# QA: verify all four files are correctly parsed.
# Expect 4 rows with no NA values in species or model.
cat("Parsed raster metadata:\n")
print(models %>% select(name, species, model))

stopifnot(
  nrow(models) == 4,
  !any(is.na(models$species)),
  !any(is.na(models$model))
)


# =============================================================
# WITHIN-SPECIES 2D VS 3D COMPARISONS
# =============================================================
# Compute Hellinger I for each species comparing the 2D and
# 3D MaxEnt cloglog outputs. Four files produce two
# comparisons: one per species.

results <- models %>%
  group_by(species) %>%
  summarise(
    file_2D = file[model == "2D"],
    file_3D = file[model == "3D"],
    .groups = "drop"
  ) %>%
  mutate(
    hellinger_I = map2_dbl(file_2D, file_3D, hellinger_from_files)
  )

cat("\nWithin-species 2D vs 3D Hellinger similarity:\n")
print(results %>% select(species, hellinger_I))


# =============================================================
# QA: SYMMETRY CHECK
# =============================================================
# Hellinger I is mathematically symmetric: I(x, y) = I(y, x).
# This check verifies the implementation by confirming that
# reversing the comparison order gives identical results.

results_reversed <- results %>%
  mutate(
    hellinger_I_reversed = map2_dbl(file_3D, file_2D,
                                    hellinger_from_files),
    symmetric = abs(hellinger_I - hellinger_I_reversed) < 1e-10
  )

cat("\nSymmetry check (expect TRUE for all species):\n")
print(results_reversed %>% select(species, hellinger_I,
                                  hellinger_I_reversed, symmetric))

stopifnot(all(results_reversed$symmetric))


# =============================================================
# EXPORT
# =============================================================

output <- results %>%
  select(species, hellinger_I)

write.csv(
  output,
  file.path(OUTPUT_DIR, "hellinger_within_species_2D_vs_3D.csv"),
  row.names = FALSE
)

cat("\nOutput written to:", OUTPUT_DIR, "\n")
