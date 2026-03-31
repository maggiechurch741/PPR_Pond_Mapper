calculate_grouped_accuracy <- function(df, group_cols, model) {
  
  df_refac <- df |>
    mutate(
      true_label = factor(true_label),
      pred_label = case_when(
        .data[[model]] == "water" ~ "wet",
        .data[[model]] == "nonwater" ~ "dry",
        TRUE ~ .data[[model]]
      ) |> factor(levels = c("dry", "wet"))
    )
  
  df_refac |>
    group_by(across(all_of(group_cols))) |>
    group_split() |>
    purrr::map_dfr(function(df_group) {
      
      group_vals <- df_group[1, group_cols, drop = FALSE]
      
      # Predictions
      pred <- df_group$pred_label == "wet"
      true <- df_group$true_label == "wet"
      
      valid <- !is.na(pred) & !is.na(true)
      pred <- pred[valid]
      true <- true[valid]
      
      # Confusion matrix
      TP <- sum(pred & true)
      FN <- sum(!pred & true)
      TN <- sum(!pred & !true)
      FP <- sum(pred & !true)
      
      sensitivity <- TP / (TP + FN)
      specificity <- TN / (TN + FP)
      precision   <- TP / (TP + FP)
      oe          <- 1 - sensitivity
      ce          <- 1 - precision
      f1          <- (2 * sensitivity * precision) / (sensitivity + precision)
      oa          <- (TP + TN) / (TP + TN + FP + FN)
      
      # AUC (probabilistic model)
      auc_val <- NA
      roc_input <- df_group |>
        filter(!is.na(probabilities), !is.na(true_label))
      
      if (length(unique(roc_input$true_label)) == 2) {
        roc_curve <- pROC::roc(
          roc_input$true_label,
          roc_input$probabilities
        )
        auc_val <- round(as.numeric(pROC::auc(roc_curve)), 2)
      }
      
      cbind(
        group_vals,
        data.frame(
          auc = auc_val,
          nwet = sum(df_group$true_label == "wet", na.rm = TRUE),
          ndry = sum(df_group$true_label == "dry", na.rm = TRUE),
          oa = round(oa, 2),
          sensitivity = round(sensitivity, 2),
          specificity = round(specificity, 2),
          precision = round(precision, 2),
          oe = round(oe, 2),
          ce = round(ce, 2),
          f1 = round(f1, 2),
          TP = TP,
          FN = FN,
          TN = TN,
          FP = FP
        )
      )
    })
}
