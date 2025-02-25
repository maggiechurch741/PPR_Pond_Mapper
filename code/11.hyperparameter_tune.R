library(tidyverse)
library(mlr3spatiotempcv)
library(mlr3learners)
library(mlr3fselect)
library(mlr3tuning)
library(mlr3tuningspaces)  
library(viridis)
library(parallelly)
library(future)
library(here)

# read in training data
train <- read_csv(here("data", "train_test_data", "balanced_training_b100.csv")) %>% 
  filter(!is.na(NDRE))

# selected featureset (determined in 10.feature_selection.R)
sel_featureset <- c("AWEI", "NDRE", "IFW", "TCG", "z_2")

set.seed(123) 

# set up task
task <- 
  train %>% 
  select(all_of(sel_featureset), type, block) %>% 
  mutate(type=as.factor(type)) %>%  
  as_task_classif(target="type", 
                  positive="wet")

# instantiate leave-one-block-out resampling method
rsmp_lobo <- rsmp("loo")
task$set_col_roles("block", add_to = "group")
rsmp_lobo$instantiate(task)

# limit task to our SELECTED predictors
task <- task$select(sel_featureset)

# setup parallel processing
w <- availableCores()
plan("multisession", workers=w)

print(paste("NUMBER OF PARALLEL PROCESSES:", w))

# specify algorithm - here I use random forest
lrn_rf = lrn("classif.ranger", 
             predict_type = "prob",
             importance = "impurity",
             num.trees = 500, 
             max.depth = 10)

# set tuning space 
search_space = lts("classif.ranger.default")

# set tuning method
tuner = mlr3tuning::tnr("grid_search", resolution = 50) 

# set tuning terminator
terminator = trm("stagnation", iters=4, threshold=0.02)

# specify measure to optimize for
measure = msr("classif.auc")

# initialize tuning instance
instance = ti(
  task = task,
  learner = lrn_rf,
  resampling = rsmp_lobo, 
  measures = measure,
  terminator = terminator, 
  store_models = FALSE,
  search_space = search_space
)

# execute tuning process
tuner$optimize(instance)

# print best hyperparameters
best_hyperparams <- paste(
  "Tuned Parameters:\n",
  paste(names(instance$result_learner_param_vals), ": ", instance$result_learner_param_vals, collapse = "\n"),
  sep = ""
)

print("OPTIMAL HYPERPARAMETERS:")
cat(best_hyperparams)
