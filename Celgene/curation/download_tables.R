
# simplified scripts to save s3 files to locally mounted storage
s3clinical      <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData"
local_path      <- "~/thindrives/mmgp/data"
if(!dir.exists(local_path)){warning("local drive not mounted")}

# We are editing the dictionary spreadsheet on EC2, so push latest to s3 before download
system(  paste('aws s3 cp',"mgp_dictionary.xlsx" , file.path(s3clinical, "ProcessedData", "Integrated", "mgp_dictionary.xlsx"), "--sse ", sep = " "))

###
# this script is meant to be run line-by-line as needed after uncommenting to prevent bulk transfer

# all ORIGINAL data
# system(  paste('aws s3 cp', file.path(s3clinical, "OriginalData"), 
#                             file.path(local_path, "OriginalData"), '--recursive', sep = " "))

# all individual PROCESSED data tables
# system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData"),
#                             file.path(local_path, "ProcessedData"),
#                '--recursive --exclude "*"',
#                '--include "DFCI*" --include "MMRF_IA9*" --include "UAMS*"',
#                '--include "JointData*"', sep = " "))

#  INTEGRATED tables
# system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData", "Integrated"),
#                file.path(local_path),
#                '--recursive --exclude "Archive*" --exclude "mgp-shiny*" --exclude "sas*"',
#                sep = " "))
