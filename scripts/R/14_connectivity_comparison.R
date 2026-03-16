# =============================================================
# Connectivity Comparison — Pearson Correlation and
# Top 10% Current Flow Difference Map
# =============================================================
# Purpose: Compares 2D and 3D Omniscape cumulative current
#          flow outputs for each species using:
#
#            1. Pearson correlation — quantifies agreement
#               between 2D and 3D connectivity maps after
#               z-score standardization.
#
#            2. Top 10% current flow difference map —
#               identifies cells in the top 10th percentile
#               of raw cumulative current flow in each model
#               and computes a difference map showing where
#               the two models agree or disagree on high
#               current flow areas (Gelmi-Candusso et al.
#               2025).
#
#               Difference map values:
#                  1 = top 10% in 3D only
#                  0 = agreement (both or neither)
#                 -1 = top 10% in 2D only
#
# Inputs:  Four Omniscape cumulative current flow rasters:
#            - 2D and 3D bluebird
#            - 2D and 3D woodpecker
#
# Outputs: Per species:
#            - {species}_pearson_correlation.csv
#            - {species}_top10_difference.tif
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

FILE_2D_BLUEBIRD   <- "path/to/2D_bluebird_thin_cum_currmap.tif"
FILE_3D_BLUEBIRD   <- "path/to/3D_bluebird_thin_cum_currmap.tif"
FILE_2D_WOODPECKER <- "path/to/2D_woodpecker_thin_cum_currmap.tif"
FILE_3D_WOODPECKER <- "path/to/3D_woodpecker_thin_cum_currmap.tif"

# Output directory
OUTPUT_DIR <- "outputs/connectivity_comparison"

# Percentile threshold for top current flow cells
# 0.90 = top 10% of raw cumulative current flow values
TOP_PERCENTILE <- 0.90

# Create output directory if it does not exist
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)


# =============================================================
# CONNECTIVITY COMPARISON FUNCTION
# =============================================================

connectivity_comparison <- function(file_2d, file_3d,
                                    species, out_dir,
                                    top_percentile) {
  
  cat("\n", strrep("=", 50), "\n")
  cat("Processing:", species, "\n")
  cat(strrep("=", 50), "\n")
  
  # Load rasters
  curr_2d <- rast(file_2d)
  curr_3d <- rast(file_3d)
  
  # Verify identical geometry
  stopifnot(compareGeom(curr_2d, curr_3d, stopOnError = FALSE))
  
  # ---------------------------------------------------------
  # Enforce shared NA mask
  # ---------------------------------------------------------
  
  # Restrict analysis to cells with valid values in both
  # rasters to ensure comparison over identical spatial extent
  mask_shared <- !is.na(curr_2d) & !is.na(curr_3d)
  curr_2d     <- mask(curr_2d, mask_shared, maskvalue = FALSE)
  curr_3d     <- mask(curr_3d, mask_shared, maskvalue = FALSE)
  
  # ---------------------------------------------------------
  # Pearson correlation on z-scored values
  # ---------------------------------------------------------
  
  # Extract paired non-NA values
  vals <- cbind(values(curr_2d), values(curr_3d))
  vals <- vals[complete.cases(vals), ]
  colnames(vals) <- c("curr_2d", "curr_3d")
  
  # Z-score standardization makes 2D and 3D outputs
  # comparable regardless of differences in absolute
  # current flow values between model runs
  vals_z <- apply(vals, 2, scale)
  
  pearson_r <- cor(vals_z[, 1], vals_z[, 2],
                   method = "pearson")
  pearson_p <- cor.test(vals_z[, 1], vals_z[, 2])$p.value
  
  cat("Pearson r:", round(pearson_r, 6), "\n")
  cat("p-value:  ", format(pearson_p, scientific = TRUE), "\n")
  
  # Save correlation results
  write.csv(
    data.frame(
      species   = species,
      pearson_r = pearson_r,
      p_value   = pearson_p
    ),
    file.path(out_dir,
              paste0(species, "_pearson_correlation.csv")),
    row.names = FALSE
  )
  
  # ---------------------------------------------------------
  # Top 10% current flow difference map
  # ---------------------------------------------------------
  
  # Threshold computed from raw cumulative current flow values.
  # The 90th percentile is computed independently for each model
  # High current flow areas are identified as cells in the
  # top 10th percentile of cumulative current flow following
  # Gelmi-Candusso et al. (2025).
  thr_2d <- quantile(vals[, 1], probs = top_percentile,
                     na.rm = TRUE)
  thr_3d <- quantile(vals[, 2], probs = top_percentile,
                     na.rm = TRUE)
  
  cat("2D threshold (", top_percentile * 100,
      "th percentile):", round(thr_2d, 4), "\n")
  cat("3D threshold (", top_percentile * 100,
      "th percentile):", round(thr_3d, 4), "\n")
  
  # Binary rasters: 1 = top 10% current flow, 0 = below
  top_2d <- curr_2d >= thr_2d
  top_3d <- curr_3d >= thr_3d
  
  # QA: confirm expected cell counts (~10% of valid cells)
  n_valid  <- sum(complete.cases(vals))
  n_top_2d <- global(top_2d, "sum", na.rm = TRUE)[[1]]
  n_top_3d <- global(top_3d, "sum", na.rm = TRUE)[[1]]
  cat("Top 10% cells — 2D:", n_top_2d,
      "(", round(n_top_2d / n_valid * 100, 1), "% )\n")
  cat("Top 10% cells — 3D:", n_top_3d,
      "(", round(n_top_3d / n_valid * 100, 1), "% )\n")
  
  # Difference map:
  #   1 = top 10% in 3D only
  #   0 = agreement (both or neither in top 10%)
  #  -1 = top 10% in 2D only
  diff_top <- top_3d - top_2d
  
  # QA: confirm only expected values present
  cat("Difference map values (expect -1, 0, 1 only):\n")
  print(table(values(diff_top), useNA = "ifany"))
  
  # Save difference raster
  writeRaster(
    diff_top,
    file.path(out_dir,
              paste0(species, "_top10_difference.tif")),
    overwrite = TRUE
  )
  
  cat("Outputs written for:", species, "\n")
}


# =============================================================
# RUN COMPARISONS
# =============================================================

connectivity_comparison(
  file_2d        = FILE_2D_BLUEBIRD,
  file_3d        = FILE_3D_BLUEBIRD,
  species        = "bluebird",
  out_dir        = OUTPUT_DIR,
  top_percentile = TOP_PERCENTILE
)

connectivity_comparison(
  file_2d        = FILE_2D_WOODPECKER,
  file_3d        = FILE_3D_WOODPECKER,
  species        = "woodpecker",
  out_dir        = OUTPUT_DIR,
  top_percentile = TOP_PERCENTILE
)


# =============================================================
# COMBINE PEARSON RESULTS
# =============================================================

pearson_files <- list.files(
  OUTPUT_DIR,
  pattern    = "_pearson_correlation.csv",
  full.names = TRUE
)

pearson_combined <- bind_rows(lapply(pearson_files, read.csv))

cat("\nPearson correlation summary:\n")
print(pearson_combined)

write.csv(
  pearson_combined,
  file.path(OUTPUT_DIR, "pearson_correlation_all_species.csv"),
  row.names = FALSE
)

cat("\nAll outputs written to:", OUTPUT_DIR, "\n")
