# =============================================================
# Spearman Rank Correlation — 2D vs 3D SDM Comparison
# =============================================================
# Purpose: Computes Spearman rank correlation between 2D and
#          3D MaxEnt habitat suitability models for each
#          species. The correlation quantifies rank-order
#          agreement between the two models across all cells.
#
# Inputs:  Four MaxEnt cloglog output rasters (.asc):
#            - 2D and 3D bluebird
#            - 2D and 3D woodpecker
#
# Outputs: - spearman_correlation_all_species.csv
#
# Paper:   [Full citation or "In review, Journal of Urban Ecosystems"]
# =============================================================


# =============================================================
# SETUP
# =============================================================

library(terra)
library(dplyr)


# =============================================================
# CONFIGURATION — update file paths before running
# =============================================================

FILE_2D_BLUEBIRD   <- "path/to/2D_bluebird.asc"
FILE_3D_BLUEBIRD   <- "path/to/3D_bluebird.asc"
FILE_2D_WOODPECKER <- "path/to/2D_woodpecker.asc"
FILE_3D_WOODPECKER <- "path/to/3D_woodpecker.asc"

OUTPUT_DIR <- "outputs/sdm_comparison"
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)


# =============================================================
# COMPUTE SPEARMAN CORRELATION
# =============================================================

spearman_correlation <- function(file_2d, file_3d, species) {
  
  r2d <- rast(file_2d)
  r3d <- rast(file_3d)
  
  stopifnot(compareGeom(r2d, r3d, stopOnError = FALSE))
  
  # Extract non-NA values from both rasters
  vals <- cbind(values(r2d), values(r3d))
  vals <- na.omit(vals)
  colnames(vals) <- c("pred2D", "pred3D")
  
  spearman_r <- cor(vals[, 1], vals[, 2], method = "spearman")
  
  cat(species, "Spearman r:", round(spearman_r, 6), "\n")
  
  data.frame(species = species, spearman_r = spearman_r)
}


# =============================================================
# RUN & EXPORT
# =============================================================

results <- bind_rows(
  spearman_correlation(FILE_2D_BLUEBIRD,   FILE_3D_BLUEBIRD,   "bluebird"),
  spearman_correlation(FILE_2D_WOODPECKER, FILE_3D_WOODPECKER, "woodpecker")
)

print(results)

write.csv(
  results,
  file.path(OUTPUT_DIR, "spearman_correlation_all_species.csv"),
  row.names = FALSE
)

cat("\nOutput written to:", OUTPUT_DIR, "\n")
