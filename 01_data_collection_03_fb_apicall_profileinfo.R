###########################################################################
## Project: Visual Frames of politician´s on Facebook
## Script purpose: To collect politician´s Facebook profiles from their
##                 fb_identifier and store them in database 
## Date: 2017-12-21
## Author: Julia Lenz
###########################################################################

library(tidyverse)
#library(httr)
library(stringr)
library(RMySQL)
source("general_functions.R")


# load FB politicians data from database -----------------------------------
# filter: only those who have a public Facebook profile (user or page)
con <- dbConnect(MySQL(), group = "politicians_on_facebook")

query_string <- str_c("select * from politicians")
query <- dbSendQuery(con, query_string)
pol <- fetch(query, n = -1) %>% 
    df_utf8() %>% 
    filter(fb_type == "user" | fb_type == "page")

dbClearResult(query)

# prerequesits for API download -------------------------------------------
# make sure to paste a valid access token here (Get token: https://developers.facebook.com/tools/explorer/145634995501895/)
token = ""


# preparation to download profile info -------------------------------------

# function to download profile info
# will return values for all fields specified (if they exist for the node)
getGraph <- function(node, fields, token){
    Sys.sleep(0.05)
    url <- str_c("https://graph.facebook.com/v2.10/", node,
                 "?fields=", fields, 
                 "&access_token=", token
    )
    url.data <- GET(url)
    content <- rjson::fromJSON(rawToChar(url.data$content)) %>%
        return()
}

# fields to collect for pages 
fields_page = str_c("id,name,picture.width(480).height(480),cover,",
                    "username,about,affiliation,bio,birthday,category,",
                    "description,fan_count,impressum,", 
                    "mission,personal_info,personal_interests,website")

# fields to collect for users
fields_user = str_c("id,name,picture.width(480).height(480),cover")


# loop over politicians, download profile info and store in databa --------
for(i in seq_along(pol$pol_id)){
    cat(paste(i, pol$pol_id[i], pol$cand_firstname[i], pol$cand_lastname[i], pol$cand_facebook[i], sep="\t"), "\n")
    
    # choose correct fields for politicians fb_type
    fields <- if_else(pol$fb_type[i] == "user", fields_user, fields_page) 
    
    # get profile info
    q <- getGraph(pol$fb_identifier[i], fields, token) 

    # make current entry
    entry <-  tibble(
              pol_id	  = pol$pol_id[i],
              fb_type	  = pol$fb_type[i], 
              fb_username = ifelse(!is.null(q$username), q$username, NA),
              fb_id       = ifelse(!is.null(q$id), q$id, NA),
              fb_name     = as.character(ifelse(!is.null(q$name), q$name, NA)),
              fb_picture  = ifelse(!is.null(q$picture$data$url ), q$picture$data$url, NA),
              fb_cover    = ifelse(!is.null(q$cover$source), q$cover$source, NA),
              fb_about    = ifelse(!is.null(q$about), q$about, NA),
              fb_category = ifelse(!is.null(q$category), q$category, NA),
              fb_fan_count = ifelse(!is.null(q$fan_count), q$fan_count, NA),
              fb_website   = ifelse(!is.null(q$website), q$website, NA),
              fb_affiliation = ifelse(!is.null(q$affiliation), q$affiliation, NA),
              fb_birthday    = ifelse(!is.null(q$birthday), q$birthday, NA),
              fb_impressum   = ifelse(!is.null(q$impressum), q$impressum, NA),
              fb_bio         = ifelse(!is.null(q$bio), q$bio, NA),
              fb_personal_info = ifelse(!is.null(q$personal_info), q$personal_info, NA),
              fb_description   = ifelse(!is.null(q$description), q$description, NA),
              fb_personal_interests = ifelse(!is.null(q$personal_interest), q$personal_interest, NA),
              fb_mission            = ifelse(!is.null(q$mission), q$mission, NA)
         )
    
    # ensure correct encoding in db
    entry <- dput(entry, control = c("keepNA", "keepInteger"))
    
    # the following code doesn´t work if it is oursourced it into a function:
    if(!is.na(entry$fb_name))          Encoding(entry$fb_name)          <- "UTF-8_bin"
    if(!is.na(entry$fb_about))         Encoding(entry$fb_about)         <- "UTF-8_bin"
    if(!is.na(entry$fb_affiliation))   Encoding(entry$fb_affiliation)   <- "UTF-8_bin"
    if(!is.na(entry$fb_impressum))     Encoding(entry$fb_impressum)     <- "UTF-8_bin"
    if(!is.na(entry$fb_birthday))      Encoding(entry$fb_birthday)      <- "UTF-8_bin"
    if(!is.na(entry$fb_bio))           Encoding(entry$fb_bio)           <- "UTF-8_bin"
    if(!is.na(entry$fb_personal_info)) Encoding(entry$fb_personal_info) <- "UTF-8_bin"
    if(!is.na(entry$fb_description))   Encoding(entry$fb_description)   <- "UTF-8_bin"
    if(!is.na(entry$fb_personal_interests)) Encoding(entry$fb_personal_interests) <- "UTF-8_bin"
    if(!is.na(entry$fb_mission))       Encoding(entry$fb_mission)       <- "UTF-8_bin"
    
    # write into db
    RMySQL::dbWriteTable(
                 con, 
                 name = "fb_profiles_test", 
                 value = entry, 
                 row.names = FALSE,
                 append = TRUE)
}

# don´t forget to disconnect
dbDisconnect(con)
