# Titanic Dataset using XGboost


rm(list=ls())  # CLEAR VARIABLES

# Set your working directory here
setwd("~/Desktop/Data Science/Portfolio/Kaggle Competitions/Titanic/Submittals")


# Reading in the data
train.data = read.csv("train.csv", na.strings=c("NA", ""))  # READ THE FILE
test.data = read.csv("test.csv", na.strings=c("NA", ""))  # READ THE FILE


# Combining the data for pre-processing

train.data.temp = subset(train.data, select = -Survived)

pre_proc = rbind(train.data.temp, test.data)


# Detecting missing values for 'Age'
sum(is.na(pre_proc$Age) == TRUE)  # NUMBER OF MISSING VALUES FOR Age IS 177
sum(is.na(pre_proc$Age) == TRUE) / length(pre_proc$Age) # PERCENTAGE OF MISSING VALUES IS 20%


# Getting a percentage of missing values for all features
sapply(pre_proc, function(df) {
  sum(is.na(df) == TRUE) / length(df)
})

# Cabin has too many missing values, imputing probably won't help, so I'm dropping this feature
pre_proc = subset(pre_proc, select = -Cabin)

# Imputing for Fare
pre_proc$Fare[is.na(pre_proc$Fare)] = 0
pre_proc$Fare[ pre_proc$Fare == 0] = median(pre_proc$Fare)



# # Imputing for Age is a little more complicated
# # First I'll impute using the median, later on I'll try imputing using the median based on name title
# # Imputing for Fare
# head(pre_proc$Age)
# pre_proc$Age[is.na(pre_proc$Age)] = 0
# pre_proc$Age[ pre_proc$Age == 0] = median(pre_proc$Age)
# head(pre_proc$Age)


# Simplifying the model down even further 

pre_proc = subset(pre_proc, select = -Ticket) 
pre_proc = subset(pre_proc, select = -Parch) 
pre_proc = subset(pre_proc, select = -Embarked) 
pre_proc = subset(pre_proc, select = -SibSp)
pre_proc = subset(pre_proc, select = -PassengerId)



# I'm going to impute using the various titles in the names 

# Discovering the titles for the 'Name' feature, ie Mr., Mrs., Ms., etc.
pre_proc$Name = as.character(pre_proc$Name) #CHANGING TO CHARACTER TYPE
table_words = table(unlist(strsplit(pre_proc$Name, "\\s+"))) 
sort(table_words [grep('\\.',names(table_words))],decreasing=TRUE)


# Discovering Titles that have missing values for 'Age'
library(stringr)
tb = cbind(pre_proc$Age, str_match(pre_proc$Name, "[a-zA-Z]+\\."))
table(tb[is.na(tb[,1]),2])
# Titles with missing values for Age: "Dr., Master., Miss., Mr., Mrs.


# Imputing missing values for 'Age' based on the median
#
# Finding the median
median.mr = median(pre_proc$Age[grepl(" Mr\\.", pre_proc$Name) & !is.na(pre_proc$Age)])
median.master = median(pre_proc$Age[grepl(" Master\\.", pre_proc$Name) & !is.na(pre_proc$Age)])
median.miss = median(pre_proc$Age[grepl(" Miss\\.", pre_proc$Name) & !is.na(pre_proc$Age)])
median.dr = median(pre_proc$Age[grepl(" Dr\\.", pre_proc$Name) & !is.na(pre_proc$Age)])
median.mrs = median(pre_proc$Age[grepl(" Mrs\\.", pre_proc$Name) & !is.na(pre_proc$Age)])
median.ms = median(pre_proc$Age[grepl(" Ms\\.", pre_proc$Name) & !is.na(pre_proc$Age)])


# Assigning the values
pre_proc$Age[grepl(" Mr\\.", pre_proc$Name) & is.na(pre_proc$Age)] = median.mr
pre_proc$Age[grepl(" Master\\.", pre_proc$Name) & is.na(pre_proc$Age)] = median.master
pre_proc$Age[grepl(" Miss\\.", pre_proc$Name) & is.na(pre_proc$Age)] = median.miss
pre_proc$Age[grepl(" Dr\\.", pre_proc$Name) & is.na(pre_proc$Age)] = median.dr
pre_proc$Age[grepl(" Mrs\\.", pre_proc$Name) & is.na(pre_proc$Age)] = median.mrs
pre_proc$Age[grepl(" Ms\\.", pre_proc$Name) & is.na(pre_proc$Age)] = median.ms

# Checking to make sure that we don't have any missing data 
sapply(pre_proc, function(df) {
  sum(is.na(df) == TRUE) / length(df)
})

# Removing the Name attribute
pre_proc = subset(pre_proc, select = -Name)

# splitting the data back into the trainset and testset 

trainset = pre_proc[1:dim(train.data)[1],]
testset = pre_proc[ (dim(train.data)[1]+1):(dim(pre_proc)[1]),]


# XGboost -- Extreme Gradient Boosting Algo
# Source:  https://xgboost.readthedocs.org/en/latest/R-package/discoverYourData.html#preparation-of-the-dataset
library(xgboost)
library(data.table)
library(Matrix)
library(Ckmeans.1d.dp)


# Pre-processing the data for Xgboost
#
# Pre-processing 'trainset'
df <- data.table(trainset, keep.rownames = F) # Xgboost performs better with data.table

str(df)

# "One-hot encoding" for categorical variables
# Purpose is to transform each value of each categorical feature in a binary feature {0,1}

# We exclude "Survived" because it will be our "label" column, ie the one we want to predict
sparse_matrix <- sparse.model.matrix(~., data = df)

# Creating the prediction vector
len = length(df[,train.data$Survived])

output_vector = as.numeric(train.data$Survived)


# Cross Validation with Xgboost
set.seed(10)
dtrain <- xgb.DMatrix(sparse_matrix, label = output_vector)
history <- xgb.cv(data = dtrain, nround = 300, nthread = 1, eta = 0.001, max.depth = 3, nfold = 10, metrics = list("error"),
                   objective = "binary:logistic", verbose = F)
history # Test accuracy is around 82%
max(history$test.error.mean)

# Building the model
bst <- xgboost(data = sparse_matrix, label = output_vector, max.depth = 3,
               eta = 0.001, nthread = 1, nround = 300, max.depth = 3, objective = "binary:logistic")


# Measuring feature importance
importance <- xgb.importance(feature_names = sparse_matrix@Dimnames[[2]], model = bst)
head(importance)

# Gain
#
# Gain is the improvement in accuracy brought by a feature to the branches it is on.
# The idea is that before adding a new split on a feature X to the branch there was
# some wrongly classified elements, after adding the split on this feature, there are two new branches,
# and each of these branches is more accurate (one branch sayhing if your observation is on this 
# branch then it should be classified as 1, and the other branch saying the exact opposite)

# Cover
#
# Cover measures the relative quantity of observations concerned by a feature

# Frequency
#
# Frequency is a simpler way to measure the Gain.  It just counts the number of times 
# a feature is used in all generated trees.  You should not use it (unless you know why 
# you want to use it)



# Improvement in the interpretability of feature importance
importanceRaw <- xgb.importance(feature_names = sparse_matrix@Dimnames[[2]], model = bst, data = sparse_matrix, label = output_vector)

# Removing two not needed columns, "Cover" and "Frequence"
importanceClean <- importanceRaw[,':='(Cover=NULL, Frequence=NULL)]

head(importanceClean)

# Split is the split applied to the feature on a branch of one of the trees.  Features can appear several times.
# Split is always applied as less than ( < ) to count the co-occurrences
# For example, Feature 'Age' has a split of 9.5, with a RealCover of 131
# This means there are 131 occurrences where children less than 9.5 survived (Survived = 1)
# This logically makes sense (women and children survived more than men)

# Plotting the feature importance
xgb.plot.importance(importance_matrix = importanceRaw)


# Looking at Chi^2
# Higher Chi^2 means better correlation

c2_Sex <- chisq.test(df$Sex, output_vector)
print(c2_Sex)

# c2_Age <- chisq.test(df$Age, output_vector)
# print(c2_Age)



#--------------------------------------------------------------------------------------------------------------
# Making predictions on the test set


# Pre-processing the testset data for Xgboost
#
# Pre-processing 'testset'
df_t <- data.table(testset, keep.rownames = F) # Xgboost performs better with data.table



# "One-hot encoding" for categorical variables
# Purpose is to transform each value of each categorical feature into a binary feature {0,1}

# We exclude "Survived" because it will be our "label" column, ie the one we want to predict
sparse_matrix_t <- sparse.model.matrix(~., data = df_t)
#---------------------------------------------------------------------------------------------------------------


test.fit = predict(bst, sparse_matrix_t)
prediction = as.numeric(test.fit > 0.5) 

# Create dataframe for submission
id <- test.data$PassengerId

solution <- data.frame(PassengerId = id, Survived = prediction)


# Write to csv file
write.csv(solution, file = "Xgboost_tuned", row.names = FALSE, quote = F)
 





