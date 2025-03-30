library(terra)
library(here)

# folder path to classifiedImage22 
# ("here" is a fancy package... you can just put the full filepath in quotes)
folder_path <- here("data/gee_exports/predicted_rasters/classifiedImage22")

# get filenames of all 32 tif tiles in a list
tif_files <- list.files(path = folder_path, pattern = "\\.tif$", full.names = TRUE)

# Read each tif into a list of raster objects
raster_list <- lapply(tif_files, function(file) {
  print(file)
  return(rast(file))
})

rast <- raster_list[[3]]
summary(rast)

# Stack rasters into one raster object
raster_stack <- stack(raster_list)

# Combine rasters into one by averaging (or any other operation)
combined_raster <- calc(raster_stack, fun = mean)  # This combines by averaging


