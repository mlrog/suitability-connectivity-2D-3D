// =============================================================
// NLCD 2021 Impervious Surface — Proportion at 100 m
// =============================================================
// Purpose: Aggregates the NLCD 2021 percent impervious surface
//          band to a proportion (0–1) within each 100 m pixel
//          over the study area boundary.
//
//          Unlike the land cover class scripts, this variable is
//          continuous (0–100% per 30 m pixel) rather than a
//          binary class mask. The percent value is converted to
//          a fractional area before aggregation.
//
// Inputs:
//   - User-supplied boundary asset (see CONFIGURATION below)
//   - NLCD 2021 'impervious' band (USGS GEE ImageCollection)
//
// Output:
//   - GeoTIFF exported to Google Drive:
//     NLCD2021_Impervious_Prop_100m_LA_UTM11.tif
//     Resolution: 100 m | CRS: EPSG:26911 (UTM Zone 11N)
//
// NOTE: This script is written for the Google Earth Engine (GEE)
//       Code Editor (code.earthengine.google.com) and is not
//       intended to be run as a standalone Node.js script.
//
// Paper:   [Full citation or "In review, Journal of Urban Ecosystems"]
// =============================================================


// =============================================================
// CONFIGURATION — edit these variables before running
// =============================================================

// Path to your study area boundary asset in GEE.
// Replace with your own asset path:
// e.g. 'projects/your-project-id/assets/your-boundary-name'
var BOUNDARY_ASSET = 'projects/YOUR_PROJECT_ID/assets/YOUR_BOUNDARY_ASSET';

// Native NLCD resolution (meters) — do not change for NLCD 2021
var NLCD_SCALE = 30;

// Output aggregation resolution (meters)
var OUTPUT_SCALE = 100;

// UTM Zone 11N (EPSG:26911) used here because area calculations
// require a projected CRS with linear units (meters). Outputs are
// later reprojected to WGS 84 (EPSG:4326) for use as MaxEnt
// environmental predictors (see R preprocessing scripts).
var EXPORT_CRS = 'EPSG:26911';

// Google Drive folder for export (optional — leave '' to use root)
var EXPORT_FOLDER = '';


// =============================================================
// STUDY AREA & PROJECTION
// =============================================================

var studyBoundary = ee.FeatureCollection(BOUNDARY_ASSET);

// Derive projection from the boundary asset (UTM Zone 11N)
var studyProj = studyBoundary.geometry().projection();


// =============================================================
// LOAD & REPROJECT NLCD 2021
// =============================================================

// Load the full NLCD 2021 image (not just landcover band —
// the impervious band is a separate continuous variable)
var nlcd2021 = ee.ImageCollection('USGS/NLCD_RELEASES/2021_REL/NLCD')
  .filter(ee.Filter.eq('system:index', '2021'))
  .first();

// Reproject to study area CRS at native 30 m resolution.
// setDefaultProjection ensures downstream operations
// (e.g. reduceResolution) respect this grid alignment.
var nlcdReprojected = nlcd2021
  .reproject({ crs: studyProj, scale: NLCD_SCALE })
  .setDefaultProjection({ crs: studyProj, scale: NLCD_SCALE });


// =============================================================
// PIXEL AREA IMAGE
// =============================================================

// Per-pixel area in m² at 30 m resolution, clipped to boundary.
// This is used as the basis for all area calculations.
var pixelArea = ee.Image.pixelArea()
  .setDefaultProjection({ crs: studyProj, scale: NLCD_SCALE })
  .clip(studyBoundary);

// Sum pixel areas within each 100 m output cell.
// This is the denominator for proportion calculations.
var totalArea100m = pixelArea.reduceResolution({
  reducer: ee.Reducer.sum(),
  maxPixels: 4096
});


// =============================================================
// IMPERVIOUS SURFACE PROPORTION
// =============================================================

// Extract the impervious band — values represent percent
// impervious cover per 30 m pixel (range: 0–100)
var impervPct = nlcdReprojected
  .select('impervious')
  .clip(studyBoundary);

// Convert percent to fraction (0–1) so units are consistent
// with the area-weighted aggregation below
var impervFrac = impervPct.divide(100).rename('imperv_frac');

// Weight fractional imperviousness by pixel area (m²)
// This gives impervious area contributed by each 30 m pixel
var impervArea = impervFrac.multiply(pixelArea);

// Aggregate impervious area to 100 m (numerator)
var impervArea100m = impervArea.reduceResolution({
  reducer: ee.Reducer.sum(),
  maxPixels: 4096
});

// Calculate proportion: impervious area / total cell area
// Output range: 0 (no impervious surface) to 1 (fully impervious)
var impervProp100m = impervArea100m
  .divide(totalArea100m)
  .rename('imperv_prop_100m')
  .reproject({ crs: studyProj, scale: OUTPUT_SCALE });


// =============================================================
// MAP DISPLAY
// =============================================================

Map.centerObject(studyBoundary, 10);

Map.addLayer(
  impervProp100m,
  { min: 0, max: 1, palette: ['white', 'orange', 'red', 'darkred'] },
  'Impervious proportion (100 m)'
);


// =============================================================
// EXPORT TO GOOGLE DRIVE
// =============================================================

Export.image.toDrive({
  image: impervProp100m,
  description: 'NLCD2021_Impervious_Prop_100m_LA_UTM11',
  folder: EXPORT_FOLDER,
  region: studyBoundary.geometry(),
  scale: OUTPUT_SCALE,
  crs: EXPORT_CRS,
  maxPixels: 1e13
});
