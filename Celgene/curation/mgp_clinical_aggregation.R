## drozelle@ranchobiosciences.com
## 2016-10-17

# vars
d <- format(Sys.Date(), "%Y-%m-%d")
source("curation_scripts.R")
source("qc_and_summary.R")
source("table_merge.R")


# locations
s3clinical <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData"
local      <- CleanLocalScratch()

# We are editing the dictionary spreadsheet locally, so push latest to s3
system(  paste('aws s3 cp',"mgp_dictionary.xlsx" , file.path(s3clinical, "ProcessedData", "Integrated", "mgp_dictionary.xlsx"), "--sse ", sep = " "))

### if appropriate, run curation scripts
# source("curate_DFCI.R")
# source("curate_MMRF_IA9.R")
# source("curate_UAMS.R")
# source("curate_JointData.R")

# copy curated files locally
system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData", "Integrated", "mgp_dictionary.xlsx"), file.path(local, "mgp_dictionary.xlsx"), sep = " "))
system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData", "DFCI"), local, '--recursive --exclude "*" --include "curated*"', sep = " "))
system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData", "MMRF_IA9"), local, '--recursive --exclude "*" --include "curated*"', sep = " "))
system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData", "UAMS"), local, '--recursive --exclude "*" --include "curated*"', sep = " "))
system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData", "JointData/curated_All_translocation_Summaries_from_BWalker_2016-10-04_zeroed_dkr.txt"), local, sep = " "))


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

  # qc and summary    
  per.file <- remove_invalid_samples(per.file)
  per.file$Sample_Name_Tissue_Type <- paste(per.file$Sample_Name, per.file$Tissue_Type, sep="_")
  per.file <- cytogenetic_consensus_calling(per.file)
  
  report_unique_patient_counts(per.file, sink_file = file.path(local,"report_unique_patient_counts.txt"))

 
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
  # qc and summary    
  per.patient <-  remove_unsequenced_patients(per.patient, per.file)
  per.patient <-  add_inventory_flags(per.patient, per.file)
  inventory_counts <- get_inventory_counts(per.patient)
  
  # write PER-FILE and PER-PATIENT
  response <- write_to_s3integrated(per.file,    name = "PER-FILE_clinical_cyto.txt")
  response <- write_to_s3integrated(per.patient, name = "PER-PATIENT_clinical.txt")
  
  # Merge clinical data tables with genomic results, but warning: these functions takes a long time!
  per.file.all    <- table_merge()
  per.patient.nd.tumor.all <- collapse_to_patient(per.file.all)
  per.patient.nd.tumor.clinical <- subset_clinical_columns(per.patient.nd.tumor.all)
  
  export_sas(per.patient.nd.tumor.all, dict, name = "per.patient.nd.tumor.all")
  export_sas(per.patient.nd.tumor.clinical, dict, name = "per.patient.nd.tumor.clinical")
  
  # NOTE: summary statistics are only from patients that have nd+tumor samples.
  clinical_summary <- summarize_clinical_parameters(per.patient.nd.tumor.clinical)
  
  
  
  