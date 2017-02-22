
# This is a manual patch for filling in missing data for rows that are for all intents
# the same. (e.g., if D_PrevBoneMarrowTransplant is called for one File_Name, it should be the same for all other
# File_Name rows of the same Sample_Name)
# by specifies the grouping to consider equal
# columns is a list of columns to perform this operation on.
# FillCommonRows <- function(df, by = "Sample_Name", columns){
# 
#   ddply(df, .(Sample_Name), summarize, unique(D_PrevBoneMarrowTransplant))
#   
#   
# }


# df <- per.file
# by = "Sample_Name"
# columns <- c("D_PrevBoneMarrowTransplant", "Sample_Study_Day" )





# columns required for df: c("Sample_Name", "File_Path", "Excluded_Flag")
remove_invalid_samples <- function(df){
  
  # Only keep rows where we have a File_Name
  if( "File_Path" %in% names(df) ){ df <- filter(df, !is.na(File_Path)) }
  
  # Warn if any don't have a Sample_Name
  if( any(is.na(df$Sample_Name)) ){
    warning(paste(sum(is.na(df$Sample_Name)),  
                  "rows do not have a valid Sample_Name",
                  sep = " "))  }
  
  # Get the table of excluded patients
  ex <- GetS3Table(file.path("s3://celgene.rnd.combio.mmgp.external",
                             "ClinicalData/ProcessedData/JointData",
                             "Excluded_Samples.txt"))
  
  excluded.files <- df %>% 
    filter(Sample_Name %in% ex$Sample_Name |
           Excluded_Flag == "1" )%>%
    select(Sample_Name, File_Name, Sequencing_Type) %>%
    arrange(File_Name)
  
  excluded.files <- merge(excluded.files, ex, by = "Sample_Name", all.x = T)
  
  # generate disease.type column based on file types
  df <- df %>% group_by(Patient) %>%
    mutate(tissue_cell = paste(tolower(Tissue_Type), tolower(Cell_Type), sep="-")) %>%
    mutate(Disease_Type = ifelse("pb-cd138pos" %in% tissue_cell, "PCL", "MM"))%>%
    select(-tissue_cell) %>%
    ungroup()
  
  # remove PCL files by enabling this region
  remove.pcl.files <- FALSE
  if(remove.pcl.files){ 
    
    pcl.files <- df %>%
      subset(Disease_Type == "PCL")%>%
      select(Sample_Name, File_Name, Sequencing_Type) %>%
      mutate(Note = "patient has Plasma Cell Leukemia (PB with CD138 cells)") %>%
      arrange(File_Name)
    
    excluded.files <- rbind(excluded.files, pcl.files)
    }
  
  # Push table of removed files to S3 and throw warning
  if( nrow(excluded.files) > 0 ){
    warning(paste(nrow(excluded.files),  
                  "files were removed that have been excluded",
                  sep = " "))
    PutS3Table(excluded.files, "s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/Integrated/Excluded_Samples.txt")
  }
  
  # Remove excluded files from table and return
  df <- df %>% filter(!(File_Name %in% excluded.files$File_Name))
  as.data.frame(df)
}

remove_sensitive_columns <- function(df, dict){
  sensitive_columns <- dict[dict$sensitive == "1","names"]
  df[,!(names(df) %in% sensitive_columns)]
}

remove_unsequenced_patients <- function(p,f){
  unsequenced_patients <- unique(p$Patient)[!unique(p$Patient) %in% unique(f$Patient)]
  warning(paste(length(unsequenced_patients), "patients did not have sequence data and were removed", sep = " "))
  
  write.object("unsequenced_patients", env = environment())
  p[!p$Patient %in% unsequenced_patients,]
}

report_unique_patient_counts <- function(df, sink_file = file.path(local, "unique_patient_counts.txt")){
  sink(file = sink_file) 
  df <- aggregate.data.frame(per.file[,"Patient"], by = list(per.file$Study, per.file$Sequencing_Type, per.file$Disease_Status), 
                             function(x){  length(unique(x))  })
  names(df) <- c("Study", "Sequencing_Type", "Disease_Status", "Unique_Patient_Count")
  print(df)
  cat("\n")
  df <- aggregate.data.frame(per.file[,"Patient"], by = list(per.file$Study, per.file$Disease_Status), 
                             function(x){  length(unique(x))  })
  names(df) <- c("Study", "Disease_Status", "Unique_Patient_Count")
  print(df)
  cat("\n")
  
  df <- aggregate.data.frame(per.file[,"Patient"], by = list(per.file$Study, per.file$Sequencing_Type), 
                             function(x){  length(unique(x))  })
  names(df) <- c("Study", "Sequencing_Type", "Unique_Patient_Count")
  print(df)
  cat("\n")
  
  sink()
}

add_inventory_flags <- function(df_perpatient, df_perfile){
  # df_perpatient <- per.patient
  # df_perfile <- per.file
  
  check_by_patient <- check.value("Patient")
  
  df_perpatient[["INV_Has.sample"]] <- ifelse(df_perpatient$Patient %in% df_perfile$Patient, 1,0)
  
  dat <- df_perfile
  df_perpatient[["INV_Has.ND.sample"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Disease_Status", value = "ND", unique_match = F)),1,0)
  df_perpatient[["INV_Has.R.sample"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Disease_Status", value = "R", unique_match = F)),1,0)
  df_perpatient[["INV_Has.Normal.sample"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sample_Type", value = "Normal", unique_match = F)),1,0)
  df_perpatient[["INV_Has.NotNormal.sample"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sample_Type", value = "NotNormal", unique_match = F)),1,0)
  
  dat <- df_perfile[df_perfile$Disease_Status == "ND",]
  df_perpatient[["INV_Has.ND.Normal.sample"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sample_Type", value = "Normal", unique_match = F)),1,0)
  df_perpatient[["INV_Has.ND.NotNormal.sample"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sample_Type", value = "NotNormal", unique_match = F)),1,0)
  df_perpatient[["INV_Has.ND.Normal.NotNormal.sample"]] <- ifelse(df_perpatient[["INV_Has.ND.Normal.sample"]] + df_perpatient[["INV_Has.ND.NotNormal.sample"]] == 2,1,0)
  
  dat <- df_perfile
  df_perpatient[["INV_Has.WES"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sequencing_Type", value = "WES", unique_match = F)),1,0)
  df_perpatient[["INV_Has.RNASeq"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sequencing_Type", value = "RNA-Seq", unique_match = F)),1,0)
  df_perpatient[["INV_Has.WGS"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sequencing_Type", value = "WGS", unique_match = F)),1,0)
  
  dat <- df_perfile[df_perfile$Disease_Status == "ND",]
  df_perpatient[["INV_Has.ND.WES"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sequencing_Type", value = "WES", unique_match = F)),1,0)
  df_perpatient[["INV_Has.ND.RNASeq"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sequencing_Type", value = "RNA-Seq", unique_match = F)),1,0)
  df_perpatient[["INV_Has.ND.WGS"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sequencing_Type", value = "WGS", unique_match = F)),1,0)
  
  dat <- df_perfile[df_perfile$Disease_Status == "R",]
  df_perpatient[["INV_Has.R.WES"]]    <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sequencing_Type", value = "WES", unique_match = F)),1,0)
  df_perpatient[["INV_Has.R.RNASeq"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sequencing_Type", value = "RNA-Seq", unique_match = F)),1,0)
  df_perpatient[["INV_Has.R.WGS"]]    <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sequencing_Type", value = "WGS", unique_match = F)),1,0)
  
   # more complex columns for elaborate selection modes
  x <- "Sample_Type_Flag"
  tumor <- !is.na(df_perfile[[x]]) & (df_perfile[[x]] == "1")  
  length(unique(df_perfile[tumor,"Patient"]))
  
  x   <- "Disease_Status"
  nd  <- !is.na(df_perfile[[x]]) & (df_perfile[[x]] == "ND")  
  length(unique(df_perfile[nd,"Patient"]))
  
  r   <- !is.na(df_perfile[[x]]) & (df_perfile[[x]] == "R")  
  length(unique(df_perfile[r,"Patient"]))
  
  x   <- "Sequencing_Type"
  wes <- !is.na(df_perfile[[x]]) & (df_perfile[[x]] == "WES")  
  length(unique(df_perfile[wes,"Patient"]))
  
  wgs <- !is.na(df_perfile[[x]]) & (df_perfile[[x]] == "WGS")  
  length(unique(df_perfile[wgs,"Patient"]))
  
  rna <- !is.na(df_perfile[[x]]) & (df_perfile[[x]] == "RNA-Seq")  
  length(unique(df_perfile[rna,"Patient"]))

  
  df_perfile[['Tumor.ND.WES']] <-  tumor & nd & wes
  df_perfile[['Tumor.R.WES']]  <-  tumor & r  & wes
  df_perfile[['Tumor.ND.RNA']] <-  tumor & nd & rna
  df_perfile[['Tumor.R.RNA']]  <-  tumor & r  & rna
  
  df_perpatient[['INV_Has.Tumor.ND.WES']] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = df_perfile, field = "Tumor.ND.WES", value = TRUE, unique_match = F)),1,0)
  df_perpatient[['INV_Has.Tumor.R.WES']] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = df_perfile, field = "Tumor.R.WES", value = TRUE, unique_match = F)),1,0)
  df_perpatient[['INV_Has.Tumor.ND.R.WES']] <- ifelse(df_perpatient$INV_Has.Tumor.ND.WES == "1" & df_perpatient$INV_Has.Tumor.R.WES == "1",1,0)
  df_perpatient[['INV_Has.Tumor.ND.RNA']] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = df_perfile, field = "Tumor.ND.RNA", value = TRUE, unique_match = F)),1,0)
  df_perpatient[['INV_Has.Tumor.R.RNA']] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = df_perfile, field = "Tumor.R.RNA", value = TRUE, unique_match = F)),1,0)
  df_perpatient[['INV_Has.Tumor.ND.R.RNA']] <- ifelse(df_perpatient$INV_Has.Tumor.ND.RNA == "1" & df_perpatient$INV_Has.Tumor.R.RNA == "1",1,0)
  df_perpatient[['INV_Has.Tumor.ND.R.WES.RNA']] <- ifelse(df_perpatient$INV_Has.Tumor.ND.R.WES == "1" & df_perpatient$INV_Has.Tumor.ND.R.RNA == "1",1,0)
  
  dat <- df_perpatient
  df_perpatient[["INV_Has.ISS"]]     <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "D_ISS",     value = "\\d", unique_match = F)),1,0)
  df_perpatient[["INV_Has.OS"]]      <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "D_OS",      value = "\\d", unique_match = F)),1,0)
  df_perpatient[["INV_Has.OS_Flag"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "D_OS_FLAG", value = "\\d", unique_match = F)),1,0)
  df_perpatient[["INV_Has.PFS"]]     <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "D_PFS",     value = "\\d", unique_match = F)),1,0)
  df_perpatient[["INV_Has.PFS_Flag"]]<- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "D_PFS_FLAG",value = "\\d", unique_match = F)),1,0)
  
  # consensus cytogenetic call counts for ND-tumor samples
  cyto_consensus_columns <- grep("CONSENSUS", names(df_perfile), value = T, ignore.case = T)
  dat <- df_perfile[df_perfile$Disease_Status == "ND" & df_perfile$Sample_Type_Flag == "1",]
  for(c in cyto_consensus_columns){
    c_name <- paste0("INV_Has.ND.NotNormal.", gsub("^.*_(.*_.*)$","\\1",c))
    df_perpatient[[c_name]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = c, value = "0|1", unique_match = F)),1,0)
  }
  
  # consensus cytogenetic call counts for R+tumor samples
  cyto_consensus_columns <- grep("CONSENSUS", names(df_perfile), value = T, ignore.case = T)
  dat <- df_perfile[df_perfile$Disease_Status == "R" & df_perfile$Sample_Type_Flag == "1",]
  for(c in cyto_consensus_columns){
    c_name <- paste0("INV_Has.R.NotNormal.", gsub("^.*_(.*_.*)$","\\1",c))
    df_perpatient[[c_name]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = c, value = "0|1", unique_match = F)),1,0)
  }
  
  
  df_perpatient
}


get_inventory_counts <- function(df_perpatient){
  df <- aggregate.data.frame(df_perpatient[,grepl("Has",names(df_perpatient))], by = list(df_perpatient$Study), function(x){
    sum(x == "1")
  })
  df <- as.data.frame(t(df), stringsAsFactors = F)
  names(df) <- df[1,]
  df <- df[2:nrow(df),]
  
  df["Total"] <- apply(df, MARGIN = 1, function(x){sum(as.integer(x))})
  
  df[['Category']] <- row.names(df)
  
  PutS3Table(df, file.path(s3, "ClinicalData/ProcessedData/Integrated", "report_inventory_counts.txt"))
  
  df$Category <- NULL
  df
}

summarize_clinical_parameters <- function(df_perpatient){
  df <- df_perpatient
  df[df==""] <- NA
  df[['coded_gender']] <- ifelse(df$D_Gender == "Male",1,0) #0=Female; 1=Male
  summary_fields <- c("coded_gender","D_Age", "D_OS", "D_PFS", "D_OS_FLAG", "D_PFS_FLAG")
  
  df <- aggregate.data.frame(df[, names(df) %in% summary_fields ], by = list(df$Study), function(x){
    round(mean(as.numeric(x), na.rm = T),2)
  })
  
  #rename and reorder
  names(df) <- c("Study", "Mean_Age", "Mean_OS_days", "Proportion_Deceased", "Mean_PFS_days", "Proportion_Progressed", "Proportion_Gender_male")
  df<- df[, c("Study", "Mean_Age", "Proportion_Gender_male", "Mean_OS_days", "Proportion_Deceased", "Mean_PFS_days", "Proportion_Progressed")]  
  
  write_to_s3integrated(df, "report_summary_statistics.txt")
  
  df
  
}

export_sas <- function(df, dict, name){
  
  # sas column names are very restrictive, and automatically edited if nonconformant
  # 32 char limit only symbol allowed is "_"
  # export to sas automatically replaces each symbol with "_", truncates to 32 but has
  # strange truncation rules (first lower case letters and then trailing upper case letters?)
  
  names(df) <- CleanColumnNamesForSAS(names(df))
  dict[['clean.names']] <- CleanColumnNamesForSAS(dict$names)
  
  ## specific column type encoding was removed because it causes
  ##  column order to be changed when imported. 
  ##  (factor columns first, then character, then numeric)
  #
  # factor_columns <- dict[dict$type == "Factor","clean.names"]
  # for(foo in factor_columns){
  #   df[df[[foo]] == "" & !is.na(df[[foo]]),foo] <- NA
  #   df[[foo]] <- as.factor(df[[foo]])
  #   }
  # 
  # numeric_columns <- dict[dict$type == "Numeric","clean.names"]
  # for(foo in numeric_columns){
  #   df[df[[foo]] == "" & !is.na(df[[foo]]),foo] <- NA
  #   df[[foo]] <- as.numeric(df[[foo]])
  # }
  # 
  # numeric_molecular_columns <- names(df)[grepl("^SNV_", names(df)) | 
  #                                        grepl("^CNV_", names(df)) | 
  #                                        grepl("^BI_", names(df)) ]
  # for(foo in numeric_molecular_columns){
  #   df[df[[foo]] == "" & !is.na(df[[foo]]),foo] <- NA
  #   df[[foo]] <- as.numeric(df[[foo]])
  # }
  # 
  # write out text datafile for SAS
  local.path <- file.path(local, "sas")
  if(!dir.exists(local.path)){dir.create(local.path)}
  
  root <- paste0(name, "_", d)
  local.data.path <- file.path(local.path, paste0(root,".txt"))
  local.code.path <- file.path(local.path, paste0(root,".sas"))
  
  foreign::write.foreign(df,
                         datafile = local.data.path,
                         codefile = local.code.path,
                         package="SAS")
  
  # edit sas import table such that empty columns have character length = 1
  system( paste('sed -i "s/\\$ 0$/\\$ 1/" ', local.code.path, sep = " "))
  
  system(paste("aws s3 cp", 
               local.data.path, 
               file.path(s3, "ClinicalData/ProcessedData/Integrated", "sas", paste0(root,".txt")),
               "--sse", sep = " "))
  system(paste("aws s3 cp", 
               local.code.path, 
               file.path(s3, "ClinicalData/ProcessedData/Integrated", "sas", paste0(root,".sas")),
               "--sse", sep = " "))
  
}





