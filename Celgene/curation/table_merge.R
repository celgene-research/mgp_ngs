
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
  # snv <- GetS3Table(file.path(s3joint,"curated_SNV_mutect2.txt"))
  # df <-  merge_table_files(df1 = df, df2 = snv, id = "File_Name")
  
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

