###########################################################################
## Project: Visual Frames of politician´s on Facebook
## Script purpose: Helper functions which are needed in more than one file 
## Date: 2017-12-21
## Author: Julia Lenz
###########################################################################


# df_utf8 -----------------------------------------------------------------
# function to set encoding to UTF-8 in all colums of a dataframe
# (eg. after SQL import); 
# returns utf8-encoded dataframe
df_utf8 <- function(df){
    for(i in seq_along(df)){
        if(is.character(df[,i])){
            Encoding(df[,i]) <- "UTF-8"   
        }
    }
    return(df)
}
