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
local_path      <- "/tmp/curation"
if(!dir.exists(local_path)){dir.create(local_path)}

# We are editing the dictionary spreadsheet locally, so push latest to s3
system(  paste('aws s3 cp',"mgp_dictionary.xlsx" , file.path(s3clinical, "ProcessedData", "Integrated", "mgp_dictionary.xlsx"), "--sse ", sep = " "))


### if appropriate, run curation scripts
# source("curate_DFCI.R")
# source("curate_MMRF_IA9.R")
# source("curate_UAMS.R")
# source("curate_joint_datasets.R")

# copy curated files locally
system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData", "Integrated", "mgp_dictionary.xlsx"), local_path, sep = " "))
system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData", "DFCI"), local_path, '--recursive --exclude "*" --include "curated*"', sep = " "))
system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData", "MMRF_IA9"), local_path, '--recursive --exclude "*" --include "curated*"', sep = " "))
system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData", "UAMS"), local_path, '--recursive --exclude "*" --include "curated*"', sep = " "))
system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData", "Joint_Datasets/curated_All_translocation_Summaries_from_BWalker_2016-10-04_zeroed_dkr.txt"), local_path, sep = " "))

##############
# The dictionary is used as a starting framework for each level table
dict <- as.data.frame(readxl::read_excel(file.path(local_path, "mgp_dictionary.xlsx")))
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

  # qc and summary    
  per.file <- remove_invalid_samples(per.file)
  per.file <- translocation_consensus_building(per.file)
  
  report_unique_patient_counts(per.file, sink_file = file.path(local,"report_unique_patient_counts.txt"))

  # write the aggregated table to local
  name <- paste("PER-FILE_clinical_cyto", ".txt", sep = "")
  path <- file.path(local,name)
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
  name <- paste("PER-PATIENT_clinical", ".txt", sep = "")
  path <- file.path(local,name)
  write.table(per.patient, path, row.names = F, col.names = T, sep = "\t", quote = F)


  
#######################
# put final integrated files back as ProcessedData/Integrated on S3
system(  paste('aws s3 cp', local, file.path(s3clinical, "ProcessedData", "Integrated"), '--recursive --exclude "*" --include "PER*"  --include "report*" --sse', sep = " "))
return_code <- system('echo $?', intern = T)
  
# clean up source files
if(return_code == "0"){
  system(paste0("rm -r ", local))
  rm(list = ls())
  }
