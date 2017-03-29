## drozelle@ranchobiosciences.com
## 2016-10-17
# 
# 2017-03-22 This script was last used to incorporate MMRF IA10 data, but for future releases I
# plan to just edit the output from this aggregation script instead of starting format
# scratch source material every time
# 

source("curation_scripts.R")
source("qc_and_summary.R")

# locations
local <- CleanLocalScratch()

# copy curated files locally
system(  paste('aws s3 cp', file.path(s3, "ClinicalData/ProcessedData", "MMRF_IA9") , 
               local, '--recursive --exclude "*" --include "curated*"', sep = " "))
system(  paste('aws s3 cp', file.path(s3, "ClinicalData/ProcessedData", "JointData"), 
               local, '--recursive --exclude "*" --include "curated*"', sep = " "))

### import dictionary ----- ----------------------------------------------------
# The dictionary is used as a starting framework for each level table
# but since we are editing the dictionary spreadsheet locally, sync latest to s3 first
system(  paste('aws s3 cp', 'mgp_dictionary.xlsx' , file.path(s3, "ClinicalData/ProcessedData/Integrated/"), '--sse', sep = " "))
dict <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Integrated", "mgp_dictionary.xlsx"))
dict <- as.data.frame(dict[dict$active == 1,])

### FILE-LEVEL AGGREGATION -----------------------------------------------------
files              <- list.files(local, pattern = "curated*", full.names = T, recursive = T)
file_level_columns <- dict[grepl("file", dict$level), "names"]
per.file           <- data.frame(matrix(ncol = length(file_level_columns), nrow = 0))
names(per.file)    <- file_level_columns

for(f in files){
  print(f)
  new <-   read.delim(f, stringsAsFactors = F, check.names = F)
  per.file <- append_df(per.file, new, id = "File_Name", mode = "append")
}
  per.file[per.file == "NA"] <- NA
  per.file  <- remove_invalid_samples(per.file)
  saveRDS(per.file, file = "/tmp/recall/per.file.001.RData")
  
  # temporary fix to add disease.status fields to MMRF samples with unannotated visit.
  unmarked <- per.file[is.na(per.file$Disease_Status) & grepl("^MMRF", per.file$Sample_Name),"Sample_Name"]
  seq <- as.numeric(gsub("MMRF_[0-9]+_([0-9]+)_[BMP]+", "\\1", as.character(unmarked)))
  seq <- recode(seq, "ND", "R", "R", "R")
  per.file[is.na(per.file$Disease_Status) & grepl("^MMRF", per.file$Sample_Name),"Disease_Status"] <- seq
  # saveRDS(per.file, file = "/tmp/recall/per.file.001b.RData")
    
  # temporary fix to add sequencing type for some MMRF files
  per.file[is.na(per.file$Sequencing_Type),"Sequencing_Type"] <- gsub(".*\\/([WGSWESRNASeq\\-]+)\\/.*","\\1",per.file[is.na(per.file$Sequencing_Type),"File_Path"])
  
  per.file  <- cytogenetic_consensus_calling(per.file)
  # saveRDS(per.file, file = "/tmp/recall/per.file.002.RData")
  
### PATIENT-LEVEL AGGREGATION --------------------------------------------------
patient_level_columns <- dict[grepl("patient", dict$level)  ,"names"] 
per.patient <- data.frame(matrix(ncol = length(patient_level_columns), nrow = 0))
names(per.patient) <- patient_level_columns
  
  for(f in files){
    print(f)
    new <-   read.delim(f, stringsAsFactors = F, check.names = F)
    per.patient <- append_df(per.patient, new, id = "Patient", mode = "append")
  }

### Merge and filter tables ----------------------------------------------------

  per.patient           <- remove_unsequenced_patients(per.patient, per.file)
  per.patient.clinical  <- per.patient # rename for clarity
  per.file.clinical     <- per.file    # rename for clarity
  
  
  # currently table merge throws dimension error since CNV contains clinically lost patients, it's OK
  per.file.all          <- table_merge(per.file.clinical)
  per.file.all          <- remove_invalid_samples(per.file.all)
  # saveRDS(per.file.all, file = "/tmp/recall/per.file.all.003.RData")
  
  # add inventory flags to per.patient after table merge since patient inventory flags
  #  are not applicable to per-file rows
  per.patient.clinical  <- add_inventory_flags(per.patient.clinical, per.file.clinical)
  
  
  # Collapse file > sample for some analyses
  per.sample.all        <- local_collapse_dt(per.file.all, column.names = "Sample_Name")
  per.sample.clinical   <- subset_clinical_columns(per.sample.all)
  
  # Filter for ND-tumor sample only
  per.file.all.nd.tumor         <- subset(per.file.all,   Sample_Type_Flag == 1 & Disease_Status == "ND")
  per.sample.all.nd.tumor       <- subset(per.sample.all, Sample_Type_Flag == 1 & Disease_Status == "ND")
  per.patient.clinical.nd.tumor <- subset(per.patient.clinical, INV_Has.ND.NotNormal.sample == 1)
  
  # Select clinical column subsets
  per.file.clinical.nd.tumor    <- subset_clinical_columns(per.file.all.nd.tumor)
  per.sample.clinical.nd.tumor  <- subset_clinical_columns(per.sample.all.nd.tumor)
  # saveRDS(per.file.clinical.nd.tumor, file = "/tmp/recall/per.file.clinical.nd.tumor.004.RData")
  
  # # qc and summary
  # inventory_counts <- get_inventory_counts(per.patient.clinical)
  # report_unique_patient_counts(per.file.clinical)

  # write un-dated PER-FILE and PER-PATIENT files to S3
  
  write_to_s3integrated <- function(object, name){
    PutS3Table(object = object, s3.path = file.path(s3,"ClinicalData/ProcessedData/Integrated/archive", name))
  }
  # write_to_s3integrated(per.file.clinical              ,name = "per.file.clinical.txt")
  write_to_s3integrated(per.file.clinical.nd.tumor     ,name = "per.file.clinical.nd.tumor_IA9_2017-03-23.txt")
  # write_to_s3integrated(per.file.all                   ,name = "per.file.all.txt")
  # write_to_s3integrated(per.file.all.nd.tumor          ,name = "per.file.all.nd.tumor.txt")
  # 
  # write_to_s3integrated(per.sample.clinical            ,name = "per.sample.clinical.txt")
  # write_to_s3integrated(per.sample.clinical.nd.tumor   ,name = "per.sample.clinical.nd.tumor.txt")
  # write_to_s3integrated(per.sample.all                 ,name = "per.sample.all.txt")
  # write_to_s3integrated(per.sample.all.nd.tumor        ,name = "per.sample.all.nd.tumor.txt")
  # 
  # write_to_s3integrated(per.patient.clinical           ,name = "per.patient.clinical.txt")
  write_to_s3integrated(per.patient.clinical.nd.tumor  ,name = "per.patient.clinical.nd.tumor_IA9_2017-03-23.txt")

  RPushbullet::pbPost("note", "mgp_clinical_agg done")
  
  