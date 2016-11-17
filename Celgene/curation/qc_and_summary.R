
remove_invalid_samples <- function(df){
# manually remove patients marked as excluded in the DFCI study
dfci_discontinued_patients <- c("PD4282a", "PD4282b", "PD4282c", "PD4287a", "PD4287b", "PD4287c", 
                                "PD4297a", "PD4297b", "PD4297c", "PD4298a", "PD4298b")

df <- df[!(df$File_Name %in% dfci_discontinued_patients),]
df <- df[!is.na(df$File_Name),]

if( "File_Path" %in% names(df) ) {df <- df[!is.na(df$File_Path),]}
df
}

remove_sensitive_columns <- function(df, dict){
  sensitive_columns <- dict[dict$sensitive == "1","names"]
  df[,!(names(df) %in% sensitive_columns)]
}

remove_unsequenced_patients <- function(p,f){
  excluded_patients <- unique(p$Patient)[!unique(p$Patient) %in% unique(f$Patient)]
  warning(paste(length(excluded_patients), "patients did not have sequence data and were removed", sep = " "))
  p[!p$Patient %in% excluded_patients,]
}

report_unique_patient_counts <- function(df, sink_file = "/tmp/unique_patient_counts.txt"){
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

  dat <- df_perfile
  df_perpatient[["INV_Has.ND.sample"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Disease_Status", value = "ND", unique_match = F)),1,0)
  df_perpatient[["INV_Has.R.sample"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Disease_Status", value = "R", unique_match = F)),1,0)
  df_perpatient[["INV_Has.Normal.sample"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sample_Type", value = "Normal", unique_match = F)),1,0)
  df_perpatient[["INV_Has.NotNormal.sample"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sample_Type", value = "NotNormal", unique_match = F)),1,0)

  dat <- df_perfile[df_perfile$Disease_Status == "ND",]
  df_perpatient[["INV_Has.ND.Normal.sample"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sample_Type", value = "Normal", unique_match = F)),1,0)
  df_perpatient[["INV_Has.ND.NotNormal.sample"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sample_Type", value = "NotNormal", unique_match = F)),1,0)
  df_perpatient[["INV_Has.ND.Normal.NotNormal.sample"]] <- ifelse(df_perpatient[["INV_Has.ND.Normal.sample"]] + df_perpatient[["INV_Has.ND.NotNormal.sample"]] == 2,1,0)
  
  dat <- df_perfile[df_perfile$Disease_Status == "ND",]
  df_perpatient[["INV_Has.ND.WES"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sequencing_Type", value = "WES", unique_match = F)),1,0)
  df_perpatient[["INV_Has.ND.RNASeq"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sequencing_Type", value = "RNA-Seq", unique_match = F)),1,0)
  df_perpatient[["INV_Has.ND.WGS"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sequencing_Type", value = "WGS", unique_match = F)),1,0)
 
  dat <- df_perfile[df_perfile$Disease_Status == "R",]
  df_perpatient[["INV_Has.R.WES"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sequencing_Type", value = "WES", unique_match = F)),1,0)
  df_perpatient[["INV_Has.R.RNASeq"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sequencing_Type", value = "RNA-Seq", unique_match = F)),1,0)
  df_perpatient[["INV_Has.R.WGS"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "Sequencing_Type", value = "WGS", unique_match = F)),1,0)
  
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

  dat <- df_perpatient
  df_perpatient[["INV_Has.ISS"]]     <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "D_ISS",     value = "\\d", unique_match = F)),1,0)
  df_perpatient[["INV_Has.OS"]]      <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "D_OS",      value = "\\d", unique_match = F)),1,0)
  df_perpatient[["INV_Has.OS_Flag"]] <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "D_OS_FLAG", value = "\\d", unique_match = F)),1,0)
  df_perpatient[["INV_Has.PFS"]]     <- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "D_PFS",     value = "\\d", unique_match = F)),1,0)
  df_perpatient[["INV_Has.PFS_Flag"]]<- ifelse(unlist(lapply(df_perpatient$Patient, check_by_patient, dat = dat, field = "D_PFS_FLAG",value = "\\d", unique_match = F)),1,0)
  
  df_perpatient
}


# # aggregate for Andrew's Sage summary
# # 
# # gender <- table(mmrf.clinical$D_Gender)
# # summary_stats <- data.frame(N        = nrow(mmrf.clinical),
# #            F.M      = paste(c(gender["Female"], gender["Male"]), collapse = ","),
# #            Mean.Age = round(mean(as.numeric(mmrf.clinical$D_Age), na.rm = T),2),
# #            Mean.OS  = round(mean(mmrf.clinical$D_OS, na.rm = T), 2),
# #            Mean.PFS  = round(mean(mmrf.clinical$D_PFS, na.rm = T), 2),
# #            Proportion.Deceased     = round(mean(mmrf.clinical$D_OS_FLAG, na.rm = T), 2),
# #            Proportion.Progressing  = round(mean(mmrf.clinical$D_PD_FLAG, na.rm = T), 2)
# #            )
# # write.table(summary_stats, "../data/curated/summary_stats_for_Andrew_20160922.txt", sep = "\t", col.names = T, row.names = F)
# 
# # join integrated tables into a single one for easy filtering
# 
# names(integrated.clinical) %in% names(integrated.cytogenetic)
# names(integrated.clinical) %in% names(inventory)
# names(integrated.cytogenetic) %in% names(integrated.clinical)
# 
# integrated <- merge(integrated, inventory, by = c("Patient", "Study"), all = T)
# 
# # sort to keep MMRF on the top (just my preference)
# integrated[['Study']] <- as.factor(integrated$Study)
# proper_order <- c("MMRF", levels(integrated$Study)[!(levels(integrated$Study) %in% "MMRF")])
# integrated[['Study']] <- factor(integrated$Study, levels = proper_order)
# integrated <- integrated[order(integrated$Study),]
# 
# write.table(integrated, paste0("../data/curated/INTEGRATED/","INTEGRATED" ,"_patient_clinical_cyto_inventory_", d,".txt"), row.names = F, col.names = T, sep = "\t", quote = F)
# 
# # save the MMRF portion to a SAGE-specific upload file
# sage <- integrated[integrated$Study == "MMRF",]
# write.table(sage, paste0("../../sage/data/","MMRF_patient_clinical_cyto_inventory_for_SAGE-", d,".txt"), row.names = F, col.names = T, sep = "\t", quote = F)
# 
# # verify proper data typing
# bak <- integrated
# foo <- "D_Gender"
# 
# meta <- XLConnect::readWorksheetFromFile(file = "../data/integrated_columns.xlsx", sheet = 1, startRow = 2)
# factor_columns <- meta[meta$type == "Factor","names"]
# 
# for(foo in factor_columns){
#   integrated[integrated[[foo]] == "" & !is.na(integrated[[foo]]),foo] <- NA
#   integrated[[foo]] <- as.factor(integrated[[foo]])
#   print(levels(integrated[[foo]]))
# }
# 
# numeric_columns <- meta[meta$type == "Numeric","names"]
# 
# for(foo in numeric_columns){
#   integrated[integrated[[foo]] == "" & !is.na(integrated[[foo]]),foo] <- NA
#   integrated[[foo]] <- as.numeric(integrated[[foo]])
#   print(summary(integrated[[foo]]))
# }
# 
# 
# # write out text datafile for SAS
# library(foreign)
# foreign::write.foreign(integrated, 
#                        datafile = paste0("../data/curated/sas/","INTEGRATED" ,"_patient_clinical_cyto_inventory_", d,".txt"), 
#                        codefile = paste0("../data/curated/sas/","INTEGRATED" ,"_patient_clinical_cyto_inventory_", d,".sas"),
#                        package="SAS")
# 
