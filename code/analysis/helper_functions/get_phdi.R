# Maggie Church
# May 5, 2025

# This script:
# 1) reads in NOAA NCEI PHDI from downloaded csvs, which is county-level.
# 2) joins to county shapefiles and clips to PPR to convert PHDI to shp

library(tidyverse)
library(sf)

ppr_dir <- "~/Documents/PPR/PPR_Pond_Mapper/data/"

####################################
# read in PHDI data
phdi_files <- list.files(paste0(ppr_dir,"/noaa"), full.names = TRUE)

# Read the files into a list, with each element named after the file
phdi_data_list <- lapply(phdi_files, function(file) {
  # Extract the file name without extension
  file_name <- tools::file_path_sans_ext(basename(file))
  
  # Read the file (use `read_csv` for CSVs, modify as needed)
  data <- read_csv(file, skip = 3)
  
  # Return the data as an element in the list
  list(name = file_name, data = data)
})

# Assign the names of the list elements to the file names
names(phdi_data_list) <- tools::file_path_sans_ext(basename(phdi_files))

####################################
# read in state, county, and ppjv boundaries
states <- st_read(paste0(ppr_dir, "boundaries/states")) |> 
  select(STUSPS, STATEFP)

counties <- st_read(paste0(ppr_dir, "boundaries/counties"))

ppjv <- st_read(paste0(ppr_dir, "boundaries/PPJV")) |> 
  st_transform(st_crs(counties))

# read in allPlots
allPlots <- st_read(paste0(ppr_dir, "allPlots"))

# get the ND-only bbox
nd_bbox <- allPlots |> 
  filter(Plot > 996) |> 
  st_bbox() |> 
  st_as_sfc() |> 
  st_transform(st_crs(counties))

####################################
# function to convert PHDI to sf and limit to PPR
make_noaa_sf <- function(noaa_df, bbox){
  
  # get geoid (state fips + county fips) for phdi units
  noaa_df_w_geoid <- noaa_df |> 
    # add state fips
    mutate(state_abbr = str_sub(ID, 1, 2)) |> 
    left_join(states, by = c("state_abbr" = "STUSPS")) |> 
    # isolate county fips
    mutate(COUNTYFP = str_sub(ID, 4, 6)) |> 
    # create geoid
    mutate(GEOID = paste0(STATEFP, COUNTYFP)) |> 
    # keep original cols + geoid
    select(1:7, GEOID)
  
  # convert phdi to sf + limit to ppr
  noaa_sf <- noaa_df_w_geoid |> 
    inner_join(counties, by = "GEOID") |>
    st_as_sf() |> 
    janitor::clean_names() |>
    st_join(ppjv, left=F) |> 
    rename(PHDI = value)
  
  # If bbox is provided, filter data for ND
  if (!is.null(bbox)) {
    noaa_sf <- noaa_sf |> 
      st_filter(bbox)  # Only keep counties within the ND bounding box
  }
  
  return(noaa_sf)
}

###  Apply fn  ###

# 2016-2017 dataset names
pdhi_16_17_names <- c("phdi_may16", "phdi_may17", "phdi_aug16", "phdi_aug17")

# Apply function over the entire dataset list
processed_phdi_list <- lapply(names(phdi_data_list), function(item_name) {
  item_data <- phdi_data_list[[item_name]]$data
  
  # Apply the function with ND bbox filter for 2016-2017 data
  if (item_name %in% pdhi_16_17_names) {
    make_noaa_sf(item_data, nd_bbox)
    # Apply the function normally for other datasets
  } else {
    make_noaa_sf(item_data, NULL)  # Pass NULL or skip bbox filter
  }
})

# Assign the same names from phdi_data_list to processed_phdi_list
names(processed_phdi_list) <- names(phdi_data_list)
