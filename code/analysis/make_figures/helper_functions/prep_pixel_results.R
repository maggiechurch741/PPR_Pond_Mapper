
## Read in pixel predictions
pixel_results <- read_csv(here("data/accuracy_assessment/pixel_results.csv"))

# Read in test plot-surveys
test_plots <- read_csv(here("data/train_test_data/test_plot_surveys.csv")) |> rename(Plot=plot_id)

# Limit test pixel predictions to the pre-selected plot-surveys used for testing (we trust HAPET on these)
pixel_results <- pixel_results |> inner_join(test_plots)

# Stratify pixel-based dataset by time (ecoregion) and space (dataset). Draw 140k samples from each strata.
set.seed(123)

pixel_results <- pixel_results |>
  group_by(dataset, test_box) |>
  group_modify(~ {
    df <- .x
    # compute number of samples per strata
    strata_counts <- df |>
      count(true_label) |>
      mutate(n_sample = round(140000 * n / sum(n)))
    
    # sample each strata
    sampled_list <- lapply(seq_len(nrow(strata_counts)), function(j) {
      cls <- strata_counts$true_label[j]
      n_samp <- strata_counts$n_sample[j]
      df_cls <- df[df$true_label == cls, ]
      
      slice_sample(df_cls, n = n_samp)
    })
    
    # combine back
    bind_rows(sampled_list)
  }) |>
  ungroup()

# add ecoregion name
pixel_results <- pixel_results |>
  mutate(ecoregion_name = case_when(
    test_box == 1 ~ "Northwestern Glaciated Plains (MT)",
    test_box == 2 ~ "Northwestern Glaciated Plains (ND/SD)",
    test_box == 3 ~ "Lake Agassiz Plain (N. MN)",
    test_box == 4 ~ "North Central Hardwood Forests (C. MN)",
    test_box == 5 ~ "Northern Glaciated Plains (ND + SD)",
    test_box == 6 ~ "Western Corn Belt Plains (S. MN + IA)"
  )) |> 
  mutate(ecoregion_name = factor(ecoregion_name, 
                                levels = ecoregion_name[match(c(6, 3, 4, 5, 2, 1), test_box)])) |>
  mutate(dataset = factor(dataset, levels=c("brood16", "2022", "2024"))) 
