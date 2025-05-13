
# Function to sample n points from 

# Sample 1 point per pond with error handling
safe_sample <- function(geometry) {
  tryCatch({
    sampled_point <- st_sample(geometry, 1, force = TRUE)
    if (length(sampled_point) == 0) {
      return(NA)
    } else {
      return(sampled_point)
    }
  }, error = function(e) {
    return(NA)  # Return NA in case of error
  })
}

# Function to sample 200 points, cycling through ponds without repeating points in a cycle
cycle_sample <- function(grouped_sf, n) {
  
  # Step 1: Sample 1 point per pond
  sampled_points <- grouped_sf %>%
    mutate(sample_point = map(geometry, safe_sample)) %>%
    filter(!map_lgl(sample_point, ~ all(is.na(.x))))  # Remove NAs
  
  n_ponds <- nrow(sampled_points)
  
  # Step 2: If there are fewer ponds than 200, cycle through the ponds
  if (n_ponds < n) {
    remaining_needed <- n - n_ponds
    full_cycles <- floor(remaining_needed / n_ponds)
    leftover <- remaining_needed %% n_ponds
    
    # Repeat the full cycles
    full_sampled_points <- sampled_points[rep(1:n_ponds, full_cycles), ]
    
    # Add the remaining samples (without replacement, but ensuring no duplicates within this cycle)
    leftover_sampled_points <- sample_n(sampled_points, leftover, replace = FALSE)
    
    # Combine full cycles and leftover
    sampled_points <- bind_rows(sampled_points, full_sampled_points, leftover_sampled_points)
  }
  
  # Step 3: Ensure the final number of points is exactly `n`
  final_sample <- sampled_points %>% slice_sample(n = n, replace = FALSE)
  
  return(final_sample)
}
