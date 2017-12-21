################################################################################
## Project: Visual Frames of politician´s on Facebook
## Script purpose: Step 1:
##                 Put .csv-File of politicians into database.
##                 The table of politicians is the basis for all further
##                 data collection-
## Date: 2017-12-21
## Author: Julia Lenz
################################################################################

library(RMySQL)

# The folowing workflow ensured the correct encoding in the SQL database for me
# (Windows 10):
# - the excel-file needs to be saved as .csv ("Trennzeichen getrennt")
# - the .csv-file needs to be opend in the simple editor and saved again as .csv
#   but with encodig "UTF-8" 


# read .csv-file (rename path if necessary)
pol <- read.csv2("politicians_2017-12-18.csv", 
                 header = TRUE, sep = ";", 
                 encoding = "UTF-8_bin") 

# Don´t worry if the German umlaute look weired in R view(). 
# I experienced that they need to be wrong here so they will be correct in the 
# database.


# correct name of first column
colnames(pol_list)[1] <- "pol_id"


# connect to database, write table into database, disconnect
con <- dbConnect(MySQL(), group = "politicians_on_facebook")

RMySQL::dbWriteTable(
    con,
    name = "politicians",
    value = pol,
    row.names = FALSE,
    append = TRUE
)
dbDisconnect(con)
