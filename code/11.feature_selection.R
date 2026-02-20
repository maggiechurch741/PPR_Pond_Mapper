library(tidyverse)
library(mlr3spatiotempcv)
library(mlr3learners)
library(mlr3fselect)
library(mlr3pipelines)
library(parallelly)
library(future)
library(here)

# Author: Maggie Church
# Updated: 2026-02-19

# Description: This script selects a parsimonious, uncorrelated feature set
# 
# Inputs: final training data (created in script #10)
#
# Steps: 
#   1. run cross-validated recursive feature elimination (CV-RFE) to get the top feature
#   2. remove all features that are >0.9 correlated with the top feature
#   3. run CV-RFE again to get the 2nd top feature
#   4. remove features correlated with it
#   5. etc etc until performance plateaus
# 
# Outputs: ... selected features
#                                                                                                                                            
# Note: I could programatically find the reduced feature set, but I'd rather do a semi-manual selection 
# Note: I actually run cv_rfe in an HPC, save the results to csv, then remove features correlated with the most recently selected feature. Below is a sort of record of that process
# Note: the 0.9 correlation threshold was arbitrary
#


# Read in training data
train <- read_csv(here("data/train_test_data/balanced_training/training_2wk_200pt_bal.csv")) |> 
  filter(!is.na(NDRE) & !is.na(NDMI2))

# full featureset
featureset <- c("VV","swir1","TCW","swir2","NDMI2","spei30d","NDRE", "NDVI",
                "sp30d_2","red","sp30d_1","nir","wt30_10","VVVH_rt",
                "wt90_10","green","z_2","NDWI","z_1","ABWI","h90_100","VH",
                "TCB","NDMI1","blue","h30_100","mNDWI2","mNDWI1","TCG",
                "rd_dg_1","z","rd_dg_2","rd_dg_3","NDPI","BU3","AWEI",
                "AWEISH","BSI","DVW","DVI","IFW","IPVI","MIFW","OSAVI","SAVI",
                "RVI","TVI","WRI","WTI", "VARI", "BGR", "GRR", "RBR", "SRBI", "NPCRI",
                "EVI3b", "EVI2b") 

#######################################################################
# function to find features that are correlated > 0.9
find_corr <- function(dat, featureset, var){
  dat |> 
    select(all_of(featureset)) |>
    cor() |> 
    as.data.frame() |> 
    select(var) |> 
    filter(abs(.) > 0.9) |>
    filter(rownames(.) != var) |> 
    rownames()
}

#######################################################################
# function to run cross-validated recursive feature elimination 

cv_rfe <- function(df){
  set.seed(123) 
  
  # set up task
  task <- 
    df |> 
    dplyr::select(all_of(feats), type, block) |> 
    dplyr::mutate(type=as.factor(type)) |>  
    mlr3::as_task_classif(target="type", 
                          positive="wet")
  
  # instantiate leave-one-block-out resampling method
  rsmp_lobo <- mlr3::rsmp("loo")
  task$set_col_roles("block", add_to = "group")
  rsmp_lobo$instantiate(task)
  
  # limit task to our predictors
  task <- task$select(feats)
  
  # check that each block will be used as a test set once 
  stopifnot(rsmp_lobo$iters == n_distinct(df$block))
  
  # setup parallel processing
  w <- parallelly::availableCores()
  future::plan("multisession", workers=w)
  
  print(paste("NUMBER OF PARALLEL PROCESSES:", w))
  
  # specify algorithm - here I use random forest
  #   default max.depth is unlimited. a higher depth will be more complex, 10 is still pretty-high end, and hopefully helps with efficiency.
  #   More trees provide more robust and stable error estimates and variable importance measures; however, the impact on computation time increases linearly with the number of trees.
  lrn_rf = mlr3::lrn("classif.ranger", predict_type = "prob", 
                     importance = "impurity", num.trees = 500, max.depth = 10)
  
  # specify feature selection method
  fselector = fs("rfecv",
                 feature_number = 1,  # n features removed in each elimination
                 n_features = 1)      # selection stops there's n_features left
  
  # set up the feature selection process
  instance = fsi(
    task =  task,
    learner = lrn_rf,               # our RF learner
    resampling = rsmp_lobo,         # our custom leave-one-block-out resampling strategy
    measure = msr("classif.auc"),   # feature selection will aim to optimize AUC 
    terminator = trm("none"),
    store_benchmark_result = FALSE, # had to set this to F for memory efficiency
    store_models = TRUE             # needed to assess RFE, when the above is F
  )
  
  # execute feature selection process
  fselector$optimize(instance)
  
  # get the RFE archive
  rfe = as.data.table(instance$archive)[!is.na(iteration), ]
  
  return(rfe)
}

########## BELOW IS A RECORD OF MY FEATURE SELECTION PROCESS ########## 
# # first selected var is swir1
# swir1_corr <- find_corr(train, featureset1, var="swir1")
# 
# featureset2 <- featureset1 |>
#   setdiff(swir1_corr) 
#
# # second selected var is NDRE
# ndre_corr <- find_corr(train, featureset2, var="NDRE") # none
#   
# # third + fourth selected var is a tie between TCG and WTI
# tcg_corr <- find_corr(train, featureset2, var="TCG") # none
# wti_corr <- find_corr(train, featureset2, var="WTI")
# 
# featureset3 <- featureset2 |>
#   setdiff(wti_corr) 
# 
# # fifth + sixth selected vars are IFW and VH
# vh_corr <- find_corr(train, featureset3, var="VH") 
# ifw_corr <- find_corr(train, featureset3, var="IFW") 
# 
# featureset4 <- featureset3 |>
#   setdiff(vh_corr) |>
#   setdiff(ifw_corr) 
# 
# # seventh selected var is BU3 
# # eighth is TVI
# bu3_corr <- find_corr(train, featureset4, var="BU3") 
# tvi_corr <- find_corr(train, featureset4, var="TVI") 
# 
# featureset5 <- featureset4 |>
#   setdiff(tvi_corr) 

feats <- featureset


