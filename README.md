# PPR Pond Mapper

The PPR Pond Mapper is an open-source tool for **monitoring surface water within wetlands** across the United States portion of the Prairie Pothole Region (PPR). Developed in collaboration with the Prairie Pothole Joint Venture, Ducks Unlimited, and the U.S. Fish and Wildlife Service, this tool supports conservation and research efforts by providing consistent, spatially explicit wetland inundation data.

----

## How it works: 
We trained a random forest model on thousands of aerial images, captured by the US Fish & Widlife's Habitate and Population Evaluation Team ("HAPET") over 680 4mi^2 plots and 9 survey periods between 2016-2024. These images have a 1.5m resolution and are digitized by HAPET into surface water polygons. 

### Wetland Footprint Preparation
We first define areas with historical evidence of wetlands — our area of interest — using multiple sources:
    * The National Wetland Inventory (NWI)
    * JRC Global Surface Water Maximum Water Extent
    * HAPET surveys
    * SSURGO hydric soils  
    * Excluding Census roads


<p align="center">
  <img src="code/images/WetlandFootprint.png" alt="Wetland footprint sources" width="800" />
</p>
<p align="center"><em>Wetland footprint sources (white areas indicate wetland evidence).</em></p>

These sources are combined in Google Earth Engine to generate a wetland footprint mask.

<p align="center">
  <img src="code/images/5.dryROI.png" alt="Historic Wetland Footprint of a Plot" width="400">
</p>
<p align="center"><em>Historic wetland footprint of a plot.</em></p>

### Sampling Strategy (R scripts 1-7)

For each plot-survey:
    * We remove all ponds <400m<sup>2</sup>, which are below our minimum target unit (for reference, HAPET's MTU is 800m<sup>2</sup>). 
    * We then sample 200 inundated points by iterating through ponds, randomly selecting one point per pond until 200 points are collected. Points must be:
        * $\geq$ 7.5m from pond edges, to avoid mixed pixels.
        * $\geq$ 20m apart, to avoid duplicate pixels. 
    * For dry points, we randomly select 200 points outside of ponds, but within the historical wetland footprint. Again, points must be $\geq$ 7.5m from pond edges. 
  
### Predictor Extraction
In Google Earth Engine, we extract predictors to each sampled point:
    * **Sentinel-1** C-band SAR: We apply border noise correction, speckle filtering, and radiometric terrain normalization via an [open-source script](https://github.com/adugnag/gee_s1_ard).
    * **Sentinel-2** We mask pixels occluded by clouds or cloud-shadow using a [CS+](https://developers.google.com/earth-engine/datasets/catalog/GOOGLE_CLOUD_SCORE_PLUS_V1_S2_HARMONIZED) threshold of 0.6. L1C images (2016-2017)are atmospherically corrected via an [open-source script](https://github.com/MarcYin/SIAC_GEE). 
    * **Topographic depression indicies** at 30m and 90m resolution ([source](https://gee-community-catalog.org/projects/hand/))
    * **Drought indices** from GridMET ([source](https://developers.google.com/earth-engine/datasets/catalog/GRIDMET_DROUGHT))

### Model Train/Test Design
R scripts 8-12 determine the training and testing sets
    * We decided to hold out data from August 2016, May 2022, and May 2024 for testing. These out-of-time test sets capture a variety of climatic conditions...
    * We hold out out-of-space test sets...
    * Within the training data, we enforce even sampling across time and a hexagonal spatial grid (51 equal-area cells, weighted by PPR coverage). Each cell-survey includes 300 wet and 300 dry points, yielding over 100,000 training samples.

### Model Selection
    * From the Sentinel-2 data, we calculate 35 spectral indicies known to be useful for detecting water
    * We use recursive feature elimination with random forests, guided by spatial and temporal cross-validation, to select a reduced and uncorrelated feature set. 
    * Random forest hyperparameters are tuned on the reduced feature set using the training data.
  

## How to use
In GEE, select the area and timespan of interest. Click run, and then begin download. Can take hours...
  
