table_merge <- function(per.file){
  # this function performs a cbind operation of molecular data
  # CNV, BI, SNV, and RNA-Seq counts to the per.file table
  
  
  s3joint    <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/JointData"
  system(paste('aws s3 cp', s3joint, local, '--recursive --exclude "*" --include "curated*" --exclude "archive*"', sep = " "))
  
  #######################
  df    <-  as.data.table(per.file)
  setkey(df, File_Name)
  
  #######################
  files <- list.files(local, pattern = "^curated", full.names = T)
  new        <- lapply(files, fread)
  names(new) <- gsub("curated_(.*?)_.*", "\\1", tolower(basename(files)))
  
  # Check that all tables have a File_Name column
  if( !all(sapply(new, function(x){"File_Name" %in% names(x)})) ){
    stop("At least one curated table is missing the File_Name column")}
  
  lapply(new, setkey, File_Name)
  
  #######################
  
  all <- df
  for( i in new ){
    all <- merge(all, i, all.x=TRUE)  
  }  
  
  # verify all column added
  sum(sapply(c(list(per.file = df), new), dim)[2,]) - length(new)
  
  # verify no new rows added to curated per.file table
  dim(df)[1] == dim(all)[1]
  
  # export table of rows that were not incorporated
  lapply(1:length(new), function(i){
    unmatched <- new[[i]][!File_Name %in% df$File_Name]
    name      <- paste0("unmatched_during_table_merge_", names(new)[i], ".txt")
    PutS3Table(unmatched, file.path(s3, "ClinicalData/ProcessedData/JointData", name))
    dim(unmatched)[1]
  })
  
  return(all)
}

subset_clinical_columns <- function(df){
  # remove genomic columns
  remove_prefix <- c("SNV", "CNV", "BI")
  n <- names(df)
  for(p in remove_prefix){
    n <- n[ !grepl(p, n) ]
  }
  df <- df[, n]
  df
}


merge_table_files <- function(df1, df2, id = "File_Name"){
  
  df <- merge(x = df1, y = df2, by = id, all = T)
  
  if(dim(df)[1] != dim(df1)[1]){
    warning(paste("merge of did not retain proper dimensionality", sep = " "))
    # print ids of additional columns
    print( df[!(df$id %in% df1$id) ,id])
    return(df)
  }else{df}
}




write.object <- function(x, path = local, env){
  if( is.environment(env)){  
    df <- get(x, envir = env)
  }else{
    df <- get(x)
  }
  write.table(df, 
              file.path(path, paste0(x,".txt")), 
              sep = "\t", 
              row.names = F, 
              col.names = T, 
              quote = F   )
  file.path(path, paste0(x,".txt"))
}

# This script is meant to facilitate generation of all downstream tables derived
# from a basic per.patient and per.file table. This includes joining to molecular 
# data tables to create "all" versions, filtering for "nd.tumor" versions, collapsing 
# to per.sample versions, and generating a single unified output table for sas.
# 
# This is run without any parameter, just make sure you PutS3Table() any changes to 
# <per.file.clinical.txt> or <per.patient.clinical.txt> before running.

table_process <- function(){
  
  source("qc_and_summary.R")
  per.file    <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Integrated", "per.file.clinical.txt"))
  per.patient <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Integrated", "per.patient.clinical.txt"))
  
  ### Merge and filter tables ----------------------------------------------------
  
  per.patient           <- remove_unsequenced_patients(per.patient, per.file)
  per.patient.clinical  <- per.patient # rename for clarity
  per.file.clinical     <- per.file    # rename for clarity
  
  per.file.all          <- table_merge(per.file.clinical)
  
  # kill here
  per.file.all          <- remove_invalid_samples(per.file.all)
  
  # update inventory flags to per.patient after table merge since patient inventory flags
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
  
  # if you just want to generate a new unified table you can uncomment
  # per.file.clinical.nd.tumor    <- GetS3Table(file.path(s3, 
  # "ClinicalData/ProcessedData/Integrated", "per.file.clinical.nd.tumor.txt"))
  # per.patient.clinical.nd.tumor <- GetS3Table(file.path(s3, 
  # "ClinicalData/ProcessedData/Integrated", "per.patient.clinical.nd.tumor.txt"))
  
  # make a unified table (file and patient variables) for nd.tumor data
  unified.clinical.nd.tumor <- per.file.clinical.nd.tumor %>%
    group_by(Study, Patient) %>%
    summarise_all(.funs = funs(Simplify(.))) %>%
    ungroup() %>%
    select(Patient, Study_Phase, Visit_Name, Sample_Name, Sample_Type, Sample_Type_Flag, Sequencing_Type, Disease_Status, Tissue_Type:CYTO_t.14.20._CONSENSUS) %>%
    full_join(per.patient.clinical.nd.tumor, ., by = "Patient") %>%
    select(-c(starts_with("INV"))) %>%
    filter(Disease_Type == "MM" | is.na(Disease_Type))
  
  
  # write un-dated PER-FILE and PER-PATIENT files to S3
  write_to_s3integrated <- function(object, name){
    PutS3Table(object = object, s3.path = file.path(s3,"ClinicalData/ProcessedData/Integrated", name))
  }
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
  
  write_to_s3integrated(unified.clinical.nd.tumor      ,name = "unified.clinical.nd.tumor.txt")
  
  RPushbullet::pbPost("note", title = "table_process done")  
}