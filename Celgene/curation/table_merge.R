
table_merge <- function(){
  # merge final clinical tables with desired summary analysis tables
  s3clinical      <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData"
  local_path      <- "/tmp/curation"
  if(!dir.exists(local_path)){dir.create(local_path)}
  
  source("curation_scripts.R")
  write_to_s3integrated <- s3_writer(s3_path = "/ClinicalData/ProcessedData/Integrated/")
  
  # copy curated files locally
  system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData", "Integrated"), local_path, '--recursive --exclude "*" --include "PER*"', sep = " "))
  system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData", "JointData"), local_path, '--recursive --exclude "*" --include "curated*"', sep = " "))
  
  #######################
  # add patient level information, this will be redundant
  
  name <- "PER-FILE_clinical_cyto.txt"
  per_file <- read.delim(file.path(local_path,name), sep = "\t", check.names = F, as.is = T, stringsAsFactors = F)
  
  name <- "PER-PATIENT_clinical.txt"
  per_patient <- read.delim(file.path(local_path,name), sep = "\t", check.names = F, as.is = T, stringsAsFactors = F)
  
  df <-  merge_table_files(df1 = per_file, df2 = per_patient, id = c("Patient", "Study"))
  
  #######################
  # CNV
  print("CNV Merge........................................", quote = F)
  
  name <- "curated_CNV_ControlFreec.txt"
  cnv <- read.delim(file.path(local_path,name), sep = "\t", check.names = F, as.is = T, stringsAsFactors = F)
  
  df <-  merge_table_files(df1 = df, df2 = cnv, id = "File_Name")
  
  #######################
  # Biallelic Inactivation Flags
  print("BI Merge.........................................", quote = F)
  
  name <- "curated_BiallelicInactivation_Flag.txt"
  bi <- read.delim(file.path(local_path,name), sep = "\t", check.names = F, as.is = T, stringsAsFactors = F)
  
  df <-  merge_table_files(df1 = df, df2 = bi, id = "File_Name")
  
  #######################
  # SNV
  print("SNV Merge........................................", quote = F)
  
  name <- "curated_SNV_mutect2.txt"
  snv <- read.delim(file.path(local_path,name), sep = "\t", check.names = F, as.is = T, stringsAsFactors = F)
  
  df <-  merge_table_files(df1 = df, df2 = snv, id = "File_Name")
  
  #######################
  # put back the all table
  write_to_s3integrated(df, name = "PER-FILE_ALL.txt")

  return(df)
  }

collapse_to_patient <- function(df){
  #######################
  # collapse_file_to_patient
  #  this needs to reduce the PER-FILE organized table such that it contains a single *ND Tumor* row for each patient
  
  # df <- read.delim(file.path(local_path,"tmp.txt"), stringsAsFactors = F, as.is = T, check.names = F)
  df <- df[df$Sample_Type_Flag == 1 & df$Disease_Status == "ND",]
  
  df <- aggregate.data.frame(df, by = list(df$Patient), function(x){
    x <- unique(x)
    x <- x[!is.na(x)]
    # if(length(x) > 1){print(x)}
    paste(x, collapse = "; ")
  })
  
  df[,c("Group.1","File_Name" ,"File_Name_Actual","File_Path")] <- NULL
  
  # write to S3
  write_to_s3integrated(df, name = "PER-PATIENT_nd_tumor_ALL.txt")

  return(df)
}

subset_clinical_columns <- function(df){
  # remove genomic columns
  remove_prefix <- c("SNV", "CNV", "BI")
  n <- names(df)
  for(p in remove_prefix){
    n <- n[ !grepl(p, n) ]
  }
  df <- df[, n]
  write_to_s3integrated(df, name = "PER-PATIENT_nd_tumor_clinical.txt")
  return(df)
}

