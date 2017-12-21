###########################################################################
## Project: Visual Frames of politician´s on Facebook
## Script purpose: To check wether a facebook profile is public or private
##                 and if it is a "user" profile or a "page"
## Date: 2017-12-21
## Author: Julia Lenz
###########################################################################

library(tidyverse)
library(stringr)
library(Rfacebook)
library(RMySQL)
source("general_functions.R")


# load politician data ----------------------------------------------------
con <- dbConnect(MySQL(), group = "politicians_on_facebook")

query_string <- str_c("select * from politicians")
query <- dbSendQuery(con, query_string)
pol <- fetch(query, n = -1) %>% 
       df_utf8() 

dbClearResult(query)
dbDisconnect(con)


# make sure to paste a valid access token here (Get token: https://developers.facebook.com/tools/explorer/145634995501895/)
token = ""

new_fb_type <- character(length = nrow(pol))

for(i in seq_along(pol$pol_id)){
    print(str_c(i, pol$cand_lastname[i], pol$fb_identifier[i], sep = " "))
    
    if(pol$fb_identifier[i] ==""){
        new_fb_type[i] <- "no fb"
    } else {
        type <- getType(pol$fb_identifier[i], token)
        
        if(is.null(type)){
            new_fb_type[i] <- "private"
        } else {
            new_fb_type[i] <- type
        }
    }
}

table(new_fb_type)

new_fb_type <- cbind(pol, fb_type2) 

# you probably want to update your database...
