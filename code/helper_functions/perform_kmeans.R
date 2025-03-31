# Function to perform k-means on each dataset's coordinates
perform_kmeans <- function(data, k) {
  
  # Remove empty geometries
  data <- data[!st_is_empty(data), ]
  
  # Extract coordinates
  coords <- st_coordinates(data)  
  num_points <- nrow(coords)
  
  # Assign NA if not enough points
  if (num_points < k) {
    data$cluster_id <- NA  
    return(data)
  }
  
  # Run k-means
  kmeans_result <- kmeans(coords, centers = k, algorithm = "Lloyd", iter.max = 60)
  data$cluster_id <- kmeans_result$cluster
  return(data)
}