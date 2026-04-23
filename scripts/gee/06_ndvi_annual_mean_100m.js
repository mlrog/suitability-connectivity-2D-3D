// =============================================================
// Sentinel-2 Annual Mean NDVI — 100 m (2022)
// =============================================================
// Purpose: Calculates mean annual NDVI from Sentinel-2 SR
//          imagery for 2022, aggregated to 100 m resolution
//          over the study area boundary.
//
//          All available cloud-masked Sentinel-2 scenes for 2022
//          are composited to a per-pixel annual mean at native
//          10 m resolution, then aggregated to 100 m using a
//          mean reducer.
//
// Inputs:
//   - User-supplied boundary asset (see CONFIGURATION below)
//   - Sentinel-2 SR Harmonized (COPERNICUS/S2_SR_HARMONIZED)
//     Bands used: B4 (Red, 10 m), B8 (NIR, 10 m)
//
// Output:
//   - GeoTIFF exported to Google Drive:
//     NDVI_100m_AnnualMean_2022_LA_UTM11.tif
//     Resolution: 100 m | CRS: EPSG:26911 (UTM Zone 11N)
//
// NOTE: This script is written for the Google Earth Engine (GEE)
//       Code Editor (code.earthengine.google.com) and is not
//       intended to be run as a standalone Node.js script.
//
// Paper:   Rogers, M. L., Frazier, A. E., Zellmer, A. J., & 
//          Lerman, S. B. (2026). Sensitivity of habitat 
//          suitability-derived connectivity models to 
//          three-dimensional measures of urban landscape structure. 
//          Urban Ecosystems, 29(3), 121. 
//          https://doi.org/10.1007/s11252-026-01948-y
// =============================================================


// =============================================================
// CONFIGURATION — edit these variables before running
// =============================================================

// Path to your study area boundary asset in GEE.
// Replace with your own asset path:
// e.g. 'projects/your-project-id/assets/your-boundary-name'
var BOUNDARY_ASSET = 'projects/YOUR_PROJECT_ID/assets/YOUR_BOUNDARY_ASSET';

// Year to process
var YEAR = '2022';

// Date range (full calendar year)
var DATE_START = YEAR + '-01-01';
var DATE_END   = YEAR + '-12-31';

// Native Sentinel-2 resolution for Red/NIR bands (meters)
var S2_SCALE = 10;

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
// STUDY AREA
// =============================================================

var studyBoundary = ee.FeatureCollection(BOUNDARY_ASSET);


// =============================================================
// CLOUD MASKING FUNCTION
// =============================================================

// Masks clouds, cloud shadows, cirrus, and snow/ice using the
// Sentinel-2 Scene Classification Layer (SCL band).
// SCL class values masked:
//   3  = cloud shadow
//   7  = cloud (low probability)
//   8  = cloud (medium probability)
//   9  = cloud (high probability)
//   10 = cirrus
//   11 = snow / ice
function maskS2clouds(image) {
  var scl = image.select('SCL');
  var mask = scl.neq(3)
    .and(scl.neq(7))
    .and(scl.neq(8))
    .and(scl.neq(9))
    .and(scl.neq(10))
    .and(scl.neq(11));
  return image.updateMask(mask);
}


// =============================================================
// LOAD & FILTER SENTINEL-2
// =============================================================

// Load Sentinel-2 SR Harmonized collection, filtered to study
// area and date range, with cloud masking applied.
// Only Red (B4) and NIR (B8) bands are retained for efficiency.
var s2 = ee.ImageCollection('COPERNICUS/S2_SR_HARMONIZED')
  .filterBounds(studyBoundary)
  .filterDate(DATE_START, DATE_END)
  .map(maskS2clouds)
  .select(['B4', 'B8']);


// =============================================================
// NDVI CALCULATION
// =============================================================

// Calculate NDVI for each image in the collection.
// NDVI = (NIR - Red) / (NIR + Red), range: -1 to 1
var ndviCollection = s2.map(function(img) {
  return img.normalizedDifference(['B8', 'B4'])
    .rename('NDVI')
    .copyProperties(img, ['system:time_start']);
});

// Compute annual mean NDVI across all cloud-masked scenes.
// Clipped and reprojected to study CRS at native 10 m resolution.
// setDefaultProjection anchors the pixel grid so reduceResolution
// correctly identifies which 10 m pixels belong to each 100 m cell.
var ndviMean = ndviCollection.mean()
  .clip(studyBoundary)
  .reproject({ crs: EXPORT_CRS, scale: S2_SCALE })
  .setDefaultProjection({ crs: EXPORT_CRS, scale: S2_SCALE });


// =============================================================
// AGGREGATE TO 100 m
// =============================================================

// Aggregate mean NDVI from 10 m to 100 m using a mean reducer.
// Each 100 m output pixel represents the mean NDVI of the
// ~100 contributing 10 m pixels.
var ndvi100m = ndviMean
  .reduceResolution({
    reducer: ee.Reducer.mean(),
    maxPixels: 1024
  })
  .reproject({ crs: EXPORT_CRS, scale: OUTPUT_SCALE });


// =============================================================
// MAP DISPLAY
// =============================================================

Map.centerObject(studyBoundary, 9);

Map.addLayer(
  ndvi100m,
  { min: -0.2, max: 0.8, palette: ['brown', 'white', 'green'] },
  'NDVI annual mean 2022 (100 m)'
);


// =============================================================
// EXPORT TO GOOGLE DRIVE
// =============================================================

Export.image.toDrive({
  image: ndvi100m,
  description: 'NDVI_100m_AnnualMean_2022_LA_UTM11',
  folder: EXPORT_FOLDER,
  region: studyBoundary.geometry(),
  scale: OUTPUT_SCALE,
  crs: EXPORT_CRS,
  maxPixels: 1e13,
  fileFormat: 'GeoTIFF'
});
