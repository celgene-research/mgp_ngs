
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
# countable_fields <- grep("Has", names(inventory), value = T)
# for(i in countable_fields){
#   inventory[[i]] <- as.numeric(inventory[[i]])
# }
# 
# summary <- aggregate.data.frame(inventory[,countable_fields], by = list(inventory$Study), sum)
# write.table(summary, paste0("../data/curated/counts/","SUMMARY_patient_inventory_", d,".txt"), row.names = F, col.names = T, sep = "\t", quote = F)
# 
# ## Troubleshooting
# # Does "extra" MMRF patient numbers exist because they are not Relevant
# # tmp <- inventory[inventory$Patient %in% relevant, ]
# # aggregate.data.frame(tmp[,countable_fields], by = list(tmp$Study), sum)
# 
# # Count patients from each source
# # IA8 README Seq QC table
# length(unique(mmrf.seqqc$Patients..KBase_Patient_ID))
# # 706
# 
# # IA8 README Seq QC table with excluded sample rows removed
# included_mmrf.seqqc <- mmrf.seqqc[!grepl("Exclude", mmrf.seqqc$MMRF_Release_Status),]
# length(unique(included_mmrf.seqqc$Patients..KBase_Patient_ID))
# # 706
# 
# # IA8 PER_PATIENT tables look like they have extra samples.
# length(unique(mmrf.PER_PATIENT$PUBLIC_ID))
# # 912
# 
# in_inventory <- inventory[inventory$Study == "MMRF","Patient"]
# in_inventory[!(in_inventory %in% mmrf.PER_PATIENT$PUBLIC_ID)]
# # "MMRF_2426" is in our inventory 
# 
# # how many more in IA9
# ia9_seqqc <- read.delim("../data/mmrf/IA9_README/MMRF_CoMMpass_IA9_Seq_QC_Summary.txt", stringsAsFactors = F)
# included_ia9 <- mmrf.seqqc[!grepl("Exclude", ia9_seqqc$MMRF_Release_Status),]
# 
# # count how many of each field are used per study
# logic_clinical <- ifelse(!(is.na(integrated.clinical)),1,0)
# summary_of_clin <- t(aggregate.data.frame(logic_clinical, by = list(integrated.clinical$Study), sum))
# write.table(summary_of_clin, "../data/curated/Count_of_clinical_fields.txt", sep = "\t", col.names = T)
# 
# logic_cyto <- ifelse(!(is.na(integrated.cytogenetic)),1,0)
# summary_of_cyto_fields <- t(aggregate.data.frame(logic_cyto, by = list(integrated.cytogenetic$Study), sum))
# write.table(summary_of_cyto_fields, "../data/curated/Count_of_cytogenetic_fields.txt", sep = "\t", col.names = T)
# 
# countable_columns <- integrated.cytogenetic[,c("t(4;14)", "t(6;14)", "t(8;14)", "t(11;14)", "t(12;14)", "t(14;16)", "t(14;20)", "del(13)", "del(17)", "del(1p)", "del(1q)", "Hyperdiploid")]
# cyto_phenotype_counts <- t(aggregate.data.frame(countable_columns, by = list(integrated.cytogenetic$Study), function(x){sum(x, na.rm = T)}))
# write.table(cyto_phenotype_counts, "../data/curated/Count_of_cytogenetic_phenotypes.txt", sep = "\t", col.names = T)
# 
# positive <- as.numeric(cyto_phenotype_counts)
# total    <- as.numeric(summary_of_cyto_fields[rownames(cyto_phenotype_counts),])
# proportions <- round(positive / total, 2)
# proportions <- matrix(proportions, ncol = 4, byrow = F)
# 
# write.table(proportions, "../data/curated/counts/proportion_of_cytogenetic_phenotypes.txt", sep = "\t", col.names = T)
# rm(positive, total, proportions)
# 
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
