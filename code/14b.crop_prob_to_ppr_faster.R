library(terra)
library(here)
library(dplyr)
library(sf)

# set time period (for filenames)
period <- "May22"

# this file reads in the gee exports, then clips and trims to PPR, and finally
# exports to the "trimmed" folder

# read in ppr boundary
ppr <- st_read(here("data", "boundaries", "PPJV")) %>% st_transform(32614)

# folder path to classifiedImage_mmyy
input_path <- here(paste0("data/gee_exports/predicted_rasters/raw/probabilities/probClassified_", period))
output_path <- here(paste0("data/gee_exports/predicted_rasters/trimmed/probabilities/probClassified_", period))

# get filenames of all tif tiles
tif_files <- list.files(path = input_path, pattern = "\\.tif$", full.names = TRUE)

# create corresponding output filenames
output_files <- file.path(output_path, basename(tif_files))

###############################################################################
# Read in all tif files as a list of SpatRaster objects
tif_list <- lapply(tif_files, terra::rast)

library(terra)
library(fasterRaster)
library(rgrass)

faster(grassDir = "/usr/lib/grass78")

madElev <- fastData("madElev") # example SpatRaster
elev <- fast(madElev)

tif_list <- lapply(tif_list, fasterRaster::fast)

# Combine into a single mosaic
mosaic_raster <- do.call(terra::mosaic, c(tif_list))
fast(tif_list[[1]])

# mask and trim
mosaic_raster_trimmed <- mosaic_raster %>%
  mask(ppr) %>%
  trim()

# save
writeRaster(mosaic_raster, 
            filename = paste0(output_path, "/", period, ".tif"), 
            overwrite = TRUE,
            gdal=c("COMPRESS=DEFLATE", "TFW=YES"))

###############################################################################

# calculate % pixels by each class
# freq(mosaic_raster)

# 4,802,448,358 pixels total (75% are nonwetland)
