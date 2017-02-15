
# simplified scripts to save s3 files to locally mounted storage
s3clinical      <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData"
local_path      <- "/scratch/tmp/drozelle/"
if(!dir.exists(local_path)){warning("local drive not mounted")}

###
# this script is meant to be run line-by-line as needed after uncommenting to prevent bulk transfer
# Sync dictionary
system(  paste('aws s3 sync', '.' , file.path(s3clinical, "ProcessedData/Integrated"), 
               '--sse --exclude "*" --include "mgp_dictionary.xlsx"', sep = " "))

# Standard Sync of current INTEGRATED tables
system(  paste('aws s3 sync', 
               file.path(s3clinical, "ProcessedData", "Integrated"),
               file.path(local_path, "ProcessedData", "Integrated"),
               '--exclude "Archive*" --exclude "sas*" ', sep = " "))

# ORIGINAL data
system(  paste('aws s3 sync', file.path(s3clinical, "OriginalData"),
                            file.path(local_path, "OriginalData"),
                            sep = " "))

# all individual PROCESSED data tables
system(  paste('aws s3 sync', file.path(s3clinical, "ProcessedData"),
                            file.path(local_path, "ProcessedData"),
                            sep = " "))

# Archive and sas table
# system(  paste('aws s3 sync', 
#                file.path(s3clinical, "ProcessedData", "Integrated"),
#                file.path(local_path, "ProcessedData", "Integrated"),
#                sep = " "))