library(tidyverse)
library(mlr3spatiotempcv)
library(mlr3learners)
library(mlr3fselect)
library(mlr3tuning)
library(mlr3tuningspaces)  
library(parallelly)
library(future)
library(here)


# Author: Maggie Church
# Updated: 2026-02-21

# Description: This script selects the hyperparameters used in the final model
# 
# Inputs: final training data (created in script #10)
#
# Steps: Run cross-validated hyperparameter tuning (CV-RFE) to get the top hyperparameters
# 
# I Tuned the 4 RF hyperparameters that are in GEE (I limited num.trees's tuning ceiling to 500, 
# because any more would take forever to deploy the model)
# 
# Output: printed tuning results
#
# Note: I ran this in an HPC, saving the results of each cv-rfe run to csv (this 
#       uses all nodes available, so be careful if running on a desktop)

set.seed(123) 

# read in training data
train <- read_csv(here("data/train_test_data/balanced_training/training_bal.csv"))

# selected featureset (determined in 11.feature_selection.R)
sel_featureset <- c("swir1", "NDRE", "TCG", "WTI", "IFW", "VH", "BU3", "TVI")

# set up task
task <- 
  train |> 
  select(all_of(sel_featureset), type, block) |> 
  mutate(type=as.factor(type)) |>  
  as_task_classif(target="type", 
                  positive="wet")

# instantiate leave-one-block-out resampling for CV
rsmp_lobo <- rsmp("loo")
task$set_col_roles("block", add_to = "group")
rsmp_lobo$instantiate(task)

# limit task to our selected predictors
task <- task$select(sel_featureset)

# setup parallel processing
w <- availableCores()
plan("multisession", workers=w)

print(paste("NUMBER OF PARALLEL PROCESSES:", w))

# specify algorithm - here I use random forest
lrn_rf = lrn("classif.ranger", 
             predict_type = "prob",
             importance = "impurity",
             replace=TRUE)

# use default tuning space
# search_space = lts("classif.ranger.default") 

# jk, upper num.trees is too high for GEE: limit to 500. Also, just tune the 4 params in GEE 
search_space <- ps(
  classif.ranger.num.trees = p_int(lower = 1, upper = 500),  #"numberofTrees" in GEE
  classif.ranger.mtry = p_int(lower = 1, upper = length(sel_featureset)),  #"variablesPerSplit" in GEE
  classif.ranger.sample.fraction = p_dbl(lower = 0.1, upper = 1),  #"bagFraction" in GEE
  classif.ranger.min.node.size = p_int(lower = 1, upper = 20) # "minLeafPopulation" in GEE
)

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
