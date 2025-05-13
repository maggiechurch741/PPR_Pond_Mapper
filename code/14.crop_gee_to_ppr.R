library(terra)
library(here)
library(dplyr)
library(sf)

# set time period (for filenames)
period <- "fullAug17"

# this file reads in the gee exports, then clips and trims to PPR, and finally
# exports to the "trimmed" folder

# read in ppr boundary
ppr <- st_read(here("data", "boundaries", "PPJV")) %>% st_transform(32614)

# folder path to classifiedImage_mmyy
input_path <- here(paste0("data/gee_exports/predicted_rasters/raw/binary/classifiedImage_", period))
output_path <- here(paste0("data/gee_exports/predicted_rasters/trimmed/binary/classifiedImage_", period))

# get filenames of all tif tiles
tif_files <- list.files(path = input_path, pattern = "\\.tif$", full.names = TRUE)

# create corresponding output filenames
output_files <- file.path(output_path, basename(tif_files))

# read, mask, trim, and save to new folder
for (i in seq_along(tif_files)) {
  
  # print progress
  cat("Processing:", tif_files[i], "\n")
  
  # read
  r <- rast(tif_files[i])
  
  # mask and trim
  trimmed <- r %>%
    mask(ppr) %>%
    trim()
  
  # save
  writeRaster(trimmed, filename = output_files[i], overwrite = TRUE,
              gdal=c("COMPRESS=DEFLATE", "TFW=YES"))
}

# read trimmed files back in
tif_files <- list.files(output_path, pattern = "\\.tif$", full.names = TRUE)
raster_list <- lapply(tif_files, rast)

# Combine into a single mosaic
mosaic_raster <- do.call(mosaic, raster_list)

# save
writeRaster(mosaic_raster, 
            filename = paste0(output_path, "/", period, ".tif"), 
            overwrite = TRUE,
            gdal=c("COMPRESS=DEFLATE", "TFW=YES"))

# calculate % pixels by each class
# freq(mosaic_raster)

# 4,802,448,358 pixels total (75% are nonwetland)
