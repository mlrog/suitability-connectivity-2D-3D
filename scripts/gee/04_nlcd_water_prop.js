// =============================================================
// NLCD 2021 Open Water — Proportion at 100 m
// =============================================================
// Purpose: Calculates the proportion of NLCD class 11
//          (Open Water) within each 100 m pixel
//          over the study area boundary.
//
// Inputs:
//   - User-supplied boundary asset (see CONFIGURATION below)
//   - NLCD 2021 land cover (USGS GEE ImageCollection)
//
// Output:
//   - GeoTIFF exported to Google Drive:
//     NLCD2021_OpenWater_Prop_100m_LA_UTM11.tif
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

// NLCD class to analyze (11 = Open Water)
var NLCD_CLASS = 11;

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

// Load the 2021 NLCD land cover layer from the USGS collection
var nlcd2021 = ee.ImageCollection('USGS/NLCD_RELEASES/2021_REL/NLCD')
  .filter(ee.Filter.eq('system:index', '2021'))
  .first()
  .select('landcover');

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
// This is used as the basis for all class area calculations.
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
// OPEN WATER PROPORTION (NLCD CLASS 11)
// =============================================================

// Create a binary mask: 1 where NLCD == class 11, else 0
var waterBinary = nlcdReprojected.eq(NLCD_CLASS)
  .rename('water')
  .clip(studyBoundary);

// Multiply binary mask by pixel area to get m² of class 11
// within each 30 m cell
var waterArea = waterBinary.multiply(pixelArea);

// Aggregate class 11 area to 100 m (numerator)
var waterArea100m = waterArea.reduceResolution({
  reducer: ee.Reducer.sum(),
  maxPixels: 4096
});

// Calculate proportion: class 11 area / total cell area
// Output range: 0 (none) to 1 (entirely open water)
var waterProp100m = waterArea100m
  .divide(totalArea100m)
  .rename('water_prop_100m')
  .reproject({ crs: studyProj, scale: OUTPUT_SCALE });


// =============================================================
// MAP DISPLAY
// =============================================================

Map.centerObject(studyBoundary, 10);

// Primary output layer
Map.addLayer(
  waterProp100m,
  { min: 0, max: 1, palette: ['white', 'blue'] },
  'Open Water proportion (100 m)'
);


// =============================================================
// QA / VALIDATION
// NOTE: These layers and charts are for visual validation only.
//       They are not required for the export and can be
//       commented out after the output has been verified.
// =============================================================

// (A) Range check — values should fall between 0 and 1
var rangeCheck = waterProp100m.reduceRegion({
  reducer: ee.Reducer.minMax(),
  geometry: studyBoundary.geometry(),
  scale: OUTPUT_SCALE,
  maxPixels: 1e13
});
print('QA — Open Water proportion range (expect 0–1):', rangeCheck);

// (B) Side-by-side visual: 30 m source vs 100 m output
Map.addLayer(
  nlcdReprojected.eq(NLCD_CLASS).clip(studyBoundary),
  { min: 0, max: 1, palette: ['white', 'blue'] },
  'QA — NLCD Class 11 binary (30 m)'
);

Map.addLayer(
  waterProp100m,
  { min: 0, max: 1, palette: ['white', 'blue'] },
  'QA — Open Water proportion (100 m)'
);

// (C) Full NLCD 2021 land cover for spatial context
// Standard USGS color palette — class values 11 through 95
var nlcdPalette = [
  '466b9f', // 11 Open Water
  'd1def8', // 12 Perennial Ice/Snow
  'dec5c5', // 21 Developed, Open Space
  'd99282', // 22 Developed, Low Intensity
  'eb0000', // 23 Developed, Medium Intensity
  'ab0000', // 24 Developed, High Intensity
  'b3ac9f', // 31 Barren
  '68ab5f', // 41 Deciduous Forest
  '1c5f2c', // 42 Evergreen Forest
  'b5c58f', // 43 Mixed Forest
  'af963c', // 52 Shrub/Scrub
  'ccb879', // 71 Grassland/Herbaceous
  'dfdfc2', // 81 Pasture/Hay
  'd1d182', // 82 Cultivated Crops
  'a3cc51', // 90 Woody Wetlands
  '82ba9e'  // 95 Emergent Herbaceous Wetlands
];

Map.addLayer(
  nlcdReprojected.clip(studyBoundary),
  { min: 11, max: 95, palette: nlcdPalette },
  'QA — NLCD 2021 full land cover (30 m)'
);


// =============================================================
// EXPORT TO GOOGLE DRIVE
// =============================================================

Export.image.toDrive({
  image: waterProp100m,
  description: 'NLCD2021_OpenWater_Prop_100m_LA_UTM11',
  folder: EXPORT_FOLDER,
  region: studyBoundary.geometry(),
  scale: OUTPUT_SCALE,
  crs: EXPORT_CRS,
  maxPixels: 1e13
});
