## drozelle@ranchobiosciences.com
## 2016-11-04

# SAGE challenge curation
# this curation script has been adjusted to use only
# MMRF IA8b data sources and filter for ND samples

# Approach to curation follows the following process:
#  1.) <data.txt> is curated to <curated_data.txt> and moved to /ProcessedData/Study/
#       In these curated files new columns are added using the format specified in 
#       <mgp_dictionary.xlsx> and values are coerced into ontologically accurate values. 
#       These files are not filtered or organized per-se, but provides a nice reference 
#       for where curated value columns are derived.
#  2.) sage_aggregation.R is used to leverage our append_df() function, which 
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
processed_path  <- file.path(s3clinical,"ProcessedData")
sage_path <- file.path(s3clinical,"ProcessedData", "Sage")
local      <- CleanLocalScratch()

# We are editing the dictionary spreadsheet locally, so push latest to s3
system(  paste('aws s3 cp',"./sage/sage_dictionary.xlsx" , file.path(sage_path, "sage_dictionary.xlsx"), "--sse ", sep = " "))

# copy files locally
# dictionary, curated files
system(  paste('aws s3 cp', processed_path, local, '--recursive --exclude "*" --include "MMRF_IA8*" --include "*sage_dictionary*"', sep = " "))

##############
# The dictionary is used as a starting framework for each level table
dict <- as.data.frame(readxl::read_excel(file.path(local, "Integrated", "mgp_dictionary.xlsx")))
dict <- dict[dict$active == 1,]

  ################################################
  ########## SAGE SPECIFIC FILTERING  ############
  dict <- dict[!is.na(dict$names),]
  dict <- dict[dict$sage_active  == 1,]
  
  sage_dict <- dict[,c("names","level","type","factor_levels","key_val","units","description","MMRF Source" )]
  sage_dict[is.na(sage_dict)] <- ""
  write.table(sage_dict, file.path(local, "MMRF_curated_dictionary.txt"), row.names = F, col.names = T, sep = "\t", quote = F)
  rm(sage_dict)

files <- list.files(local, pattern = "curated*", full.names = T, recursive = T)

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

  per.file <- remove_invalid_samples(per.file)
  per.file$Sample_Name_Tissue_Type <- paste(per.file$Sample_Name, per.file$Tissue_Type, sep="_")
  
  #######################################################
  ##########    SAGE SPECIFIC FILTERING      ############                             
  per.file <- per.file[per.file$Disease_Status == "ND",]
  per.file$Visit_Name <- "Baseline"

  name <- paste("MMRF_IA8b_PER-FILE_", ".txt", sep = "")
  path <- file.path(local,name)
  write.table(per.file, path, row.names = F, col.names = T, sep = "\t", quote = F)

  ##########                                   ########## 
  #######################################################
  
  
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

  #######################################################
  ##########    SAGE SPECIFIC FILTERING      ############                             
    
  per.patient <- remove_sensitive_columns(per.patient, dict)
  
  # remove empty columns
  columns_with_data <- unlist(lapply(names(per.patient), function(x){
    !all(is.na(per.patient[[x]]))
  }))
  per.patient <- per.patient[,columns_with_data]
  
  name <- paste("MMRF_IA8b_PER-PATIENT", ".txt", sep = "")
  path <- file.path(local,name)
  write.table(per.patient, path, row.names = F, col.names = T, sep = "\t", quote = F)
  
  ##########                                   ########## 
  #######################################################
  
  
# download sage curated files to local disk for upload to synapse
file.copy(from = list.files(path = local, pattern = "MMRF*", full.names = T, include.dirs = F, no.. = T), 
          to   = "~/thindrives/drozelle/Downloads/",
          overwrite = T)
  
  
# put final integrated files back as ProcessedData/Integrated on S3
# processed <- file.path(s3clinical,"ProcessedData","Integrated")
# system(  paste('aws s3 cp', local, processed, '--recursive --exclude "*" --include "INTEGRATED*" --sse', sep = " "))
# return_code <- system('echo $?', intern = T)

# clean up source files
rm(per.file, per.patient, new)
# if(return_code == "0") 
system(paste0("rm -r ", local))


