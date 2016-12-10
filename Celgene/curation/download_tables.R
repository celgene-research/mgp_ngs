
# simplified scripts to save s3 files to locally mounted storage
s3clinical      <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData"
local_path      <- "~/thindrives/mmgp/data"
if(!dir.exists(local_path)){warning("local drive not mounted")}

###
# this script is meant to be run line-by-line as needed after uncommenting to prevent bulk transfer

# all ORIGINAL data
# system(  paste('aws s3 cp', file.path(s3clinical, "OriginalData"),
#                             file.path(local_path, "OriginalData"), '--recursive', sep = " "))

# all individual PROCESSED data tables
system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData"),
                            file.path(local_path, "ProcessedData"),
               '--recursive --exclude "*"',
               # '--include "DFCI*" --include "MMRF_IA9*" --include "UAMS*"',
               '--include "JointData*"', sep = " "))

#  INTEGRATED tables, push dictionary before download
# system(  paste('aws s3 cp',"mgp_dictionary.xlsx" , file.path(s3clinical, "ProcessedData", "Integrated", "mgp_dictionary.xlsx"), "--sse ", sep = " "))
# system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData", "Integrated"),
#                file.path(local_path),
#                '--recursive --exclude "Archive*" --exclude "mgp-shiny*" --exclude "sas*"',
#                '--include "PER*"',
#                sep = " "))

#  report and summary tables
# system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData", "Integrated"),
#                file.path(local_path),
#                '--recursive --exclude "*"',
#                '--include "report*"',
#                sep = " "))

#  sas tables
# system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData", "Integrated"),
#                file.path(local_path),
#                '--recursive --exclude "*"',
#                '--include "sas*"',
#                sep = " "))