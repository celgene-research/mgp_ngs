## drozelle@ranchobiosciences.com
## 2016-10-17

# vars
d <- format(Sys.Date(), "%Y-%m-%d")
# devtools::install_github("dkrozelle/toolboxR")
library(toolboxR)
source("curation_scripts.R")
source("qc_and_summary.R")
source("table_merge.R")


# locations
s3    <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData"
local <- CleanLocalScratch()

# We are editing the dictionary spreadsheet locally, so sync latest to s3
system(  paste('aws s3 sync', '.' , file.path(s3, "Integrated"), 
               '--sse --exclude "*" --include "mgp_dictionary.xlsx" ', sep = " "))

### if appropriate, run curation scripts
# source("curate_DFCI.R")
# source("curate_MMRF_IA9.R")
# source("curate_UAMS.R")
# source("curate_JointData.R")

# copy curated files locally
system(  paste('aws s3 cp', file.path(s3, "Integrated", "mgp_dictionary.xlsx"), file.path(local, "mgp_dictionary.xlsx"), sep = " "))
system(  paste('aws s3 cp', file.path(s3, "DFCI"), local, '--recursive --exclude "*" --include "curated*"', sep = " "))
system(  paste('aws s3 cp', file.path(s3, "MMRF_IA9"), local, '--recursive --exclude "*" --include "curated*"', sep = " "))
system(  paste('aws s3 cp', file.path(s3, "UAMS"), local, '--recursive --exclude "*" --include "curated*"', sep = " "))
system(  paste('aws s3 cp', file.path(s3, "JointData/curated_All_translocation_Summaries_from_BWalker_2016-10-04_zeroed_dkr.txt"), local, sep = " "))

##############
# The dictionary is used as a starting framework for each level table
dict <- as.data.frame(readxl::read_excel(file.path(local, "mgp_dictionary.xlsx")))
dict <- dict[dict$active == 1,]

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

  # per.file$Sample_Name_Tissue_Type <- paste(per.file$Sample_Name, per.file$Tissue_Type, sep="_")
  per.file  <- remove_invalid_samples(per.file)
  per.file  <- cytogenetic_consensus_calling(per.file)
  
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

#######################
  # merge and filter tables

  per.patient           <- remove_unsequenced_patients(per.patient, per.file)
  per.patient.clinical  <- per.patient # rename for clarity
  per.file.clinical     <- per.file    # rename for clarity
  
  # currently table merge throws dimension error since CNV contains clinically lost patients, it's OK
  per.file.all          <- table_merge(per.file.clinical, per.patient.clinical)
  per.file.all          <- remove_invalid_samples(per.file.all)
  
  # add inventory flags to per.patient after table merge since patient inventory flags
  #  are not applicable to per-file rows
  per.patient.clinical  <- add_inventory_flags(per.patient.clinical, per.file.clinical)
  
  # Collapse file > sample for some analyses
  per.sample.all        <- toolboxR::CollapseDF(per.file.all, column.names = "Sample_Name_Tissue_Type")
  per.sample.clinical   <- subset_clinical_columns(per.sample.all)
  
  # Filter for ND-tumor sample only
  per.file.all.nd.tumor         <- subset(per.file.all,   Sample_Type_Flag == 1 & Disease_Status == "ND")
  per.sample.all.nd.tumor       <- subset(per.sample.all, Sample_Type_Flag == 1 & Disease_Status == "ND")
  per.patient.clinical.nd.tumor <- subset(per.patient.clinical, INV_Has.ND.NotNormal.sample == 1)
  
  # Select clinical column subsets
  per.file.clinical.nd.tumor    <- subset_clinical_columns(per.file.all.nd.tumor)
  per.sample.clinical.nd.tumor  <- subset_clinical_columns(per.sample.all.nd.tumor)
  
  # qc and summary
  inventory_counts <- get_inventory_counts(per.patient)
  report_unique_patient_counts(per.file, sink_file = file.path(local,"report_unique_patient_counts.txt"))

  # write un-dated PER-FILE and PER-PATIENT files to S3
  
  write_to_s3integrated(per.file.clinical              ,name = "per.file.clinical.txt")
  write_to_s3integrated(per.file.clinical.nd.tumor     ,name = "per.file.clinical.nd.tumor.txt")
  write_to_s3integrated(per.file.all                   ,name = "per.file.all.txt")
  write_to_s3integrated(per.file.all.nd.tumor          ,name = "per.file.all.nd.tumor.txt")
  
  write_to_s3integrated(per.sample.clinical            ,name = "per.sample.clinical.txt")
  write_to_s3integrated(per.sample.clinical.nd.tumor   ,name = "per.sample.clinical.nd.tumor.txt")
  write_to_s3integrated(per.sample.all                 ,name = "per.sample.all.txt")
  write_to_s3integrated(per.sample.all.nd.tumor        ,name = "per.sample.all.nd.tumor.txt")
  
  write_to_s3integrated(per.patient.clinical           ,name = "per.patient.clinical.txt")
  write_to_s3integrated(per.patient.clinical.nd.tumor  ,name = "per.patient.clinical.nd.tumor.txt")

  

  # export_sas(per.patient.all.nd.tumor, dict, name = "per.patient.all.nd.tumor")
  # export_sas(per.patient.clinical.nd.tumor, dict, name = "per.patient.clinical.nd.tumor")
  # 
  # # NOTE: summary statistics are only from patients that have nd+tumor samples.
  # clinical_summary <- summarize_clinical_parameters(per.patient.clinical.nd.tumor)
  # 
  # # Backup the new versions with a dated archive 
  # Snapshot(prefix = "s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/Integrated")
  # 
  
  