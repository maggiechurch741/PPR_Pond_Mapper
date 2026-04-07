library(sf)
library(tmap)

veg_est <- st_read("figs8/plot_May24_plot262_est.shp")
veg_obs <- st_read("figs8/plot_May24_plot262_obs.shp")
river_est <- st_read("figs8/plot_May24_plot937_est.shp")
river_obs <- st_read("figs8/plot_May24_plot937_obs.shp")

# library(mapedit)
# drawn_features <- editMap(mapview(veg_est))
# my_bbox_sf <- drawn_features$finished
# my_bbox_sf$geometry %>% st_bbox()

veg_bbox_poly <- st_as_sfc(st_bbox(c(xmin = -95.70757, ymin = 45.94733, 
                                     xmax = -95.70045, ymax = 45.95497), 
                                   crs = 4326))

river_bbox_poly <- st_as_sfc(st_bbox(c(xmin = -108.75012, ymin = 48.51959,
                                       xmax = -108.74424, ymax = 48.52361), 
                                     crs = 4326))

a <- tm_shape(veg_bbox_poly) + 
  tm_basemap("Esri.WorldImagery") +
  tm_shape(veg_est) +
  tm_polygons(col = "#4169E1", border.col = "#4169E1", alpha = 1) +
  tm_shape(veg_obs) +
  tm_borders(col = "white", lwd = 2)

b <- tm_shape(veg_bbox_poly) + 
  tm_basemap("Esri.WorldImagery") +
  tm_shape(veg_obs) +
  tm_borders(col = "white", lwd = 2)

c <- tm_shape(river_bbox_poly) + 
  tm_basemap("Esri.WorldImagery") +
  tm_shape(river_est) +
  tm_polygons(col = "#4169E1", border.col = "#4169E1", alpha = 1) +
  tm_shape(river_obs) +
  tm_borders(col = "white", lwd = 2)

d <- tm_shape(river_bbox_poly) + 
  tm_basemap("Esri.WorldImagery") +
  tm_shape(river_obs) +
  tm_borders(col = "white", lwd = 2)

######################
# 1. Update each panel with standard manuscript tags
# We use title.size and title.weight to make the "A, B..." pop
a_final <- a + tm_layout(title = "a.", 
                         title.size = 1.5, 
                         title.position = c(0.01, 0.97), 
                         title.color = "white", 
                         title.fontface = "bold",
                         frame = FALSE,
                         inner.margins = c(0.05, 0.05, 0.05, 0.05))

b_final <- b + tm_layout(title = "b.", 
                         title.size = 1.5, 
                         title.position = c(0.01, 0.97), 
                         title.color = "white", 
                         title.fontface = "bold",
                         frame = FALSE,
                         inner.margins = c(0.05, 0.05, 0.05, 0.05))

c_final <- c + tm_layout(title = "c.", 
                         title.size = 1.5, 
                         title.position = c(0.01, 0.97), 
                         title.color = "white", 
                         title.fontface = "bold",
                         frame = FALSE,
                         inner.margins = c(0.05, 0.05, 0.05, 0.05))

d_final <- d + tm_layout(title = "d.", 
                         title.size = 1.5, 
                         title.position = c(0.01, 0.97), 
                         title.color = "white", 
                         title.fontface = "bold",
                         frame = FALSE,
                         inner.margins = c(0.05, 0.05, 0.05, 0.05))

# 2. Arrange into the 2x2 grid
four_panel_fig <- tmap_arrange(a_final, b_final, c_final, d_final, 
                               ncol = 2, nrow = 2)
four_panel_fig

# 3. Save at high resolution
tmap_save(four_panel_fig, 
          filename = "Figure_S8.png", 
          dpi = 600, 
          width = 8, 
          height = 8, 
          units = "in")