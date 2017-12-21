###########################################################################
## Project: Visual Frames of politician´s on Facebook
## Script purpose: To collect politician´s Facebook posts from their
##                 fb_identifier and store them in database 
## Date: 2017-12-21
## Author: Julia Lenz
###########################################################################

library(tidyverse)
library(stringr)
library(Rfacebook)
library(RMySQL)
source("general_functions.R")


# connect to database and select all profiles of politicians --------------
con <- dbConnect(MySQL(), group = "politicians_on_facebook")

query_string <- str_c("select * from fb_profiles")
query <- dbSendQuery(con, query_string)
fb_pol <- fetch(query, n = -1) %>% 
    df_utf8() 
dbClearResult(query)


# prerequesits for API download -------------------------------------------
# make sure to paste a valid access token here (Get token: https://developers.facebook.com/tools/explorer/145634995501895/)
token = ""


# set date range for download ---------------------------------------------
start_date  <- as.Date("2013-01-01 00:00:00 CET") 
end_date    <- as.Date("2017-10-01 00:00:00 CET")


# loop over fb_profiles and download posts in date range ------------------
# astonishingly, I always get a connection timeout the first time I start 
# this loop in a new R session - just start it again.

for(i in 2:length(fb_pol$fb_id)){
    user_id <- as.character(format(fb_pol$fb_id[i], scientific = FALSE))
    print(paste("next case: ", i, fb_pol$fb_name[i], user_id))
    
    # make fb request
    my_pol <-
        try(getPage(
            user_id,
            token,
            n = 5000,
            since = start_date,
            until = end_date,
            feed = FALSE,
            reactions = TRUE,
            verbose = FALSE,
            api = "v2.10"
        ))
    
    # report profiles without posts
    if(dim(my_pol)[1] == 0){
        print(str_c("no public posts: ", i, fb_pol$fb_name[i], user_id))
    }
    
    # check if an error occcured, if yes: 
    # print error message & write error into sql database
    else if(str_detect(my_pol[1], "Error in callAPI")){
        print(paste("error: ", i, fb_pol$name[i], user_id))
        
        error <- list(platform = "fb", type = "post", 
                      id = user_id, error_time = Sys.time()) %>% 
            as.data.frame()

        RMySQL::dbWriteTable(
            con,
            name = "download_errors",
            value = error,
            row.names = FALSE,
            append = TRUE
        )
    } 
    
    # if no error occured, write posts into sql database
    else { 

        # this needs to be done to ensure right encoding in sql database:
        my_pol <- dput(my_pol, control = c("keepNA", "keepInteger"))
        
        Encoding(my_pol$from_name) <- "UTF-8_bin"
        Encoding(my_pol$message) <- "UTF-8_bin"
        Encoding(my_pol$story) <- "UTF-8_bin"

        # set downloaded_time
        my_pol$downloaded_time <- Sys.time()
        
        # write into table fb_posts
        RMySQL::dbWriteTable(
            con,
            name = "fb_posts",
            value = my_pol,
            row.names = FALSE,
            append = TRUE
        )
    }
    
    print(paste("done with: ", i, fb_pol$fb_name[i], user_id))
}

# Don´t forget to close connection
dbDisconnect(con)
 