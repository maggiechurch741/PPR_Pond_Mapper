library(tidyverse)
library(here)
library(sf)
library(janitor)
library(mapview)
library(cowplot)
library(ggpubr)  

# May and Aug PHDI downloaded from NOAA:
# https://www.ncei.noaa.gov/access/monitoring/climate-at-a-glance/divisional/mapping/110/phdi/202205/1/value

####################################
# read in PHDI data
phdi_files <- list.files(here("data", "noaa"), full.names = TRUE)

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
states <- st_read(here("data", "boundaries", "states")) %>% 
  select(STUSPS, STATEFP)
counties <- st_read(here("data", "boundaries", "counties"))
ppjv <- st_read(here("data", "boundaries", "PPJV")) %>% 
  st_transform(st_crs(counties))

# read in allPlots
allPlots <- st_read(here("data", "allPlots"))

# get the ND-only bbox
nd_bbox <- allPlots %>% 
  filter(Plot > 996) %>% 
  st_bbox() %>% 
  st_as_sfc() %>% 
  st_transform(st_crs(counties))

####################################
# function to convert PHDI to sf and limit to PPR
make_noaa_sf <- function(noaa_df, bbox){
  
  # get geoid (state fips + county fips) for phdi units
  noaa_df_w_geoid <- noaa_df %>% 
    # add state fips
    mutate(state_abbr = str_sub(ID, 1, 2)) %>% 
    left_join(states, by = c("state_abbr" = "STUSPS")) %>% 
    # isolate county fips
    mutate(COUNTYFP = str_sub(ID, 4, 6)) %>% 
    # create geoid
    mutate(GEOID = paste0(STATEFP, COUNTYFP)) %>% 
    # keep original cols + geoid
    select(1:7, GEOID)
  
  # convert phdi to sf + limit to ppr
  noaa_sf <- noaa_df_w_geoid %>% 
    inner_join(counties, by = "GEOID") %>%
    st_as_sf() %>% 
    janitor::clean_names() %>%
    st_join(ppjv, left=F) %>% 
    rename(PHDI = value)
  
  # If bbox is provided, filter data for ND
  if (!is.null(bbox)) {
    noaa_sf <- noaa_sf %>% 
      st_intersection(bbox)  # Only keep points within the ND bounding box
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


  
###############################################################################

# Function to plot selected datasets with a shared fill legend
plot_phdi_data <- function(dataset_names = NULL, fill_limits=NULL, ncol=2) {
  
  # If no dataset names are provided, use all datasets
  if (is.null(dataset_names)) {
    dataset_names <- names(processed_phdi_list)
  }
  
  # Function to convert dataset name (e.g., 'phdi_may16') to a readable title (e.g., 'May 2016')
  format_title <- function(name) {
    # Extract the month and year from 'phdi_monYY' format
    month_year <- sub("phdi_", "", name)  # Remove the 'phdi_' part
    month_year <- gsub("([a-zA-Z]+)([0-9]{2})", "\\1 \\2", month_year)  # Add space between month and year
    # Convert month to title case
    month_year <- sub("^(\\w)", toupper("\\1"), month_year)  # Capitalize the first letter of the month
    return(month_year)
  }
  
  # Filter the datasets to include only the selected ones
  selected_datasets <- processed_phdi_list[dataset_names]
  
  # Generate plots without legends
  plots <- lapply(names(selected_datasets), function(name) {
    ggplot() + 
      geom_sf(data = st_transform(selected_datasets[[name]], 32614), aes(fill = PHDI)) + 
      scale_fill_gradientn(
        colors = c("#38200e", "#814b22", "#dc8039", "white", "#c2f6ed", "#59c1af", "#387e71", "#065244", "#00342a"),
        values = scales::rescale(c(-6, -4, -2, 0, 2, 4, 6, 8, 10)),
        limits = fill_limits
      ) + 
      theme_minimal() + 
      theme(legend.position = "none", 
            axis.text.x = element_text(angle = 45, hjust = 1),
            axis.text = element_text(size = 14), 
            plot.title = element_text(size = 18, face = "bold", hjust = 0.5) 
      ) +
      labs(title = format_title(name))
  })
  
  # Create a reference plot to extract the shared legend
  ref_plot <- ggplot() + 
    geom_sf(data = selected_datasets[[1]], aes(fill = PHDI)) + 
    scale_fill_gradientn(
      colors = c("#38200e", "#814b22", "#dc8039", "white", "#c2f6ed", "#59c1af", "#387e71", "#065244", "#00342a"),
      values = scales::rescale(c(-6, -4, -2, 0, 2, 4, 6, 8, 10)),
      limits = fill_limits,
      name = "PHDI"
    ) + 
    theme_minimal() + 
    theme(legend.position = "right") 
  
  # Extract the legend
  legend <- get_legend(ref_plot)
  
  # Arrange plots with the shared legend
  plot_grid(plot_grid(plotlist = plots, ncol = ncol, align = "hv"), 
            legend, 
            rel_widths = c(3, 0.3))
}

############
# Define a common fill scale based on min/max values across all datasets in the list
fill_limits <- range(
  unlist(lapply(processed_phdi_list, function(df) df$PHDI)),
  na.rm = TRUE
)

plot_phdi_data(dataset_names = c("phdi_may21", "phdi_aug21", "phdi_may22", "phdi_aug22"), fill_limits=fill_limits)


# Plot only selected datasets
plot_phdi_data(dataset_names = c("phdi_may16", "phdi_may17"), fill_limits=fill_limits)
plot_phdi_data(dataset_names = c("phdi_aug16", "phdi_aug17"), fill_limits=fill_limits)

plot_phdi_data(dataset_names = c("phdi_may19", "phdi_may21", "phdi_may22", "phdi_may23", "phdi_may24"), fill_limits=fill_limits)
plot_phdi_data(dataset_names = c("phdi_aug19", "phdi_aug21", "phdi_aug22", "phdi_aug23", "phdi_aug24"), fill_limits=fill_limits)
####################################################

# Define a common fill scale based on min/max values for 2022-2024
fill_limits <- range(
  unlist(lapply(processed_phdi_list[c(5,7, 12,14)], function(df) df$PHDI)),
  na.rm = TRUE
)

plot_phdi_data(dataset_names = c("phdi_may21", "phdi_aug21","phdi_may22", "phdi_aug22", 
                                 "phdi_may23", "phdi_aug23", "phdi_may24", "phdi_aug24"), fill_limits=fill_limits)

plot_phdi_data(dataset_names = c("phdi_aug16", "phdi_may22", "phdi_may24"), fill_limits=fill_limits, ncol=3)
