sptm_sample <- function(df, n_per_cell){
  df |>
    mutate(grid_area_prop = as.numeric(grid_area_prop)) |> 
    # stratify by class, grid-id, and survey period
    group_by(type, grid_id, dataset) |>
    group_modify(~ {
      # determine number of wet & dry rows to sample for this grid-survey
      n <- round(n_per_cell * .x$grid_area_prop[1] / 2)
      
      # sample without replacement for all grid-surveys
      base_sample <- slice_sample(.x, n=n, replace=FALSE) 
      
      # for grid-surveys that need more, re-sample with replacement
      if(nrow(.x) < n){
        # Calculate needed points per group
        needed_points <- n - nrow(.x)  
        augmented_points <- slice_sample(., n = needed_points, replace = TRUE)  
        bind_rows(base_sample, augmented_points)
      } else {
        base_sample
      }
    }) |>
    ungroup()
}