library(tidyverse)
library(mlr3spatiotempcv)
library(mlr3learners)
library(mlr3fselect)
library(viridis)
library(parallelly)
library(future)
library(mlr3pipelines)
library(here)

# Read in training data
train <- read_csv(here("data", "train_test_data", "unbalanced_training", "training_2wk_200pt.csv")) %>% 
  distinct()

# Hmm 400 plot-surveys still had <100 wet sample points
train_wet_100 <- train %>% 
  filter(type=="wet") %>%
  group_by(dataset, plot_id) %>% 
  summarize(n=n())
  

train_sub <- train %>% 
  filter(!is.na(NDRE)) %>% 
  sample_frac(.001) 

# this has 9 folds
table(train$block, train$type)

featureset <- c("VV","swir1","TCW","swir2","NDMI2","spei30d","NDRE", "NDVI",
                "spei30d_2","red","spei30d_1","nir","water30_10","VVVH_ratio",
                "water90_10","green","z_2","NDWI","z_1","ABWI","hand90_100","VH",
                "TCB","NDMI1","blue","hand30_100","mNDWI2","mNDWI1","TCG",
                "red_edge_1","z","red_edge_2","red_edge_3","NDPI","BU3","AWEI",
                "AWEISH","BSI","DVW","DVI","IFW","IPVI","MIFW","OSAVI","SAVI",
                "RVI","TVI","WRI","WTI", "VARI", "BGR", "GRR", "RBR", "SRBI", "NPCRI",
                "EVI3b", "EVI2b")  

feats <- featureset
n_feat <- 1

set.seed(123) 

# set up task
task <- 
  train_sub %>% 
  select(all_of(feats), type, block) %>% 
  mutate(type=as.factor(type)) %>%  
  as_task_classif(target="type", 
                  positive="wet")

# instantiate leave-one-block-out resampling method
rsmp_lobo <- rsmp("loo")
task$set_col_roles("block", add_to = "group")
rsmp_lobo$instantiate(task)

#########

instance = fselect(
  fselector = fs("sequential"),
  task =  task,
  learner = lrn_rf,
  resampling = rsmp_lobo,
  measure = msr("classif.auc")
)
#########
# limit task to our predictors
task <- task$select(feats)

# check that each block will be used as a test set once 
stopifnot(rsmp_lobo$iters == n_distinct(train$block))

# setup parallel processing
w <- availableCores()
plan("multisession", workers=w)

print(paste("NUMBER OF PARALLEL PROCESSES:", w))

# specify algorithm - here I use random forest
# default max.depth is unlimited. a higher depth will be more complex, 10 is still pretty-high end, and hopefully helps with efficiency.
# num.trees: a good rule of thumb is to start with 10 times the number of features
# More trees provide more robust and stable error estimates and variable importance measures; however, the impact on computation time increases linearly with the number of trees.
lrn_rf = lrn("classif.ranger", predict_type = "prob"
             , importance = "impurity"
             , num.trees = 500, max.depth = 10)

# specify fallback method for inner resampling
lrn_rf$fallback = lrn("classif.featureless", predict_type = "prob")

# specify feature selection method
fselector = fs("rfecv",
               feature_number = 1,      # 1 feature is removed in each elimination
               n_features = n_feat)         # selection stops there's n_features left

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

write_csv(rfe, here("data", "intermediate", "mlr3", "rfe_output.csv"))

