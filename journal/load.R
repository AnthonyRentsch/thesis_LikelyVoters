## @knitr load
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
library(pROC)

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

# add structural variables from Abramowitz Time for Change model:

# annualized growth rate of real GDP in 2nd quarter of election year
# taken from U.S. Department of Commerce's Bureau of Economic Analysis (BEA)
pooled$gdp_growth[pooled$year == 2008] <- 1.9
pooled$gdp_growth[pooled$year == 2012] <- 1.5
pooled$gdp_growth[pooled$year == 2016] <- 1.1
pooled$gdp_growth[pooled$year == 2010] <- 1.6
pooled$gdp_growth[pooled$year == 2014] <- 4

# Presidential approval
# Incumbent party's net approval (approve-disapprove) rating in final Gallup poll in June
pooled$pres_approval[pooled$year == 2008] <- 28-68
pooled$pres_approval[pooled$year == 2012] <- 47-46
pooled$pres_approval[pooled$year == 2016] <- 51-45
pooled$pres_approval[pooled$year == 2010] <- 46-45
pooled$pres_approval[pooled$year == 2014] <- 43-52
pooled <- pooled %>% rename(approval = pres_approval)

# # 2010/2014 - compute net approval for each House incumbent, 
# # then assign this to each R with this incumbent
# # 2010
# incumbent_approval10 <- cces10 %>% group_by(V501, CC315a) %>%
#   summarise(n = sum(V101)) %>% 
#   spread(CC315a, n) %>% 
#   mutate(approval = round(100*((`1`+`2`)-(`3`+`4`))/(`1`+`2`+`3`+`4`), 0)) %>% 
#   select(V501, approval) %>% rename(incumbent_name.x = V501) %>%
#   filter(!is.na(incumbent_name.x), incumbent_name.x != "")
# pooled <- left_join(pooled, incumbent_approval10, by = 'incumbent_name.x')
# # 2014
# incumbent_approval14 <- cces14 %>% group_by(CurrentHouseName, CC14_315a) %>%
#   summarise(n = sum(weight)) %>% 
#   spread(CC14_315a, n) %>% 
#   mutate(approval = round(100*((`1`+`2`)-(`3`+`4`))/(`1`+`2`+`3`+`4`), 0)) %>% 
#   select(CurrentHouseName, approval) %>% rename(incumbent_name.y = CurrentHouseName) %>%
#   filter(!is.na(incumbent_name.y), incumbent_name.y != "")
# pooled <- left_join(pooled, incumbent_approval14, by = 'incumbent_name.y')

# # finish clean up work
# pooled <- pooled[-which(pooled$year == 2010 & is.na(pooled$approval.x)),]
# pooled <- pooled[-which(pooled$year == 2014 & is.na(pooled$approval.y)),]
# pooled$pres_approval[pooled$year == 2010] <- pooled$approval.x[pooled$year == 2010] 
# pooled$pres_approval[pooled$year == 2014] <- pooled$approval.y[pooled$year == 2014] 
# pooled$incumbent_name[pooled$year == 2010] <- pooled$incumbent_name.x[pooled$year == 2010] 
# pooled$incumbent_name[pooled$year == 2014] <- pooled$incumbent_name.y[pooled$year == 2014] 
# pooled <- pooled %>% select(-approval.x, -approval.y, -incumbent_name.x, -incumbent_name.y) %>% 
#   rename(approval = pres_approval)

# indicator variable for whether or not the incumbent was from the President's party
pooled$incumbent[pooled$year == 2008] <- 1
pooled$incumbent[pooled$year == 2012] <- 1
pooled$incumbent[pooled$year == 2016] <- 1
pooled$incumbent[pooled$year == 2010 & pooled$incumbent_party10 == "Democratic"]  <- 1
pooled$incumbent[pooled$year == 2010 & pooled$incumbent_party10 == "Republican"]  <- 0
pooled$incumbent[pooled$year == 2014] <- 0
pooled$incumbent[pooled$year == 2014 & pooled$incumbent_party14 == "Democratic"] <- 1

# polarization variable (Abramowitz 2012)
# 1 if incumbent running or open seat where sitting president has net approval over 0
# -1 if no incumbent running or sitting president has net approval less than 0
pooled$polarization[pooled$year == 2008] <- 0
pooled$polarization[pooled$year == 2012] <- 1
pooled$polarization[pooled$year == 2016] <- 0
# 2010
pooled$polarization[pooled$year == 2010] <- 0
pooled$polarization[(pooled$year == 2010 & pooled$incumbent == 1) |
                      (pooled$year == 2010 & pooled$incumbent == 0 & pooled$approval > 0)] <- 1
# 2014
pooled$polarization[pooled$year == 2014] <- 0
pooled$polarization[(pooled$year == 2014 & pooled$incumbent == 1) |
                      (pooled$year == 2014 & pooled$incumbent == 0 & pooled$approval > 0)] <- 1

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
         religiosity, marital_status, residential_mobility, intent, gdp_growth, 
         approval, incumbent, polarization, partisan_strength) %>% 
  rename(education = educ, validated = vv_turnout_gvm, choice = intent_pres_16) %>% 
  mutate(validated = as.factor(validated),     # set all categorical variables as factors
         vote_history = as.factor(vote_history),
         intent = as.factor(intent),
         interest = as.factor(interest),
         registration = as.factor(registration),
         gender = as.factor(gender),
         race = as.factor(race),
         education  = as.factor(education),
         income_new = as.factor(income_new),
         religiosity = as.factor(religiosity),
         marital_status = as.factor(marital_status),
         residential_mobility = as.factor(residential_mobility),
         partisan_strength = as.factor(partisan_strength),
         incumbent = as.factor(incumbent),
         polarization = as.factor(polarization))


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

# calculated margin among 2016 validated voters, nationally
validated_margin16 <- pooled %>%
  filter(year == 2016, !choice %in% c("I Won't Vote In This Election"), !is.na(choice), validated == 'Voted') %>%
  group_by(choice) %>%
  summarise(n = sum(weight)) %>%
  mutate(vote_share = n/sum(n))
validated_margin16 <- validated_margin16 %>%
    mutate(margin = 100*(vote_share - lag(vote_share, default=first(vote_share)))) %>%
    filter(choice == "Hillary Clinton (Democrat)") %>%
    select(margin)
validated_margin16 <- validated_margin16$margin

# calculated margin among 2016 validated voters, state by state
validated_margin16_state <- pooled %>%
  filter(year == 2016, !choice %in% c("I Won't Vote In This Election"), !is.na(choice), validated == 'Voted') %>%
  group_by(state, choice) %>%
  summarise(n = sum(weight)) %>%
  mutate(vote_share = n/sum(n))
validated_margin16_state <- validated_margin16_state %>%
  mutate(margin = 100*(vote_share - lag(vote_share, default=first(vote_share)))) %>%
  filter(choice == "Hillary Clinton (Democrat)") %>%
  select(state, margin)

# remove data from VA '08 and '10 because of no vote history
va_08_10 <- pooled %>% filter(state=='Virginia', year %in% c(2008,2010))
pooled <- anti_join(pooled, va_08_10, by='case_id')

# Add a dummy variable for whether election is a mid-term
pooled$midterm[pooled$year==2008 | pooled$year==2012 | pooled$year==2016] <- 0 
pooled$midterm[pooled$year==2010 | pooled$year==2014] <- 1 

