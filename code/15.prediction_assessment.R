---
title: "prediction_assessment"
output: html_document
date: "2025-05-08"
---

```{r}
library(terra)
library(here)
library(dplyr)
library(sf)
library(mapview)
```


```{r}
ppr <- st_read(here("data", "boundaries", "PPJV")) %>% st_transform(32614)
plots <- st_read(here("data", "allPlots")) 
ponds <- st_read(here("data", "allPonds")) %>% st_transform(4326)
```