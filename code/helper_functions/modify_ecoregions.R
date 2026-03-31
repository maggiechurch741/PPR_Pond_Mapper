library(sf)
library(here)

ppr <- read_sf(here("data/boundaries/PPJV")) |> st_transform(4326)
states <- read_sf(here("data/boundaries/states")) |> st_transform(4326)

# load ecoregion boundaries
ecoregion5 <- st_read(here("data", "boundaries", "reg5_eco_l3")) |> st_transform(4326)
ecoregion7 <- st_read(here("data", "boundaries", "reg7_eco_l3")) |> st_transform(4326)
ecoregion8 <- st_read(here("data", "boundaries", "reg8_eco_l3")) |> st_transform(4326)

##################################################
# combine ecoregion layers
ecoregions <- bind_rows(ecoregion5, ecoregion7, ecoregion8) 

# get the ecoregions within the ppr
ppr_ecoregions <- st_intersection(ecoregions, ppr)

# modify ecoregion category, to consolidate (a region gets subsumed if <5 plots in it)
ppr_ecoregions_mod <- ppr_ecoregions |> 
  mutate(L3mod = case_when(
    NA_L3NAME %in% c("Northwestern Great Plains", "Middle Rockies", "Canadian Rockies", "Northwestern Glaciated Plains") ~ "Northwestern Plains",
    NA_L3NAME %in% c("North Central Hardwood Forests", "Northern Lakes and Forests") ~ "North Central Hardwood Forests",
    NA_L3NAME %in% c("Lake Manitoba and Lake Agassiz Plain", "Northern Minnesota Wetlands") ~ "Lake Agassiz Plain",
    NA_L3NAME %in% c("Western Corn Belt Plains", "Driftless Area") ~ "Western Corn Belt Plains",
    T ~ NA_L3NAME
  )) |> 
  group_by(L3mod) |> 
  summarize(geometry = st_as_sf(st_union(geometry)))
##################################################

# break Northwestern Glaciated Plains into a MT side and a dakotas side
states_mt <- states |>
  filter(STUSPS=="MT")

states_other <- states |> 
  filter(STUSPS != "MT") |>
  st_union() |>
  st_sf(STUSPS = "OTHER", geometry = .) 

states_mt_oth <- bind_rows(states_mt, states_other)

ppr_ecoregions_mod2 <- st_intersection(ppr_ecoregions_mod, states_mt_oth) |> 
  mutate(ecoreg = case_when(
    STUSPS == "MT" ~ "Northwestern Glaciated Plains (MT)",
    STUSPS != "MT" & L3mod == "Northwestern Plains" ~ "Northwestern Glaciated Plains (ND/SD)",
    L3mod == "Aspen Parkland/Northern Glaciated Plains" ~ "Northern Glaciated Plains",
    T ~ L3mod
    )) |>
  select(L3mod = ecoreg)

mapview(ppr_ecoregions_mod2, zcol="L3mod")

st_write(ppr_ecoregions_mod2, here("data/boundaries/ecoregions6/ecoregions6.shp"), append=F)
