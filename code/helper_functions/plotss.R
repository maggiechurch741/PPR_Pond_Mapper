# fn to plot Sentinel-2 spectral signature and compare by group
#     requires 1 grouping var
#     assumes you're using the 10- and 20-m S2 bands (there are 9)
#     also assumes data is in micrometeres, not nanometers
# To play with ggplot parameters, you'll have to edit the function directly

# inputs: 
#     dataframe
#     grouping var: categorical var for which we wanna compare spec sigs
#     band_cindices: column indices of your Sentinel-2 band values (there should be 9, and THEY SHOULD BE IN ORDER!)
#     subtitle (default is a lil explanation of the plot)
#     title (default is blank)

plotss <- function(
  df, 
  grouping_var, 
  band_cindices, 
  subtitle="Dotted lines show average surface reflectance. Error bar shows stardard deviation for each landcover type (+/- 1 sd)",
  title="",
  CI=T){
  
  # Convert grouping_var to a string for use with dynamic column selection
  grouping_var_name <- deparse(substitute(grouping_var))
  
  # get band names 
  band_names <- df %>% select(all_of(band_cindices)) %>% colnames()
  
  class_means <- df %>%
    as.data.frame() %>%
    dplyr::select(all_of(band_cindices), {{grouping_var}}) %>%
    group_by({{grouping_var}}) %>%
    summarize(across(everything(), mean))
  
  class_sd <- df %>%
    as.data.frame() %>%
    dplyr::select(all_of(band_cindices), {{grouping_var}}) %>%
    group_by({{grouping_var}}) %>%
    summarise(across(everything(), sd)) 
  
  class_means_bands <- class_means %>%
    pivot_longer(-{{grouping_var}}, names_to="band") %>%
    rename("mean"="value")
  
  class_sd_bands <- class_sd %>%
    pivot_longer(-{{grouping_var}}, names_to="band") %>%
    rename("sd"="value")
  
  class_bands <-  inner_join(class_sd_bands, class_means_bands, by = c(grouping_var_name, "band")) %>% 
    mutate(band_acr = case_when(
      band %in% band_names[1] ~ "B",
      band %in% band_names[2] ~ "G",
      band %in% band_names[3] ~ "R",
      band %in% band_names[4] ~ "RE1",
      band %in% band_names[5] ~ "RE2",
      band %in% band_names[6] ~ "RE3",
      band %in% band_names[7] ~ "NIR",
      band %in% band_names[8] ~ "SWIR1",
      band %in% band_names[9] ~ "SWIR2"
    )) %>%
    mutate(band_cw = case_when( 
      band_acr == "B" ~ .49,
      band_acr == "G"~ .56,
      band_acr == "R"~ .665,
      band_acr == "RE1"~ .705,
      band_acr == "RE2"~ .74,
      band_acr == "RE3"~ .783,
      band_acr == "NIR"~ .842,
      band_acr == "SWIR1"~ 1.61,
      band_acr == "SWIR2"~ 2.19
    ))

  # Define S2 wavelength ranges and corresponding colors
  color_bars <- data.frame(
    xmin = c(.457, .542, .650, .6975, .7325, .773, .7845, 1.565, 2.100),  # Starting wavelengths
    xmax = c(.522, .577, .680, .7125, .7475, .793, .8995, 1.655, 2.280),  # Ending wavelengths
    color = c("blue", "forestgreen", "red", "brown3", "brown3", "brown3", "tan4", "grey50", "grey30")  # Corresponding colors
  )
  
  p <- class_bands %>% 
    ggplot(aes(x = band_cw,
               y = mean,
               group = {{grouping_var}}, 
               color = factor({{grouping_var}}))) +
    geom_line(linetype='dashed', size=1)  +
    geom_rect(data = color_bars, 
              aes(xmin = xmin, xmax = xmax, ymin = -0.015, ymax = 0), 
              inherit.aes = FALSE, 
              fill = color_bars$color) +
    theme_minimal() + 
    labs(x=expression(paste('Wavelength (', mu, 'm)')),
         y='Reflectance',
         subtitle = subtitle,
         title=title) +
    theme(axis.text=element_text(size=20),
          axis.title=element_text(size=20),
          legend.text=element_text(size=20),
          legend.title=element_blank())
  
  if(CI==T){
    p <- p + 
      geom_ribbon(aes(ymin = mean - sd, 
                      ymax = mean + sd,
                      fill = factor({{grouping_var}})), 
                  alpha = 0.15, linetype = 0)
  }
  
  return(p)
}

