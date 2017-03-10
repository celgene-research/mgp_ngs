
table_merge <- function(per.file){
  
  s3joint    <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/JointData"

  #######################
  df <-  per.file
  
  #######################
  # CNV
  print("CNV Merge........................................", quote = F)
  new <- GetS3Table(file.path(s3joint,"curated_cnv_ControlFreec_2017-02-21.txt"))
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
  print("SNV Merge........................................", quote = F)
  new <- GetS3Table(file.path(s3joint,"curated_SNV_BinaryConsensus_2017-02-13.txt"))
  new <- filter(new, new$File_Name %in% per.file$File_Name)
  df <-  merge_table_files(df, new, id = "File_Name")
  
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

