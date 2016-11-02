## drozelle@ranchobiosciences.com
## 2016-10-17

# Approach to MGP curation follows the following process:
#  1.) <data.txt> is curated to <curated_data.txt> and moved to /ProcessedData/Study/
#       In these curated files new columns are added using the format specified in 
#       <mgp_dictionary.xlsx> and values are coerced into ontologically accurate values. 
#       These files are not filtered or organized per-se, but provides a nice reference 
#       for where curated value columns are derived.
#  2.) mgp_clinical_aggregated.R is used to leverage our append_df() function, which 
#       loads curated columns (those matching a dictionary column) from each table 
#       into the main integrated table. 
#  3.) TODO: QC to enforces ontology rules to ensure all columns adhere to 
#       type and factor rules detailed in the <mgp_dictionary.xlsx>.
#  3.) TODO: Summary scripts to generate specific counts and aggregated summary 
#       values.

# vars
d <- format(Sys.Date(), "%Y-%m-%d")
source("curation_scripts.R")
source("qc_and_summary.R")

# locations
s3clinical      <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData"
integrated_path <- file.path(s3clinical,"ProcessedData", "Integrated")
processed_path  <- file.path(s3clinical,"ProcessedData")
local_path      <- "/tmp/curation"
if(!dir.exists(local_path)){dir.create(local_path)}

# We are editing the dictionary spreadsheet locally, so push latest to s3
system(  paste('aws s3 cp',"mgp_dictionary.xlsx" , file.path(integrated_path, "mgp_dictionary.xlsx"), "--sse ", sep = " "))

### if appropriate, run curation scripts
source("curate_DFCI.R")
# source("curate_MMRF.R")
# source("curate_UAMS.R")
# source("../aggregate_stats/uams_calls_to_binary_table.R")

# copy files locally
# dictionary, curated files
system(  paste('aws s3 cp', processed_path, local_path, '--recursive --exclude "*" --include "*dictionary*" --include "*curated*"', sep = " "))

##############
# The dictionary is used as a starting framework for each level table
dict <- as.data.frame(readxl::read_excel(file.path(local_path, "Integrated", "mgp_dictionary.xlsx")))
dict <- dict[dict$active == 1,]

files <- list.files(local_path, pattern = "curated*", full.names = T, recursive = T)

###
### FILE_LEVEL AGGREGATION
### 
file_level_columns <- dict[grepl("file", dict$level), "names"] 
per.file <- data.frame(matrix(ncol = length(file_level_columns), nrow = 0))
names(per.file) <- file_level_columns

for(f in files){
  print(f)
  new <-   read.delim(f, stringsAsFactors = F, check.names = F)
  per.file <- append_df(per.file, new, id = "File_Name", mode = "append")
}

# write the aggregated table to local
  name <- paste("INTEGRATED-PER-FILE_", d, ".txt", sep = "")
  path <- file.path(local,name)
  per.file <- remove_invalid_samples(per.file)
  write.table(per.file, path, row.names = F, col.names = T, sep = "\t", quote = F)

###
### PATIENT_LEVEL AGGREGATION
### 
patient_level_columns <- dict[grepl("patient", dict$level)  ,"names"] 
per.patient <- data.frame(matrix(ncol = length(patient_level_columns), nrow = 0))
names(per.patient) <- patient_level_columns
  
  for(f in files){
    print(f)
    new <-   read.delim(f, stringsAsFactors = F, check.names = F)
    per.patient <- append_df(per.patient, new, id = "Patient", mode = "append")
  }

  # qc and summary    
per.patient <-  remove_unsequenced_patients(per.patient, per.file)


  # write the aggregated table to local
  name <- paste("INTEGRATED-PER-PATIENT_", d, ".txt", sep = "")
  path <- file.path(local,name)
  write.table(per.patient, path, row.names = F, col.names = T, sep = "\t", quote = F)

###
# put final integrated files back as ProcessedData/Integrated on S3
processed <- file.path(s3clinical,"ProcessedData","Integrated")
system(  paste('aws s3 cp', local, processed, '--recursive --exclude "*" --include "INTEGRATED*" --sse', sep = " "))
return_code <- system('echo $?', intern = T)
  
# clean up source files
rm(per.file, per.patient)
if(return_code == "0") system(paste0("rm -r ", local))

# run Fadi's script to merge sample-level table onto file-level table
# source("../Metadata/merge_file_sample_table.R")

# save a copy to my local drive for inspection
source("download_tables.R")
