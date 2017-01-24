
table_merge <- function(per.file, per.patient){
  
  s3joint    <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/JointData"

  #######################
  # Merge per-patient data onto per-file table, this will be redundant
  df <-  merge_table_files(df1 = per.file, df2 = per.patient, id = c("Patient", "Study"))
  
  #######################
  # CNV
  print("CNV Merge........................................", quote = F)
  cnv <- GetS3Table(file.path(s3joint,"curated_CNV_ControlFreec.txt"))
  df <-  merge_table_files(df1 = df, df2 = cnv, id = "File_Name")
  
  #######################
  # Biallelic Inactivation Flags
  print("BI Merge.........................................", quote = F)
  bi <- GetS3Table(file.path(s3joint,"curated_BiallelicInactivation_Flag.txt"))
  df <-  merge_table_files(df1 = df, df2 = bi, id = "File_Name")
  
  #######################
  # SNV
  # print("SNV Merge........................................", quote = F)
  # bi <- GetS3Table(file.path(s3joint,"curated_SNV_mutect2.txt"))
  # df <-  merge_table_files(df1 = df, df2 = snv, id = "File_Name")
  
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

