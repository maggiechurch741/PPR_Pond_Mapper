
# this file reads in the gee exports (all tifs within the input_path), then clips and trims to PPR, and exports the combined/trimmed tif to the outout_path


mosaic_raster_to_ppr <- function(epsg, input_folder, output_path, datatype = "INT1U"){
  
  # read in ppr boundary
  ppr <- st_read(here("data", "boundaries", "PPJV")) |> st_transform(epsg)
  
  # get filenames of all tif tiles in the input path
  tif_files <- list.files(path = input_folder, pattern = "\\.tif$", full.names = TRUE)
  
  # Read in all tif files as a list of SpatRaster objects
  tif_list <- lapply(tif_files, terra::rast)
  
  print(tif_files)
  
  ###############################################################################
  
  # Combine into a single mosaic
  mosaic_raster <- do.call(terra::mosaic, c(tif_list))
  
  # mask and trim
  mosaic_raster_trimmed <- mosaic_raster |>
    mask(ppr) |>
    trim()
  
  # save
  writeRaster(
    mosaic_raster_trimmed, 
    filename = output_path, 
    overwrite = TRUE,
    datatype = datatype,
    gdal=c("COMPRESS=DEFLATE", "TFW=YES"))
}

merge_raster_to_ppr <- function(epsg, input_folder, output_path, datatype="INT1U"){
  
  # read in ppr boundary
  ppr <- st_read(here("data", "boundaries", "PPJV")) |> st_transform(epsg)
  
  # get filenames of all tif tiles in the input path
  tif_files <- list.files(path = input_folder, pattern = "\\.tif$", full.names = TRUE)
  
  # Read in all tif files as a list of SpatRaster objects
  tif_list <- lapply(tif_files, terra::rast)
  
  print(tif_files)
  
  ###############################################################################
  
  # merge instead of mosaic, bc tiles are non-overlapping (this is faster)
  r_collection <- sprc(tif_files)
  merged <- merge(r_collection)
  
  merged_int <- merged * 100
  merged_int <- round(merged_int) |> as.int()
  merged_int <- mask(merged_int, ppr) |> trim()
  
  # write scaled on the fly
  writeRaster(
    merged_int,
    filename = output_path,
    overwrite = TRUE,
    datatype = datatype,
    gdal=c("COMPRESS=DEFLATE", "TFW=YES")
  )
}
