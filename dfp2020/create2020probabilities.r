rm(list=ls())

# set dependencies
library(plyr)
library(readr)
library(tidyverse)
library(ggplot2)
library(tidyr)
library(dplyr)
library(reshape2)
library(caret)
library(broom)
library(survey)
library(randomForest)
library(haven)
library(labelled)
library(ggpubr)
library(grid)
library(gridExtra)
library(grDevices)

theme_set(theme_bw())
theme(panel.border = element_blank())

# upload CCES data
cces16 <- read_tsv(file = "~/Dropbox/LikelyVoters/Journal article/Data/CCES16_Common_OUTPUT_Feb2018_VV.tab",
                   col_names = TRUE)
cces12 <- read_tsv(file = "~/Dropbox/LikelyVoters/Journal article/Data/CCES12_Common_VV.tab",
                   col_names = TRUE)
cces08 <- read_tsv(file = "~/Dropbox/LikelyVoters/Journal article/Data/cces_2008_common.tab",
                   col_names = TRUE)
cces10 <- read_dta(file = "~/Dropbox/LikelyVoters/Journal article/Data/cces_2010_common_validated.dta")
cces14 <- read_tsv(file = "~/Dropbox/LikelyVoters/Journal article/Data/CCES14_Common_Content_Validated.tab",
                   col_names = TRUE)
cces18 <- read_dta(file = "~/Dropbox/LikelyVoters/Journal article/Data/CCES18_Common_OUTPUT_vv.dta")
cces20 <- read_csv(file = "~/Dropbox/LikelyVoters/2020 Data/dfp_2020julyb.csv",
                   col_names = TRUE)

# remove variable labels from 2010 CCES
var_label(cces10) <- NULL

# add state abbreviations
states <- data.frame(inputstate = seq(1:56), state_abbreviation = c(
  "AL",
  "AK",
  "",
  "AZ",
  "AR",
  "CA",
  "",
  "CO",
  "CT",
  "DE",
  "D.C.",
  "FL",
  "GA",
  "",
  "HI",
  "ID",
  "IL",
  "IN",
  "IA",
  "KS",
  "KY",
  "LA",
  "ME",
  "MD",
  "MA",
  "MI",
  "MN",
  "MS",
  "MO",
  "MT",
  "NE",
  "NV",
  "NH",
  "NJ",
  "NM",
  "NY",
  "NC",
  "ND",
  "OH",
  "OK",
  "OR",
  "PA",
  "",
  "RI",
  "SC",
  "SD",
  "TN",
  "TX",
  "UT",
  "VT",
  "VA",
  "",
  "WA",
  "WV",
  "WI",
  "WY"))
cces16 <- left_join(cces16, states, by = "inputstate")
cces12 <- left_join(cces12, states, by = "inputstate")
cces08 <- cces08 %>% rename(inputstate = V206)
cces08 <- left_join(cces08, states, by = "inputstate")

# add names of racial groups
race <- data.frame(race = c(1,2,3,4,5,6,7,8,98,99), racial_group = c("White","Black","Hispanic","Asian","Native American",
                                                                     "Mixed","Other","Middle Eastern","Skipped","Not Asked"))
cces16 <- left_join(cces16, race, by = "race")
cces12 <- left_join(cces12, race, by = "race")
cces08 <- cces08 %>% rename(race = V211)
cces08 <- left_join(cces08, race, by = "race")

##############

## upload pooled CCES data
pooled <- readRDS("~/Dropbox/LikelyVoters/Journal article/Data/cumulative_2006_2016 (1).Rds")
# adjust age on pooled
pooled$age <- CUR_YEAR - pooled$birthyr

## 2008
cces08_tojoin <- cces08 %>% select(V100, V246, V217, V214, V244, CC301_2, CC301_3, CC335bush, V203, CC334, CC326, CC324_1, CC324_2) %>% 
  rename(case_id = V100, income = V246, religiosity = V217, marital_status = V214, 
         interest = V244, registration = V203, residential_mobility = CC334, 
         intent = CC326, vote_history_primary = CC324_1, vote_history_caucus = CC324_2)
# incorporate primary and caucus vote history from 2008
cces08_tojoin$vote_history <- 0
cces08_tojoin$vote_history[cces08_tojoin$vote_history_primary == 1 |
                             cces08_tojoin$vote_history_caucus == 1] <- 1
cces08_tojoin <- cces08_tojoin %>% select(-vote_history_primary, -vote_history_caucus)
pooled <- left_join(pooled, cces08_tojoin, by = 'case_id')

## 2012
cces12_tojoin <- cces12 %>% select(V101, faminc, pew_churatd, marstat, newsint,
                                   CC351, votereg, CC308a, CC354, CC316) %>% 
  rename(case_id = V101, income = faminc, religiosity = pew_churatd, marital_status = marstat,
         interest = newsint, residential_mobility = CC351, registration = votereg, 
         intent = CC354, vote_history = CC316)
pooled <- left_join(pooled, cces12_tojoin, by = 'case_id')

## 2016
cces16_tojoin <- cces16 %>% select(V101, faminc, pew_churatd, marstat, newsint,
                                   CC16_361, votereg, CC16_320a, CC16_364, CC16_316, commonweight) %>% 
  rename(case_id = V101, income = faminc, religiosity = pew_churatd, marital_status = marstat,
         interest = newsint, residential_mobility = CC16_361, registration = votereg, 
         intent = CC16_364, vote_history = CC16_316, commonweight = commonweight)
pooled <- left_join(pooled, cces16_tojoin, by = 'case_id')
# replace cumulative file weight with 2016 weight
pooled$weight[pooled$year == 2016] <- pooled$commonweight[pooled$year == 2016]
pooled <- pooled %>% select(-commonweight)

## 2010
cces10_tojoin <- cces10 %>% select(V100, V246, V217, V214, V244, CC351, V203, CC354, CC316, V502) %>% 
  rename(case_id = V100, income = V246, religiosity = V217, marital_status = V214, 
         interest = V244, residential_mobility = CC351, registration = V203, 
         intent = CC354, vote_history = CC316, incumbent_party10 = V502) %>% 
  mutate(case_id = as.integer(case_id))
pooled <- left_join(pooled, cces10_tojoin, by = 'case_id')

## 2014
cces14_tojoin <- cces14 %>% select(V101, faminc, pew_churatd, marstat, newsint, CC351, votereg, CC354, CC14_316, CurrentHouseParty) %>% 
  rename(case_id = V101, income = faminc, religiosity = pew_churatd, marital_status = marstat,
         interest = newsint, residential_mobility = CC351, registration = votereg, 
         intent = CC354, vote_history = CC14_316, incumbent_party14 = CurrentHouseParty)
pooled <- left_join(pooled, cces14_tojoin, by = 'case_id')


## Collapse these variables into one

# income
pooled$income[pooled$year == 2008] <- pooled$income.x[pooled$year == 2008]
pooled$income[pooled$year == 2012] <- pooled$income.y[pooled$year == 2012]
pooled$income[pooled$year == 2016] <- pooled$income.x.x[pooled$year == 2016]
pooled$income[pooled$year == 2010] <- pooled$income.y.y[pooled$year == 2010]

# religiosity
pooled$religiosity[pooled$year == 2008] <- pooled$religiosity.x[pooled$year == 2008]
pooled$religiosity[pooled$year == 2012] <- pooled$religiosity.y[pooled$year == 2012]
pooled$religiosity[pooled$year == 2016] <- pooled$religiosity.x.x[pooled$year == 2016]
pooled$religiosity[pooled$year == 2010] <- pooled$religiosity.y.y[pooled$year == 2010]

# marital status
pooled$marital_status[pooled$year == 2008] <- pooled$marital_status.x[pooled$year == 2008]
pooled$marital_status[pooled$year == 2012] <- pooled$marital_status.y[pooled$year == 2012]
pooled$marital_status[pooled$year == 2016] <- pooled$marital_status.x.x[pooled$year == 2016]
pooled$marital_status[pooled$year == 2010] <- pooled$marital_status.y.y[pooled$year == 2010]

# interest
pooled$interest[pooled$year == 2008] <- pooled$interest.x[pooled$year == 2008]
pooled$interest[pooled$year == 2012] <- pooled$interest.y[pooled$year == 2012]
pooled$interest[pooled$year == 2016] <- pooled$interest.x.x[pooled$year == 2016]
pooled$interest[pooled$year == 2010] <- pooled$interest.y.y[pooled$year == 2010]

# residential mobility
pooled$residential_mobility[pooled$year == 2008] <- pooled$residential_mobility.x[pooled$year == 2008]
pooled$residential_mobility[pooled$year == 2012] <- pooled$residential_mobility.y[pooled$year == 2012]
pooled$residential_mobility[pooled$year == 2016] <- pooled$residential_mobility.x.x[pooled$year == 2016]
pooled$residential_mobility[pooled$year == 2010] <- pooled$residential_mobility.y.y[pooled$year == 2010]

# registration
pooled$registration[pooled$year == 2008] <- pooled$registration.x[pooled$year == 2008]
pooled$registration[pooled$year == 2012] <- pooled$registration.y[pooled$year == 2012]
pooled$registration[pooled$year == 2016] <- pooled$registration.x.x[pooled$year == 2016]
pooled$registration[pooled$year == 2010] <- pooled$registration.y.y[pooled$year == 2010]

# intent
pooled$intent[pooled$year == 2008] <- pooled$intent.x[pooled$year == 2008]
pooled$intent[pooled$year == 2012] <- pooled$intent.y[pooled$year == 2012]
pooled$intent[pooled$year == 2016] <- pooled$intent.x.x[pooled$year == 2016]
pooled$intent[pooled$year == 2010] <- pooled$intent.y.y[pooled$year == 2010]

# vote history
pooled$vote_history[pooled$year == 2008] <- pooled$vote_history.x[pooled$year == 2008]
pooled$vote_history[pooled$year == 2012] <- pooled$vote_history.y[pooled$year == 2012]
pooled$vote_history[pooled$year == 2016] <- pooled$vote_history.x.x[pooled$year == 2016]
pooled$vote_history[pooled$year == 2010] <- pooled$vote_history.y.y[pooled$year == 2010]


## Recode variables

# intent
# 2010
pooled$intent[pooled$year == 2010 & pooled$intent == 4] <- 5 #undecided to undecided
pooled$intent[pooled$year == 2010 & pooled$intent == 3] <- 4 #no to no
# 2012
pooled$intent[pooled$year == 2012 & pooled$intent == 4] <- 1 #plan to vote to definitely vote
pooled$intent[pooled$year == 2012 & pooled$intent == 5] <- 4 #no to no
pooled$intent[pooled$year == 2012 & pooled$intent == 6] <- 5 #undecided to undecided
# 2014
pooled$intent[pooled$year == 2014 & pooled$intent == 4] <- 1 #plan to vote to definitely vote
pooled$intent[pooled$year == 2014 & pooled$intent == 5] <- 4 #no to no
pooled$intent[pooled$year == 2014 & pooled$intent == 6] <- 5 #undecided to undecided

# registration
pooled$registration[pooled$registration == 1] <- 1
pooled$registration[pooled$registration == 2 | pooled$registration == 3] <- 0

# vote history 
# 2008
pooled$vote_history[pooled$year == 2008 & pooled$vote_history == 2] <- 0
# 2010
pooled$vote_history[pooled$year == 2010 & (pooled$vote_history == 1 | pooled$vote_history == 2 | pooled$vote_history == 3)] <- 0
pooled$vote_history[pooled$year == 2010 & pooled$vote_history == 4 ] <- 1
# 2012
pooled$vote_history[pooled$year == 2012 & (pooled$vote_history == 1 | pooled$vote_history == 2 | pooled$vote_history == 3)] <- 0
pooled$vote_history[pooled$year == 2012 & pooled$vote_history == 4 ] <- 1
# 2014
pooled$vote_history[pooled$year == 2014 & (pooled$vote_history == 1 | pooled$vote_history == 2 | pooled$vote_history == 3)] <- 0
pooled$vote_history[pooled$year == 2014 & pooled$vote_history == 4 ] <- 1
# 2016
pooled$vote_history[pooled$year == 2016 & (pooled$vote_history == 1 | pooled$vote_history == 2 | pooled$vote_history == 3)] <- 0
pooled$vote_history[pooled$year == 2016 & pooled$vote_history == 4] <- 1

# interest
# 2016
pooled$interest[pooled$interest == 7] <- 4

# income
# 2016
pooled$income_new[pooled$year == 2016 & pooled$income %in% c(1,2,3,4)] <- 1 #under 40k
pooled$income_new[pooled$year == 2016 & pooled$income %in% c(5,6,7,8,9)] <- 2 #40 to 100k
pooled$income_new[pooled$year == 2016 & pooled$income %in% c(10,11,12,13,14,15,16,31)] <- 3 #over 100k
pooled$income_new[pooled$year == 2016 & pooled$income == 97] <- 4 #prefer not to say
# 2012
pooled$income_new[pooled$year == 2012 & pooled$income %in% c(1,2,3,4)] <- 1 #under 40k
pooled$income_new[pooled$year == 2012 & pooled$income %in% c(5,6,7,8,9)] <- 2 #40 to 100k
pooled$income_new[pooled$year == 2012 & pooled$income %in% c(10,11,12,13,14,15,16,31,32)] <- 3 #over 100k
pooled$income_new[pooled$year == 2012 & pooled$income == 97] <- 4 #prefer not to say
# 2008
pooled$income_new[pooled$year == 2008 & pooled$income %in% c(1,2,3,4,5,6)] <- 1 #under 40k
pooled$income_new[pooled$year == 2008 & pooled$income %in% c(7,8,9,10,11)] <- 2 #40 to 100k
pooled$income_new[pooled$year == 2008 & pooled$income %in% c(12,13,14)] <- 3 #over 100k
pooled$income_new[pooled$year == 2008 & pooled$income == 15] <- 4 #prefer not to say
# 2010
pooled$income_new[pooled$year == 2010 & pooled$income %in% c(1,2,3,4,5,6)] <- 1 #under 40k
pooled$income_new[pooled$year == 2010 & pooled$income %in% c(7,8,9,10,11)] <- 2 #40 to 100k
pooled$income_new[pooled$year == 2010 & pooled$income %in% c(12,13,14)] <- 3 #over 100k
pooled$income_new[pooled$year == 2010 & pooled$income == 15] <- 4 #prefer not to say
# 2014
pooled$income_new[pooled$year == 2014 & pooled$income %in% c(1,2,3,4)] <- 1 #under 40k
pooled$income_new[pooled$year == 2014 & pooled$income %in% c(5,6,7,8,9)] <- 2 #40 to 100k
pooled$income_new[pooled$year == 2014 & pooled$income %in% c(10,11,12,13,14,15,16,31,32)] <- 3 #over 100k
pooled$income_new[pooled$year == 2014 & pooled$income == 97] <- 4 #prefer not to say

# marital status
pooled$marital_status[pooled$marital_status %in% c(2,3,4,6)] <- 3 #other
pooled$marital_status[pooled$marital_status == 5] <- 2 #single

# partisan strength
pooled$partisan_strength[pooled$pid7 %in% c(1,7)] <- 1 #very strong
pooled$partisan_strength[pooled$pid7 %in% c(2,6)] <- 2 #strong
pooled$partisan_strength[pooled$pid7 %in% c(3,5)] <- 3 #moderate
pooled$partisan_strength[pooled$pid7 %in% c(4,8)] <- 4 #weak

# race
pooled$race[pooled$race %in% c(7,8)] <- 6 #send Middle Eastern and Mixed to Other
pooled$race[pooled$race %in% c(7,8)] <- 6

## exclude Rs who were not asked these questions and other NA values
# intent
pooled <- pooled[pooled$intent <= 5,]
pooled <- pooled[pooled$intent!='__NA__',]
pooled <- pooled[!is.na(pooled$intent),]
# vote history
pooled <- pooled[pooled$vote_history <= 2,]
pooled <- pooled[!is.na(pooled$vote_history),]
#registration
pooled <- pooled[!is.na(pooled$registration),]
# interest 
pooled <- pooled[pooled$interest <= 5,]
pooled <- pooled[!is.na(pooled$interest),]
# income
pooled <- pooled[!pooled$income %in% c(20874,46814,94114),]
pooled <- pooled[!is.na(pooled$income),]
# religiosity
pooled <- pooled[pooled$religiosity <= 7,]
pooled <- pooled[!is.na(pooled$religiosity),]
# marital status
pooled <- pooled[!pooled$marital_status %in% c(8,9),]
pooled <- pooled[!is.na(pooled$marital_status),]
# residential mobility
pooled <- pooled[!pooled$residential_mobility %in% c(8,9),]
pooled <- pooled[!is.na(pooled$residential_mobility),]
# partisanship
pooled <- pooled[!is.na(pooled$pid7),]
# education
pooled <- pooled[!is.na(pooled$educ),]

## consider Rs with no voter file as having no record of voting and drop this empty class
pooled$vv_turnout_gvm[pooled$vv_turnout_gvm == 'No Voter File'] <- 'No Record Of Voting'
pooled$vv_turnout_gvm <- factor(pooled$vv_turnout_gvm)

## select relevant variables and filter years of interest
pooled <- pooled %>% filter(year %in% c(2008, 2010, 2012, 2014, 2016)) %>% 
  select(year, case_id, weight, state, gender, age, race, educ, vv_turnout_gvm, 
         intent_pres_16, intent_rep, intent_sen, intent_gov, vote_history, intent, income_new, interest,registration, 
         religiosity, marital_status, residential_mobility, intent, partisan_strength
         #,gdp_growth, approval, incumbent, polarization
  ) %>% 
  rename(education = educ, validated = vv_turnout_gvm, choice = intent_pres_16) %>% 
  mutate(validated = as.factor(validated),     # set all categorical variables as factors
         vote_history = as.factor(vote_history),
         intent = factor(intent),
         interest = as.factor(interest),
         registration = as.factor(registration),
         gender = as.factor(gender),
         race = as.factor(race),
         education  = as.factor(education),
         income_new = as.factor(income_new),
         religiosity = as.factor(religiosity),
         marital_status = as.factor(marital_status),
         residential_mobility = as.factor(residential_mobility),
         partisan_strength = as.factor(partisan_strength)
         #,
         #incumbent = as.factor(incumbent),
         #polarization = as.factor(polarization)
  )


# calculate Prerry-Gallup index
# initialize Perry-Gallup index
pooled <- pooled %>% mutate(perry_gallup = 0)

# vote intent
pooled$perry_gallup[!is.na(pooled$intent) & (pooled$intent == 1 | pooled$intent == 3)] <- pooled$perry_gallup[!is.na(pooled$intent) & (pooled$intent == 1 | pooled$intent == 3)]  + 2
pooled$perry_gallup[!is.na(pooled$intent) & pooled$intent == 2]  <- pooled$perry_gallup[!is.na(pooled$intent) & pooled$intent == 2] + 1

# vote history
pooled$perry_gallup[!is.na(pooled$vote_history) & pooled$vote_history == 1] <- pooled$perry_gallup[!is.na(pooled$vote_history) & pooled$vote_history == 1] + 1

# political interest
pooled$perry_gallup[!is.na(pooled$interest) & pooled$interest == 1] <- pooled$perry_gallup[!is.na(pooled$interest) & pooled$interest == 1] + 2
pooled$perry_gallup[!is.na(pooled$interest) & pooled$interest == 2] <- pooled$perry_gallup[!is.na(pooled$interest) & pooled$interest == 2] + 1

# voter registration 
pooled$perry_gallup[pooled$registration == 1] <- pooled$perry_gallup[pooled$registration == 1] + 1

# age adjustment
pooled$perry_gallup[pooled$age < 22 && pooled$vote_history == 0] <- pooled$perry_gallup[pooled$age < 22 && pooled$vote_history == 0] + 1


# create eligible variable, to be used in logistic regression Perry-Gallup section
pooled <- pooled %>% mutate(eligible = 0)
pooled$eligible[pooled$year %in% c(2008, 2012) & pooled$age < 22] <- 0
pooled$eligible[pooled$year %in% c(2008, 2012) & pooled$age >= 22] <- 1
pooled$eligible[pooled$year %in% c(2010, 2014) & pooled$age < 20] <- 0
pooled$eligible[pooled$year %in% c(2010, 2014) & pooled$age >= 20] <- 1
pooled$eligible[pooled$year == 2016 & pooled$age < 22] <- 0
pooled$eligible[pooled$year == 2016 & pooled$age >= 22] <- 1
pooled$eligible <- as.factor(pooled$eligible)

# Force gender and age into factors
pooled$gender <- as.factor(pooled$gender)
pooled$race <- as.factor(pooled$race)

# remove data from VA '08 and '10 because of no vote history
va_08_10 <- pooled %>% filter(state=='Virginia', year %in% c(2008,2010))
pooled <- anti_join(pooled, va_08_10, by='case_id')

####### RECODE 2018 DATA #######
## all obs with NA values are removed 
## --> about 2k obs dropped due to missing values

new18 <- cces18

# intent - CC18_350
new18$intent[new18$CC18_350==1 | new18$CC18_350==4] <- 1
new18$intent[new18$CC18_350 == 2] <- 2
new18$intent[new18$CC18_350 == 3] <- 3
new18$intent[new18$CC18_350 == 5] <- 4
new18$intent[new18$CC18_350 == 6] <- 5
new18 <- new18[!is.na(new18$intent),]
new18$intent <- factor(new18$intent)

# vote history - CC18_316 
new18$vote_history[new18$CC18_316==1] <- 1
new18$vote_history[new18$CC18_316==2] <- 0
new18$vote_history[new18$CC18_316 == 3] <- 0
new18 <- new18[!is.na(new18$vote_history),]
new18$vote_history <- as.factor(new18$vote_history)

# interest - newsint
new18$interest[new18$newsint==1] <- 1
new18$interest[new18$newsint==2] <- 2
new18$interest[new18$newsint==3] <- 3
new18$interest[new18$newsint>3] <- 4
new18 <- new18[!is.na(new18$interest),]
new18$interest <- as.factor(new18$interest)

# registration - votereg
new18$registration[new18$votereg==1] <- 1
new18$registration[new18$votereg >1] <- 0
new18 <- new18[!is.na(new18$registration),]
new18$registration <- as.factor(new18$registration)

# gender - gender
new18 <- new18[!is.na(new18$gender),]
new18$gender <- as.factor(new18$gender)

# age - birthyr
new18$age <- 2018 - new18$birthyr
new18$age <- as.integer(new18$age)

# race - race
new18$race[new18$race>4] <- 5
new18 <- new18[!is.na(new18$race),]
new18$race <- as.factor(new18$race)

# educ - educ
new18$education <- new18$educ 
new18 <- new18[!is.na(new18$education),]
new18$education <- as.factor(new18$education)

# income - faminc_new
new18$income_new[new18$faminc_new<5] <- 1
new18$income_new[new18$faminc_new>4 & new18$faminc_new<10] <- 2
new18$income_new[new18$faminc_new>9 & new18$faminc_new<97] <- 3
new18$income_new[new18$faminc_new == 97] <- 4
new18 <- new18[!is.na(new18$income_new),]
new18$income_new <- as.factor(new18$income_new)

# partisan strength - pid7
new18$partisan_strength[new18$pid7==1 | new18$pid7==7] <- 1
new18$partisan_strength[new18$pid7==2 | new18$pid7==6] <- 2
new18$partisan_strength[new18$pid7==3 | new18$pid7==5] <- 3
new18$partisan_strength[new18$pid7==4 | new18$pid7==8] <- 4
new18 <- new18[!is.na(new18$partisan_strength),]
new18$partisan_strength <- as.factor(new18$partisan_strength)

# Validated vote
new18$validated <- "No Record Of Voting"
new18$validated[!is.na(new18$CL_2018gvm)] <- "Voted"
new18$validated <- as.factor(new18$validated)

new18$year <- 2018

new18 <- subset(new18, select=c("vote_history","intent","interest","registration","gender","age","race","education","income_new","partisan_strength","year", "validated"))


####### END 2018 RECODE ####### 

# add 2018 to rest of pooled data 
pooled <- pooled %>% filter(year %in% c(2008,2010,2012,2014,2016,2018)) %>%     
  select(vote_history,intent,interest,registration,gender,age,race,
         education,income_new,partisan_strength,year,validated)

pooled <- bind_rows(pooled, new18)



####### RECODE 2020 DATA #######
## all obs with NA values are removed 
## --> about XXXXX obs dropped due to missing values
## some of the variables were coded correctly to begin
## but I go through motions of reassigning for completeness

tracker <- read_csv(file = "~/Dropbox/LikelyVoters/2020 Data/tracker_july21_july27_election_items.csv",
                    col_names = TRUE)
new20 <- tracker

# intent - early_vote_2020 --> DFP only
# new20$intent[new20$early_vote_2020 == 1] <- 1
# new20$intent[new20$early_vote_2020 == 2] <- 2
# new20$intent[new20$early_vote_2020 == 5] <- 5
# new20$intent[new20$early_vote_2020 == 4] <- 4
# new20 <- new20[!is.na(new20$intent),]
# new20$intent <- factor(new20$intent)
# intent - voteintent20 --> tracker only
new20$intent[new20$voteintent20 == 1] <- 1
new20$intent[new20$voteintent20 == 2] <- 2
new20$intent[new20$voteintent20 %in% c(4,5)] <- 4
new20$intent[new20$voteintent20 == 3] <- 5
new20$intent[new20$voteintent20 == 1] <- 1
new20 <- new20[!is.na(new20$intent),]
new20$intent <- factor(new20$intent)

# vote history - turnout16
new20$vote_history[new20$turnout16 == 2] <- 0
new20$vote_history[new20$turnout16 == 1] <- 1
new20 <- new20[!is.na(new20$vote_history),]
new20$vote_history <- as.factor(new20$vote_history)

# interest - newsint
new20$interest[new20$newsint == 1] <- 1
new20$interest[new20$newsint == 2] <- 2
new20$interest[new20$newsint == 3] <- 3
new20$interest[new20$newsint %in% c(4,7)] <- 4
new20 <- new20[!is.na(new20$interest),]
new20$interest <- as.factor(new20$interest)

# registration - votereg
new20$registration[new20$votereg==1] <- 1
new20 <- new20[!is.na(new20$registration),]
new20$registration <- as.factor(new20$registration)

# gender - gender
new20$gender[new20$gender==1] <- 1
new20$gender[new20$gender==2] <- 2
new20 <- new20[!is.na(new20$gender),]
new20$gender <- as.factor(new20$gender)

# age - birthyr
new20$age <- 2020 - new20$birthyr
new20$age <- as.integer(new20$age)

# race - race
new20$race[new20$race==1] <- 1
new20$race[new20$race==2] <- 2
new20$race[new20$race==3] <- 3
new20$race[new20$race==4] <- 4
new20$race[new20$race %in% c(5,6,7,8)] <- 5
new20 <- new20[!is.na(new20$race),]
new20$race <- as.factor(new20$race)

# educ - educ
new20$education[new20$educ==1] <- 1
new20$education[new20$educ==2] <- 2
new20$education[new20$educ==3] <- 3
new20$education[new20$educ==4] <- 4
new20$education[new20$educ==5] <- 5
new20$education[new20$educ==6] <- 6
new20 <- new20[!is.na(new20$education),]
new20$education <- as.factor(new20$education)

# income - faminc_new
new20$income_new[new20$faminc_new %in% c(1,2,3,4)] <- 1
new20$income_new[new20$faminc_new %in% c(5,6,7,8,9)] <- 2
new20$income_new[new20$faminc_new %in% c(10,11,12,13,14,15,16)] <- 3
new20$income_new[new20$faminc_new == 97] <- 4
new20 <- new20[!is.na(new20$income_new),]
new20$income_new <- as.factor(new20$income_new)

# partisan strength - pid7
new20$partisan_strength[new20$pid7 %in% c(1,7)] <- 1
new20$partisan_strength[new20$pid7 %in% c(2,6)] <- 2
new20$partisan_strength[new20$pid7 %in% c(3,5)] <- 3
new20$partisan_strength[new20$pid7 %in% c(4,8)] <- 4
new20 <- new20[!is.na(new20$partisan_strength),]
new20$partisan_strength <- as.factor(new20$partisan_strength)

# add year
new20$year <- 2020


####### END 2020 RECODE ####### 


####### Perry Gallup + Demos

# create training set and enforce var types
train <- pooled %>% filter(year %in% c(2008,2010,2012,2014,2016,2018)) %>% 
  select(vote_history,intent,interest,registration,gender,age,race,
         education,income_new,partisan_strength,year,validated)
test <- new20 %>% select(vote_history,intent,interest,registration,gender,age,race,
                         education,income_new,partisan_strength,year)
test_df <- bind_rows(train, test)
test_df$race <- as.factor(test_df$race)
test_df$intent <- as.factor(test_df$intent)
test_df$validated <- as.factor(test_df$validated)

# run model
formula <- as.formula(validated ~ vote_history + intent + interest + 
                        #registration + 
                        gender + age + race + education + income_new + 
                        partisan_strength)
set.seed(2020)
model <- randomForest(formula, 
                      data = test_df %>% filter(year!=2020, registration==1), 
                      importance=TRUE)

# apply the models to test data
predictions <- cbind(test_df[test_df$year==2020,], 
                     predict(model, newdata = test_df[test_df$year==2020,], type = "prob"))
predictions <- as.data.frame(predictions)

write.csv(cbind(new20, predictions$Voted) %>% rename(Voted = 'predictions$Voted'), 
          '~/Dropbox/LikelyVoters/2020 Data/preds_2020.csv')

############

## MODEL AUDIT ##
ggplot(predictions) +
  geom_histogram(aes(x=Voted)) +
  labs(y='')

ggplot(predictions, aes(x=Voted, y = ..density..)) +
  geom_histogram(alpha=0.4) +
  geom_density() +
  labs(y='', title='By race', subtitle='1=white, 2=black, 3=hispanic, 4=asian, 5=other') + 
  facet_wrap(~race) 

ggplot(predictions, aes(x=Voted, y = ..density..)) +
  geom_histogram(alpha=0.4) +
  geom_density() +
  labs(y='', title='By education', subtitle='1=No HS, 2=HS grad, 3=Some college, 4=2-year, 5=4-year, 6=Post-grad') + 
  facet_wrap(~education) 

## TOPLINES ##
mean(predictions$Voted)

estimates_df <- cbind(new20, predictions$Voted) %>% rename(Voted = 'predictions$Voted') %>%
  mutate(
    vote_preference_no_leaners = 
      case_when(
        presvote20_decided == 1 ~ 'Biden',
        presvote20_decided == 3 ~ 'Trump',
        TRUE ~ 'Other'),
    vote_preference_leaners = 
      case_when(
        presvote20_decided == 9 & presvote20_lean == 2 ~ 'Biden',
        presvote20_decided == 9 & presvote20_lean == 4 ~ 'Trump',
        TRUE ~ vote_preference_no_leaners
      ))

# no leaners - Biden +5.81
no_leaners <- estimates_df %>% group_by(vote_preference_no_leaners) %>%
  summarise(n = sum(weight_wave*Voted)) %>% # 
  mutate(vote_share = round(n/sum(n)*100,2)) %>% 
  select(-n)
no_leaners$vote_share[no_leaners$vote_preference_no_leaners=='Biden'] -
  no_leaners$vote_share[no_leaners$vote_preference_no_leaners=='Trump']

# leaners - Biden +6.33
leaners <- estimates_df %>% group_by(vote_preference_leaners) %>%
  summarise(n = sum(weight_wave*Voted)) %>% 
  mutate(vote_share = round(n/sum(n)*100,2)) %>% 
  select(-n)
leaners$vote_share[leaners$vote_preference_leaners=='Biden'] -
  leaners$vote_share[leaners$vote_preference_leaners=='Trump']


