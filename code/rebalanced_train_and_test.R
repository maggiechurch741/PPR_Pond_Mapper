
# changes made: 
#   adds more dry testing points to test set
#   uses grid 217 instead of 260, for Lake Agassiz test box
#   balances test set, so that wet and dry points are balanced within a grid-year
#   drops 2020 entirely
#   re-balances training set: samples 1 grid cell (100 wet and dry points) PER DATASET
#   !NVM! replaces missing VV and VH with median values of training set NVM! 
#   fixes the mis-scaled band values from 2016-2017
library(tidyverse)
library(sf)

home_dir <- "~/Documents/PPR/"
set.seed(123)

grid <- st_read(paste0(home_dir, "maggie_analysis/data/inputs/grid/grid_sf.shp"))

# try using grid_id 217 (plots 280, 281, 620) instead of grid_id 260 (plots 200, 769)
test <- st_read(paste0(home_dir, "maggie_analysis/data/intermediate/testing/testing.shp")) %>% 
  mutate(plot_id = if_else(is.na(plot_id), Plot, plot_id))

test2 <- st_read(paste0(home_dir, "maggie_analysis/data/intermediate/testing/dryMORETESTING.shp")) %>% 
  mutate(
    NDPI = (swir1-green)/(swir1+green),
    BU3 = red + swir1 - nir,
    AWEI = (green-swir2) - (0.25*nir + 2.75*swir1),
    AWEISH = blue + 2.5*green - 1.5*(nir+swir1) - 0.25*swir2,
    BSI = ((swir1+red-nir-blue)/(swir1+red+nir+blue))*100 + 100,
    DVW = NDVI-NDWI,
    DVI = nir-red,
    IFW = nir-green,
    IPVI = nir/(nir+red),
    MIFW = swir1-green,
    OSAVI = (nir-red)/(nir+red+0.16),
    SAVI = ((nir-red)/(nir+red+0.5))*1.5,
    RVI = nir/red,
    TVI = 0.5*(120*(nir-green)-200*(red-green)),
    WRI = (green+red)/(nir+swir1),
    WTI = 0.91*red + 0.43*nir,
    VARI = (green-red)/(green+red-blue),
    BGR = blue/green,
    GRR = green/red,
    RBR = red/blue,
    SRBI = blue-red,
    NPCRI = (red-blue)/(red+blue), # Normalized Pigment Chlorophyll Ratio Index 
    EVI3b = 2.5 * (nir - red)/(nir + (6*red) - (7.5*blue) + 1),
    EVI2b = 2.5 * (nir - red)/ (nir + (2.4*red) + 1)
  ) %>% 
  mutate(
    type="dry",
    flyvr_d = as.Date(flyvr_d)
  ) %>% 
  st_join(grid)

jrc_missed <- read_sf(paste0(home_dir, "maggie_analysis/data/intermediate/jrc_missed/jrc_missed.shp")) %>% 
  st_transform(st_crs(test)$wkt)

fulltest <- bind_rows(test, test2) %>% 
  st_difference(jrc_missed) %>% 
  mutate(STATEFP = as.numeric(STATEFP))

# uhh idk how this happened but...
fix_bands <- fulltest %>% 
  st_drop_geometry() %>% 
  filter(dataset %in% c("pair16", "pair17", "brood16", "brood17")) %>% 
  select(3, 6, 13, 15, 20, 35, 42, 44, 45) %>% 
  mutate(across(everything(), ~ . * 10000)) %>% 
  mutate(NDRE = (nir-red_edge_1)/(nir+red_edge_1),
         NDVI = (nir-red)/(nir+red),
         NDWI = (green-nir)/(green+nir),
         mNDWI1 = (green-nir)/(green+nir),
         mNDWI2 = (green-swir2)/(green+swir2),
         NDMI1 = (nir-swir1)/(nir+swir1),
         NDMI2 = (nir-swir2)/(nir+swir2),
         TCG = -0.3599*blue - 0.3533*green - 0.4734*red - 0.6633*nir + 0.0087*swir1 - 0.2856*swir2,
         TCB = 0.3510*blue + 0.3813*green + 0.3437*red + 0.7196*nir + 0.2396*swir1 + 0.1949*swir2,
         TCW = 0.2578*blue + 0.2305*green + 0.0883*red + 0.1071*nir - 0.7611*swir1 - 0.5308*swir2,
         ABWI = (blue + green + red - (nir + swir1 + swir2)) / (blue + green + red + (nir + swir1 + swir2)),
         NDPI = (swir1-green)/(swir1+green),
         BU3 = red + swir1 - nir,
         AWEI = (green-swir2) - (0.25*nir + 2.75*swir1),
         AWEISH = blue + 2.5*green - 1.5*(nir+swir1) - 0.25*swir2,
         BSI = ((swir1+red-nir-blue)/(swir1+red+nir+blue))*100 + 100,
         DVW = NDVI-NDWI,
         DVI = nir-red,
         IFW = nir-green,
         IPVI = nir/(nir+red),
         MIFW = swir1-green,
         OSAVI = (nir-red)/(nir+red+0.16),
         SAVI = ((nir-red)/(nir+red+0.5))*1.5,
         RVI = nir/red,
         TVI = 0.5*(120*(nir-green)-200*(red-green)),
         WRI = (green+red)/(nir+swir1),
         WTI = 0.91*red + 0.43*nir,
         VARI = (green-red)/(green+red-blue),
         BGR = blue/green,
         GRR = green/red,
         RBR = red/blue,
         SRBI = blue-red,
         NPCRI = (red-blue)/(red+blue), # Normalized Pigment Chlorophyll Ratio Index 
         EVI3b = 2.5 * (nir - red)/(nir + (6*red) - (7.5*blue) + 1),
         EVI2b = 2.5 * (nir - red)/ (nir + (2.4*red) + 1)
  )

fix_attr <- fulltest %>% 
  filter(dataset %in% c("pair16", "pair17", "brood16", "brood17")) %>% 
  select(L3mod, type, sz_clss, dataset, VV, z_2, grid_id, VV, area_m, NWIclass, 
         VH, VVVH_ratio, STATEFP, spei30d, spei30d_2, spei30d_1, water30_10, water90_10, 
         area_cr, flyvr_d, PE, hand90_100, hand30_100, z, z_2, z_1, PercFll, plot_id, Acres, Shape_Area) 

fix <- bind_cols(fix_bands, fix_attr) %>% st_as_sf()

fulltest <- fulltest %>% 
  filter(!dataset %in% c("pair16", "pair17", "brood16", "brood17")) %>% 
  bind_rows(fix)
#############

g260 <- fulltest %>% filter(grid_id==260)

test_bal <- fulltest %>% 
  filter(!is.infinite(RBR)) %>%
  group_by(dataset, grid_id, type) %>%
  mutate(count = n()) %>%                    # Count each type within dataset
  ungroup() %>%
  group_by(dataset, grid_id) %>%
  mutate(min_count = min(count[type %in% c("wet", "dry")])) %>%   # Find min count of A or B within each dataset
  group_by(dataset, grid_id, type) %>%
  filter(row_number() <= min_count) %>%      # Keep only up to min count for each type
  ungroup() %>%
  select(-count, -min_count) %>% 
  filter(dataset != "2020")

#####################################
dat_sf <- read_csv(paste0(home_dir, "maggie_analysis/data/intermediate/balanced_training/balanced_training_b100.csv")) %>%
  mutate(coords = stringr::str_remove_all(geometry, "c\\(|\\)")) %>% # Remove "c(" and ")"
  separate(coords, into = c("x", "y"), sep = ", ") %>% # Split by ", "
  mutate(across(c(x, y), as.numeric)) %>% 
  st_as_sf(coords=c("x","y"), crs=4326) %>%
  bind_rows(g260)

g217 <- dat_sf %>% filter(grid_id==217)

test_bal <- test_bal %>% bind_rows(g217) %>% filter(grid_id != 260) 

################

train_sf <- dat_sf %>%
  filter(!is.infinite(RBR)) %>% 
  mutate(EVI3b = 2.5 * (nir - red)/(nir + (6*red) - (7.5*blue) + 1),
         EVI2b = 2.5 * (nir - red)/ (nir + (2.4*red) + 1)) %>% 
  filter(dataset != "2020") %>%
  filter(grid_id != 217) 

# uhh idk how this happened but...
fix_bands_train <- train_sf %>% 
  st_drop_geometry() %>% 
  filter(dataset %in% c("pair16", "pair17", "brood16", "brood17")) %>% 
  select(3, 6, 13, 15, 20, 35, 42, 44, 45) %>% 
  mutate(across(everything(), ~ . * 10000)) %>% 
  mutate(NDRE = (nir-red_edge_1)/(nir+red_edge_1),
         NDVI = (nir-red)/(nir+red),
         NDWI = (green-nir)/(green+nir),
         mNDWI1 = (green-nir)/(green+nir),
         mNDWI2 = (green-swir2)/(green+swir2),
         NDMI1 = (nir-swir1)/(nir+swir1),
         NDMI2 = (nir-swir2)/(nir+swir2),
         TCG = -0.3599*blue - 0.3533*green - 0.4734*red - 0.6633*nir + 0.0087*swir1 - 0.2856*swir2,
         TCB = 0.3510*blue + 0.3813*green + 0.3437*red + 0.7196*nir + 0.2396*swir1 + 0.1949*swir2,
         TCW = 0.2578*blue + 0.2305*green + 0.0883*red + 0.1071*nir - 0.7611*swir1 - 0.5308*swir2,
         ABWI = (blue + green + red - (nir + swir1 + swir2)) / (blue + green + red + (nir + swir1 + swir2)),
         NDPI = (swir1-green)/(swir1+green),
         BU3 = red + swir1 - nir,
         AWEI = (green-swir2) - (0.25*nir + 2.75*swir1),
         AWEISH = blue + 2.5*green - 1.5*(nir+swir1) - 0.25*swir2,
         BSI = ((swir1+red-nir-blue)/(swir1+red+nir+blue))*100 + 100,
         DVW = NDVI-NDWI,
         DVI = nir-red,
         IFW = nir-green,
         IPVI = nir/(nir+red),
         MIFW = swir1-green,
         OSAVI = (nir-red)/(nir+red+0.16),
         SAVI = ((nir-red)/(nir+red+0.5))*1.5,
         RVI = nir/red,
         TVI = 0.5*(120*(nir-green)-200*(red-green)),
         WRI = (green+red)/(nir+swir1),
         WTI = 0.91*red + 0.43*nir,
         VARI = (green-red)/(green+red-blue),
         BGR = blue/green,
         GRR = green/red,
         RBR = red/blue,
         SRBI = blue-red,
         NPCRI = (red-blue)/(red+blue), # Normalized Pigment Chlorophyll Ratio Index 
         EVI3b = 2.5 * (nir - red)/(nir + (6*red) - (7.5*blue) + 1),
         EVI2b = 2.5 * (nir - red)/ (nir + (2.4*red) + 1)
  )

fix_attr_train <- train_sf %>% 
  filter(dataset %in% c("pair16", "pair17", "brood16", "brood17")) %>% 
  select(L3mod, type, sz_clss, dataset, VV, z_2, cluster_id, grid_id, VV, area_m, NWIclass, VH, VVVH_ratio, STATEFP, spei30d, spei30d_2, spei30d_1, water30_10, water90_10, area_cr, flyvr_d, PE, hand90_100, hand30_100, z, z_2, z_1, PercFll, plot_id, Acres, Shape_Area, block) 

fix_train <- bind_cols(fix_bands_train, fix_attr_train) %>% st_as_sf()

train_sf <- train_sf %>% 
  filter(!dataset %in% c("pair16", "pair17", "brood16", "brood17")) %>% 
  bind_rows(fix_train) 

train_sf_bal <- train_sf %>% 
  group_by(grid_id, type) %>% 
  slice_sample(n=100) %>% 
  ungroup()

####################################

dat_sf <- read_csv(paste0(home_dir, "maggie_analysis/data/intermediate/unbalanced_training/training.shp")) %>%
  bind_rows(g260) %>%
  filter(grid_id != 217) %>%
  filter(!is.infinite(RBR)) %>%
  filter(!(red==0 & nir==0)) %>% # drop this 1 row
  mutate(EVI3b = 2.5 * (nir - red)/(nir + (6*red) - (7.5*blue) + 1),
         EVI2b = 2.5 * (nir - red)/ (nir + (2.4*red) + 1)) %>% 
  filter(dataset != "2020")

# uhh idk how this happened but...
fix_bands_train <- dat_sf %>% 
  st_drop_geometry() %>% 
  filter(dataset %in% c("pair16", "pair17", "brood16", "brood17")) %>% 
  select(3, 6, 13, 15, 20, 35, 42, 44, 45) %>% 
  mutate(across(everything(), ~ . * 10000)) %>% 
  mutate(NDRE = (nir-red_edge_1)/(nir+red_edge_1),
         NDVI = (nir-red)/(nir+red),
         NDWI = (green-nir)/(green+nir),
         mNDWI1 = (green-nir)/(green+nir),
         mNDWI2 = (green-swir2)/(green+swir2),
         NDMI1 = (nir-swir1)/(nir+swir1),
         NDMI2 = (nir-swir2)/(nir+swir2),
         TCG = -0.3599*blue - 0.3533*green - 0.4734*red - 0.6633*nir + 0.0087*swir1 - 0.2856*swir2,
         TCB = 0.3510*blue + 0.3813*green + 0.3437*red + 0.7196*nir + 0.2396*swir1 + 0.1949*swir2,
         TCW = 0.2578*blue + 0.2305*green + 0.0883*red + 0.1071*nir - 0.7611*swir1 - 0.5308*swir2,
         ABWI = (blue + green + red - (nir + swir1 + swir2)) / (blue + green + red + (nir + swir1 + swir2)),
         NDPI = (swir1-green)/(swir1+green),
         BU3 = red + swir1 - nir,
         AWEI = (green-swir2) - (0.25*nir + 2.75*swir1),
         AWEISH = blue + 2.5*green - 1.5*(nir+swir1) - 0.25*swir2,
         BSI = ((swir1+red-nir-blue)/(swir1+red+nir+blue))*100 + 100,
         DVW = NDVI-NDWI,
         DVI = nir-red,
         IFW = nir-green,
         IPVI = nir/(nir+red),
         MIFW = swir1-green,
         OSAVI = (nir-red)/(nir+red+0.16),
         SAVI = ((nir-red)/(nir+red+0.5))*1.5,
         RVI = nir/red,
         TVI = 0.5*(120*(nir-green)-200*(red-green)),
         WRI = (green+red)/(nir+swir1),
         WTI = 0.91*red + 0.43*nir,
         VARI = (green-red)/(green+red-blue),
         BGR = blue/green,
         GRR = green/red,
         RBR = red/blue,
         SRBI = blue-red,
         NPCRI = (red-blue)/(red+blue), # Normalized Pigment Chlorophyll Ratio Index 
         EVI3b = 2.5 * (nir - red)/(nir + (6*red) - (7.5*blue) + 1),
         EVI2b = 2.5 * (nir - red)/ (nir + (2.4*red) + 1)
  )

fix_attr_train <- dat_sf %>% 
  filter(dataset %in% c("pair16", "pair17", "brood16", "brood17")) %>% 
  select(L3mod, type, sz_clss, dataset, VV, z_2, VV, area_m, NWIclass, VH, VVVH_ratio, STATEFP, spei30d, spei30d_2, spei30d_1, water30_10, water90_10, area_cr, flyvr_d, PE, hand90_100, hand30_100, z, z_2, z_1, PercFll, plot_id, Acres, Shape_Area) 

fix_train <- bind_cols(fix_bands_train, fix_attr_train) %>% st_as_sf()

train_sf_unbal <- dat_sf %>% 
  filter(!dataset %in% c("pair16", "pair17", "brood16", "brood17")) %>% 
  bind_rows(fix_train) 

#####################################

st_write(test_sf, paste0(home_dir, "maggie_analysis/data/intermediate/rebalanced_11.19.24/test.shp"), append=F)
st_write(train_sf, paste0(home_dir, "maggie_analysis/data/intermediate/rebalanced_11.19.24/train.shp"), append=F)
st_write(train_sf_bal, paste0(home_dir, "maggie_analysis/data/intermediate/rebalanced_11.19.24/train_bal.shp"), append=F)
st_write(train_sf_unbal, paste0(home_dir, "maggie_analysis/data/intermediate/rebalanced_11.19.24/train_unbal.shp"), append=F)

