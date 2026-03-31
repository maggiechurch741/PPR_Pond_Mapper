create_grouped_stats_table <- function(df, 
                                       group_col, 
                                       model, 
                                       metrics = c("auc", "oa", "oe", "ce", "f1"), 
                                       include_plot_accuracy = TRUE) {
  
  group_col_sym <- enquo(group_col)
  group_col_name <- rlang::as_name(group_col_sym)
  
  # Validate model
  model <- tolower(as.character(model))
  valid_models <- c("model", "jrc", "dw", "dswe_agg", "dswe_cons", "postproc10", "postproc20")
  if (!(model %in% valid_models)) stop("Invalid model. Choose 'model', 'postproc10', 'postproc20', 'dswe_cons', 'dswe_agg', 'dw', or 'jrc'.")
  

  ## ---------------- Optional: Plot-level accuracy ---------------- ##
  if (include_plot_accuracy) {
      plots_accuracy <- plot_results |>
        filter(source == model, class == "water") |>  # Only water class for this model
        group_by(!!group_col_sym) |>
        #group_by(across(all_of(group_col))) |>
        summarize(
          plot_rmse = round(sqrt(mean(((pred_area_m2 - true_wet_area_m2_cloudless) / 1e4)^2, na.rm = TRUE)), 0),
          plot_mean_error = round(mean((pred_area_m2 - true_wet_area_m2_cloudless) / 1e4, na.rm = TRUE), 0),
          plot_perc_detected = round(mean(pred_area_m2 / true_wet_area_m2_cloudless, na.rm = TRUE) * 100, 0),
          n_plots = n(),
          .groups = "drop"
        )
  }
  
  ## ---------------- Combine results ---------------- ##
  summary_df <- df
  
  if (include_plot_accuracy) {
    summary_df <- summary_df |>
      inner_join(plots_accuracy, by = group_col_name)
  }
  
  ## ---------------- Clean + label ---------------- ##
  summary_df <- summary_df |>
    select(any_of(c(group_col_name, metrics, 
                    if (include_plot_accuracy) c("plot_rmse", "plot_mean_error", "n_plots")))) |>
    # round and add commas if displaying TP FN TN FP
    mutate(
      across(intersect(c("TP", "FN", "TN", "FP"), metrics),
             ~ format(round(.x, -2), big.mark = ","))
    )
  
  if (!(model %in% c("model", "postproc10"))) {
    summary_df <- summary_df |> select(-any_of("auc"))
  }
  
  # ## ---------------- Adjust group name ---------------- ##
  # if (group_col_name == "ecoregion_name") {
  #   summary_df <- summary_df |>
  #     mutate(
  #       ecoregion_name = if_else(
  #         str_starts(ecoregion_name, "Northwestern Glaciated Plains"),
  #         ecoregion_name,
  #         str_remove(ecoregion_name, " \\(.*\\)")
  #       )
  #     ) |>
  #     arrange(factor(ecoregion_name, levels = c(
  #       "Western Corn Belt Plains",
  #       "Lake Agassiz Plain",
  #       "North Central Hardwood Forests",
  #       "Northern Glaciated Plains",
  #       "Northwestern Glaciated Plains (ND/SD)",
  #       "Northwestern Glaciated Plains (MT)"
  #     ))) |>
  #     rename(Ecoregion = ecoregion_name)
  # } else if (group_col_name == "dataset") {
  #   summary_df <- summary_df |> rename(Survey = dataset)
  # } else if (group_col_name == "phdi_class") {
  #   summary_df <- summary_df |> rename(PHDI = phdi_class)
  # }
  
  return(summary_df)
}
