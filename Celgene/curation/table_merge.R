
table_merge <- function(per.file, per.patient){
  
  s3joint    <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/JointData"

  #######################
  # Merge per-patient data onto per-file table, this will be redundant
  df <-  merge_table_files(df1 = per.file, df2 = per.patient, id = c("Patient", "Study"))
  
  #######################
  # CNV
  print("CNV Merge........................................", quote = F)
  new <- GetS3Table(file.path(s3joint,"curated_CNV_ControlFreec.txt"))
  new <- filter(new, new$File_Name %in% per.file$File_Name)
  df <-  merge_table_files(df, new, id = "File_Name")
  
  #######################
  # Biallelic Inactivation Flags
  print("BI Merge.........................................", quote = F)
  new <- GetS3Table(file.path(s3joint,"curated_BiallelicInactivation_Flag.txt"))
  new <- filter(new, new$File_Name %in% per.file$File_Name)
  df <-  merge_table_files(df, new, id = "File_Name")
  
  #######################
  # SNV
  # print("SNV Merge........................................", quote = F)
  # new <- GetS3Table(file.path(s3joint,"curated_SNV_mutect2.txt"))
  # new <- filter(new, new$File_Name %in% per.file$File_Name)
  # df <-  merge_table_files(df, new, id = "File_Name")
  
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
  df
}

