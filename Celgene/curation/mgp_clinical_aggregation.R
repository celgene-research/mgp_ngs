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
source("curate_MMRF.R")
source("curate_UAMS.R")

# copy files locally
# dictionary, inventory
system(  paste('aws s3 cp', integrated_path, local_path, '--recursive --exclude "*" --include "*dictionary*" ', sep = " "))
# get curated files
system(  paste('aws s3 cp', processed_path, local_path, '--recursive --exclude "*" --include "DFCI*" --include "UAMS*" --include "MMRF*"', sep = " "))

##############
# The dictionary is used as a starting framework for each level table
dict <- as.data.frame(readxl::read_excel(file.path(local_path, "mgp_dictionary.xlsx")))
dict <- dict[dict$active == 1,]

files <- list.files(local_path, pattern = "curated*", full.names = T, recursive = T)

###
### FILE_LEVEL AGGREGATION
### 
file_level_columns <- dict[grepl("file", dict$level), "names"] 
df <- data.frame(matrix(ncol = length(file_level_columns), nrow = 0))
names(df) <- file_level_columns

for(f in files){
  print(f)
  new <-   read.delim(f, stringsAsFactors = F, check.names = F)
  df <- append_df(df, new, id = "File_Name", mode = "append")
}

# write the aggregated table to local
  name <- paste("INTEGRATED-PER-FILE_", d, ".txt", sep = "")
  path <- file.path(local,name)
  write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
  rm(df)

###
### SAMPLE_LEVEL AGGREGATION
### 
  options(warn=1)
sample_level_columns <- dict[grepl("sample", dict$level), "names"] 
df <- data.frame(matrix(ncol = length(sample_level_columns), nrow = 0))
names(df) <- sample_level_columns

  for(f in files){
    print(f)
    new <-   read.delim(f, stringsAsFactors = F, check.names = F)
    df <- append_df(df, new, id = "Sample_Name", mode = "append")
  }
  
  # write the aggregated table to local
  name <- paste("INTEGRATED-PER-SAMPLE_", d, ".txt", sep = "")
  path <- file.path(local,name)
  write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
  rm(df)
  
###
### PATIENT_LEVEL AGGREGATION
### 
patient_level_columns <- dict[grepl("patient", dict$level)  ,"names"] 
df <- data.frame(matrix(ncol = length(patient_level_columns), nrow = 0))
names(df) <- patient_level_columns
  
  for(f in files){
    print(f)
    new <-   read.delim(f, stringsAsFactors = F, check.names = F)
    df <- append_df(df, new, id = "Patient", mode = "append")
  }
  
  # write the aggregated table to local
  name <- paste("INTEGRATED-PER-PATIENT_", d, ".txt", sep = "")
  path <- file.path(local,name)
  write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
  rm(df)
  
###
# put final integrated files back as ProcessedData/Integrated on S3
processed <- file.path(s3clinical,"ProcessedData","Integrated")
system(  paste('aws s3 cp', local, processed, '--recursive --exclude "*" --include "INTEGRATED*" --sse', sep = " "))
return_code <- system('echo $?', intern = T)
  
# clean up source files
if(return_code == "0") system(paste0("rm -r ", local))
