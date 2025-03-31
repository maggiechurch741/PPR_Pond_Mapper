library(terra)
library(here)
library(dplyr)
library(sf)
library(mapview)

ppr <- st_read(here("data", "boundaries", "PPJV")) %>% st_transform(4326)
plots <- st_read(here("data", "allPlots")) 
ponds <- st_read(here("data", "allPonds")) %>% st_transform(4326)

# folder path to classifiedImage_May22
folder_path <- here("data/gee_exports/predicted_rasters/classifiedImage24")
dataset <- "2024"

# get filenames of all 32 tif tiles
tif_files <- list.files(path = folder_path, pattern = "\\.tif$", full.names = TRUE)

# read each tif into a list of raster objects
raster_list <- lapply(tif_files, function(file){
  print(file)
  r <- rast(file) 
  return(r)
})

#############################

# stack rasters into 1 multi-layer raster object
# raster_merged <- do.call(merge, raster_list)
  
#############################
  options(sf_use_s2 = TRUE)

  # ponds from [yr]
  ponds_yr <- ponds %>% filter(dataset==dataset) 
  
  # Convert plots to a SpatVector (terra format)
  plots_terra <- vect(plots)
  
  # Create an empty list to store the cropped rasters
  cropped_rasters <- list()
  
  # Initialize an empty data frame to store the results
  accuracy_results <- data.frame(
    Plot = integer(),
    Correct_Area = numeric(),
    Underestimated_Area = numeric(),
    Overestimated_Area = numeric(),
    stringsAsFactors = FALSE
  )
  
  # Loop through each plot and find the appropriate raster
  for(i in 1:nrow(plots)) {
    
    plot <- plots_terra[i,]
    plot_id <- plot$Plot
    
    # Get the plot's bounding box (extent)
    plot_extent <- ext(plot)
    
    # Find the raster that overlaps with the plot's bounding box
    raster_to_use <- NULL
    for (rast in raster_list) {
      raster_extent <- ext(rast)
      intersect_result <- terra::intersect(raster_extent, plot_extent)
      if (!is.null(intersect_result) && length(intersect_result) > 0) {
        raster_to_use <- rast
        break  
      }
    }

    # If an appropriate raster is found, crop it to the plot's extent
    if (!is.null(raster_to_use)) {
      
      # get predicted raster
      cropped_raster <- crop(raster_to_use, plot_extent)

      # rasterize HAPET pond layer (0=dry, 1=wet)
      ponds_in_plot <- ponds_yr %>% filter(Plot==plot_id)
      ponds_raster <- terra::rasterize(ponds_in_plot, cropped_raster, field = 1, background = 0)

      # store the cropped raster in the list with the plot ID as the name
      #plot_id <- plot$Plot  
      #cropped_rasters[[paste("plot", plot_id, sep = "_")]] <- cropped_raster

      # calculate accuracy
      
        # convert to utm for better area prediction
        cropped_raster_utm <- project(cropped_raster, "EPSG:32614", res=10)
        ponds_raster_utm <- project(ponds_raster, "EPSG:32614", res=10)
        cell_area <- 100
        
        # convert classification probabilities to binary
        binary_prediction_utm <- as.numeric(cropped_raster_utm >= 0.5) 
      
        # correct area
        correct_rast <- as.numeric(binary_prediction_utm == ponds_raster_utm)
        correct_area <- sum(values(correct_rast) == 1, na.rm = TRUE) * cell_area
        
        # underestimated wet area
        underest_rast <- as.numeric(binary_prediction_utm == 0 & ponds_raster_utm == 1)
        underest_area <- sum(values(underest_rast) == 1, na.rm = TRUE) * cell_area
        
        # overestimated wet area
        overest_rast <- as.numeric(binary_prediction_utm == 1 & ponds_raster_utm == 0) 
        overest_area <- sum(values(overest_rast) == 1, na.rm = TRUE) * cell_area
        
        # get number of ponds detected
        wet_pixels_sf <- binary_prediction_utm %>% 
          as.data.frame(xy=T) %>% 
          filter(probabilities==1) %>% 
          st_as_sf(coords = c("x", "y"), crs=32614) %>% 
          st_transform(4326)
        intersections <- st_intersects(ponds_in_plot, wet_pixels_sf)

        # Save the results in the accuracy_results data frame
        accuracy_results <- rbind(accuracy_results, data.frame(
          Plot = plot_id,
          Correct_Area = correct_area,
          Underestimated_Area = underest_area,
          Overestimated_Area = overest_area,
          n_ponds = nrow(ponds_in_plot),
          n_ponds_detected = sum(sapply(intersections, length) > 0)
        ))
        
      print(paste("Processed plot", plot_id))  # Adjust if needed to extract plot ID
  } else {
    print(paste("No raster found for plot", plot_id))
  }
}

##########################
# OOT PLOT-WIDE ACCURACY 
# total correct
totals <- accuracy_results %>% 
    summarize(correct = sum(Correct_Area),
              underestimated = sum(Underestimated_Area),
              overestimated = sum(Overestimated_Area),
              prop_ponds_detected = sum(n_ponds_detected)/sum(n_ponds)) %>% 
    mutate(PA = correct/(correct+underestimated),
           UA = correct/(correct+overestimated))

totals$PA  # recall
totals$UA  # precision
totals$prop_ponds_detected

# 50% threshold: May 22: 99.2% PA // 74.2% UA 
# 60% threshold: May 22: 99.0% PA // 78.1% UA 
# 70% threshold: May 22: 98.8% PA // 83.0% UA 
# 80% threshold: May 22: 97.6% PA // 90.4% UA -- 76% of ponds
# 90% threshold: May 22: 84.4% PA // 100% UA 

# 50% threshold: May 24: 98.5% PA // 78.0% UA  

plot_totals <- accuracy_results %>% 
  group_by(Plot) %>% 
  summarize(correct = sum(Correct_Area),
            underestimated = sum(Underestimated_Area),
            overestimated = sum(Overestimated_Area),
            prop_ponds_detected = sum(n_ponds_detected/n_ponds)) %>% 
  mutate(PA = correct/(correct+underestimated),
         UA = correct/(correct+overestimated))

plots %>% 
  inner_join(plot_totals, by="Plot") %>% 
  filter(!is.na(PA)) %>% 
  st_centroid() %>% 
  mapview(zcol="PA", cex=6)

plots %>% 
  inner_join(plot_totals, by="Plot") %>% 
  filter(!is.na(UA)) %>% 
  st_centroid() %>% 
  mapview(zcol="UA", cex=6)

plots %>% 
  inner_join(plot_totals, by="Plot") %>% 
  filter(!is.na(prop_ponds_detected)) %>% 
  st_centroid() %>% 
  mapview(zcol="prop_ponds_detected", cex=6)

# btw, num ponds detected is wrong for all exports except thresh=50 and 80
write.csv(accuracy_results, here("data/accuracy_24_thresh50.csv"))

#################
# OOST PLOT-WIDE ACCURACY 

test_plot_ids <- scan(here("data", "train_test_data", "test_plot_ids.txt"))

totals <- accuracy_results %>% 
  filter(Plot %in% test_plot_ids) %>% 
  summarize(correct = sum(Correct_Area),
            underestimated = sum(Underestimated_Area),
            overestimated = sum(Overestimated_Area),
            prop_ponds_detected = sum(n_ponds_detected)/sum(n_ponds)) %>% 
  mutate(PA = correct/(correct+underestimated),
         UA = correct/(correct+overestimated))

totals$PA  # recall
totals$UA  # precision
totals$prop_ponds_detected

# 80% threshold: May 22: 98.1% PA // 92.8% UA -- 76% of ponds


plot_totals <- accuracy_results %>% 
  filter(Plot %in% test_plot_ids) %>%
  group_by(Plot) %>% 
  summarize(correct = sum(Correct_Area),
            underestimated = sum(Underestimated_Area),
            overestimated = sum(Overestimated_Area),
            prop_ponds_detected = sum(n_ponds_detected/n_ponds)) %>% 
  mutate(PA = correct/(correct+underestimated),
         UA = correct/(correct+overestimated))

