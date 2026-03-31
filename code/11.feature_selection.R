library(tidyverse)
library(mlr3spatiotempcv)
library(mlr3learners)
library(mlr3fselect)
library(mlr3pipelines)
library(parallelly)
library(future)
library(here)

# Author: Maggie Church
# Updated: 2026-02-21

# Description: This script selects a parsimonious, uncorrelated feature set
# 
# Inputs: final training data (created in script #10)
#
# Steps: 
#   1. run cross-validated recursive feature elimination (CV-RFE) to get the top feature
#   2. remove all features that are >0.88 correlated with the top feature
#   3. run CV-RFE again to get the 2nd top feature
#   4. remove features correlated with it
#   5. etc etc until performance plateaus
# The comments at the bottom of this script document this process.
# 
# Outputs: results of cv-rfe runs
#                                                                                                                                            
# Note: I could programatically find the reduced feature set, but I'd rather do a semi-manual selection 
# Note: Ideally I'd run repetitions, since this feature selection process has some stochasticity,
#       but with 57 features and 9 folds it already takes a very long time
# Note: the 0.88 correlation threshold was arbitrary
# Note: I ran this in an HPC, saving the results of each cv-rfe run to csv (this 
#       uses all nodes available, so be careful if running on a desktop)

# 
output_folder <- here("data/intermediate/feature_selection/")
stopifnot(dir.exists(output_folder))

# Read in training data
train <- read_csv(here("data/train_test_data/balanced_training/training_bal.csv"))

# full featureset
full_featureset <- c("VV","swir1","TCW","swir2","NDMI2","spei30d","NDRE", "NDVI",
                "sp30d_2","red","sp30d_1","nir","wt30_10","VVVH_rt",
                "wt90_10","green","z_2","NDWI","z_1","ABWI","h90_100","VH",
                "TCB","NDMI1","blue","h30_100","mNDWI2","mNDWI1","TCG",
                "rd_dg_1","z","rd_dg_2","rd_dg_3","NDPI","BU3","AWEI",
                "AWEISH","BSI","DVW","DVI","IFW","IPVI","MIFW","OSAVI","SAVI",
                "RVI","TVI","WRI","WTI", "VARI", "BGR", "GRR", "RBR", "SRBI", "NPCRI",
                "EVI3b", "EVI2b") 

#######################################################################
# function to find features that are correlated > 0.88
find_corr <- function(dat, featureset, var){
  cor_mat <- dat |>
    dplyr::select(all_of(featureset)) |>
    cor()
  
  cor_vals <- cor_mat[, var]
  
  names(cor_vals)[
    abs(cor_vals) > 0.88 &
      names(cor_vals) != var
  ]
}

#######################################################################
# function to run cross-validated recursive feature elimination (in parallel)
cv_rfe <- function(df, feats, runnum){
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
  rfe = as.data.table(instance$archive)[!is.na(iteration), ] |>
    mutate(
      n_feat = lengths(features),
      importance = sapply(importance, function(x) paste(x, collapse = ",")),
      features   = sapply(features, function(x) paste(x, collapse = ",")),
      n_features = as.integer(sapply(n_features, function(x) paste(x, collapse = ","))),
      rep = r
    )
  
  # save to disk, for our records
  write_csv(rfe, here(paste0(output_folder,"rfe", runnum,".csv")))
  
  # turn off parallel processing
  future::plan("sequential")
  
  return(rfe)
}


########## BELOW IS A RECORD OF MY FEATURE SELECTION PROCESS ########## 
# I started by tossing spei30d (min, max, mean), topo vars, min palmer-z (min), 
# because their importance was so low, and they were always tossed first in previous
# iterations of this process. It saves a lot of time to widdle down the featureset 

# ########## 1. 
# # Run feature selection - top var is swir1
# rfe0 <- cv_rfe(train, full_featureset, 0)
# 
# # Find features correlated with the top var
# swir1_corr <- find_corr(train, full_featureset, var="swir1")
# 
# # Remove features correlated with the top var
# featureset1 <- full_featureset |> setdiff(swir1_corr) # AWEI, AWEIsh, MIFW, TCB, TCW, swir2

# ########## 2.
# # Run feature selection - top 2 vars are swir1 and NDRE
# rfe1 <- cv_rfe(train, featureset1, 1)
#
# # Find features correlated with the top var - there were none
# ndre_corr <- find_corr(train, featureset1, var="NDRE") # none 
#   
# # In that case, we can pick the 3rd var now: it's a tie between TCG and WTI
# tcg_corr <- find_corr(train, featureset1, var="TCG") # none
# wti_corr <- find_corr(train, featureset1, var="WTI") # red, nir, green, blue, RE1, RE2, RE3, SRBI
# 
# # Remove features correlated with WTI 
# featureset2 <- featureset1 |>  setdiff(wti_corr) 

# ########## 3.
# # Run feature selection: ok now we've got swir1, NDRE, TCG, WTI annnnddddd a tie between IFW and VH
# rfe2 <- cv_rfe(train, featureset2, 2)
# 
# # I think we can just go with both
# vh_corr <- find_corr(train, featureset2, var="VH")    # VV, VV/VH
# ifw_corr <- find_corr(train, featureset2, var="IFW")  # DVI, SAVI, EVI3b, EVI2b
# 
# # Remove features correlated with VH and IFW
# featureset3 <- featureset2 |>
#   setdiff(vh_corr) |>
#   setdiff(ifw_corr) 
#
# ########## 4.
# # Run feature selection: so now we got swir1, NDRE, TCG, WTI, IFW, VH annnddd... BU3!
# rfe3 <- cv_rfe(train, featureset3, 3)
#
# # Seventh selected var is BU3 
# bu3_corr <- find_corr(train, featureset3, var="BU3") # none
#
# # Eighth is TVI
# tvi_corr <- find_corr(train, featureset3, var="TVI") # OSAVI
# 
# featureset4 <- featureset3 |> setdiff(tvi_corr) 
#
# ########## 5.
# # Run feature selection: swir1, NDRE, TCG, WTI, IFW, VH, BU3, TVI annddd - no more, lets be done!
# rfe4 <- cv_rfe(train, featureset4, 4)
# 
# # ok at this point, there's no advantage to having more features! We'll go with those 8 features
# # I did keep going through rfe until only an uncorrelated featureset remained... these 8 features remained at the top

