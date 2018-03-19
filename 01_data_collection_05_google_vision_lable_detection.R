###########################################################################
## Project: Visual Frames of politician´s on Facebook
## Script purpose: To analyse collected facebook photos using 
##                 google vision api
## Date: 2018-03-19
## Author: Julia Lenz
###########################################################################


# for requsting the label detection via google api the RoogleVision package is 
# used and needs to be installed first:

# latest stable version
# install.packages("RoogleVision", repos = c(getOption("repos"), 
# "http://cloudyr.github.io/drat"))

# or, to pull a potentially unstable version directly from GitHub:
# if (!require("devtools")) {
#     install.packages("ghit")
# }
# devtools::install_github("cloudyr/RoogleVision")

# load packages
library(RoogleVision)
library(tidyverse)
library(stringr)
library(Rfacebook)
library(RMySQL)
library(lubridate)
source("general_functions.R")


# prepare database ---------------------------------------------------------
# connect to database and select all profiles of politicians, posts & visuals --------------
con <- dbConnect(MySQL(), group = "politicians_on_facebook")

query_string <- str_c("select * from politicians")
query <- dbSendQuery(con, query_string)
all_pol <- fetch(query, n = -1) %>% 
    df_utf8() 
dbClearResult(query)

query_string <- str_c("select * from fb_profiles")
query <- dbSendQuery(con, query_string)
fb_pol <- fetch(query, n = -1) %>% 
    df_utf8() 
dbClearResult(query)


query_string <- str_c("select * from fb_posts")
query <- dbSendQuery(con, query_string)
fb_posts <- fetch(query, n = -1) %>% 
    df_utf8() 
dbClearResult(query)


query_string <- str_c("select * from fb_posts_visuals")
query <- dbSendQuery(con, query_string)
fb_posts_vis <- fetch(query, n = -1) %>% 
    df_utf8() 
dbClearResult(query)


fb_pol <- left_join(fb_pol, all_pol, by = c("pol_id", "fb_type")) %>% 
    select(-X)
names(fb_pol)
colnames(fb_pol)[3] <- "from_id"


colnames(fb_posts_vis)[1] <- "id"
fb_posts_vis <- fb_posts_vis %>% 
    select(-type, -created_time, -downloaded_time)
post_data_vis <- left_join(fb_posts, fb_posts_vis, by = "id")
table(post_data_vis$type)

post_data_vis$date <- ymd(str_sub(post_data_vis$created_time, 1, 10))
head(post_data_vis$date)



# prepare for google vision for lable detection ----------------------------


### plugin your credentials for google vision
options("googleAuthR.client_id" = "")
options("googleAuthR.client_secret" = "")

## use the Google Auth R package
options("googleAuthR.scopes.selected" = c("https://www.googleapis.com/auth/cloud-platform"))
googleAuthR::gar_auth()



# loop over list of images and store result of lable detection into db ------
# Also, store if there is an error.

# I decided to write the labels to my SQL database after each query. This makes 
# the script very slow. But I'm a coward and I didn't want to lose the data ;)
# One can probably speed this skript up by collecting severals google requests 
# first.

for(i in seq_along(post_data_vis$id)){
    error_msg <- NULL
    
    img_path <- str_c("" # you need to adapt the path to your images and file names here 
                      post_data_vis$id[i], 
                      "__vis_id_",
                      post_data_vis$visual_id[i], 
                      ".jpg")
    
    #print(i_img)
    
    if(!file.exists(img_path)){
        error_msg <- "file does not exist!"
        
    } else {
        google_request <- getGoogleVisionResponse(img_path, 
                                                  feature="LABEL_DETECTION", 
                                                  numResults = 100)
        
        if(!is.null(google_request$error)){
            error_msg <- as.character(google_request$error)
        }
    }
    
    if(!is.null(error_msg)){
        print(str_c(i, ": ERROR: ", post_data_vis$id[i], " ", error_msg))
        
        google_error <- data.frame(img_type = as.character("fb post"),
                                   post_id = as.character(post_data_vis$id[i]), 
                                   vis_id  = as.character(post_data_vis$visual_id[i]), 
                                   error = as.character(error_msg), 
                                   reqest_time = as.Date(Sys.time()), 
                                   stringsAsFactors = FALSE,
                                   row.names = FALSE)
        
        RMySQL::dbWriteTable(
            con,
            name = "google_vision_error",
            value = google_error,
            row.names = FALSE,
            append = TRUE
        )
    } else {
        print(str_c(i, ": request successful for ", post_data_vis$id[i]))
        google_request <- as.data.frame(google_request)
        
        #print(google_request)
        
        google_request$id     <- post_data_vis$id[i]
        google_request$vis_id <- post_data_vis$visual_id[i]
        google_request$created_time <- post_data_vis$created_time[i]
        google_request$from_name    <- post_data_vis$from_name[i]
        google_request$cand_party   <- post_data_vis$cand_party[i]
        google_request$request_time   <- Sys.time()
        google_request$img_type   <- "fb post"
        
        google_request <- select(google_request, id, vis_id, img_type, created_time, from_name, cand_party, 
                                 mid, description, score, topicality, request_time)
        
        Encoding(google_request$description) <- "UTF-8_bin"
        Encoding(google_request$from_name)   <- "UTF-8_bin"
        Encoding(google_request$cand_party)  <- "UTF-8_bin"
        
        RMySQL::dbWriteTable(
            con,
            name = "google_vision_lables",
            value = google_request,
            row.names = FALSE,
            append = TRUE
        )
    }
}

# close connection to db
dbDisconnect(con)
