#########################################################3
# Main script for generating integrated clinical, cytogenetic,
#  and molecular file inventory data table. 
#  This sources individual curation scripts for each dataset,
#  to allow for unique quirks of sources and reformatting.
#
# Dan Rozelle
# Oct 17, 2016


d <- format(Sys.Date(), "%Y-%m-%d")

# we'll first load all of our curated objects into memory
source("clinical_and_cyto_data_curation_MMRF.R")
source("clinical_and_cyto_data_curation_UAMS.R")
source("clinical_and_cyto_data_curation_DFCI.R")
source("clinical_and_cyto_data_curation_LOHR.R")

# Bind datasets into a master table
integrated.clinical    <- rbind(mmrf.clinical, uams.clinical, dfci.clinical, lohr.clinical)
tmp    <- list(mmrf.clinical, uams.clinical, dfci.clinical, lohr.clinical)
integrated.cytogenetic <- rbind(mmrf.cytogenetic, uams.cytogenetic, dfci.cytogenetic, lohr.cytogenetic)

write.table(integrated.clinical, paste0("../data/curated/","INTEGRATED" ,"_patient_clinical_", d,".txt"), row.names = F, col.names = T, sep = "\t", quote = F)
write.table(integrated.cytogenetic, paste0("../data/curated/","INTEGRATED" ,"_patient_cytogenetic_", d,".txt"), row.names = F, col.names = T, sep = "\t", quote = F)

qc_inventory <- read.csv("../data/other/aggregated_sample_inventory_FADI.csv", stringsAsFactors = F)
# reformat UAMS patient ids as I've done in the clinical tables UAMS_0000
qc_inventory[['Patient']] <- unlist(mapply(function(x,y){
  if( y == "UAMS"){
    sprintf("UAMS_%04d", as.numeric(x))
  } else x
}, qc_inventory$Patient, qc_inventory$Study))

# I'll add Lohr Seq counts to qc_inventory so we can use a single lookup
lohr_sra <- read.delim("../data/lohr/sra/SraRunTable_203.txt", stringsAsFactors = F)
lohr_sra[['Patient']] <- gsub("MMRC", "MMRC_", lohr_sra$submitted_subject_id_s)
# fix MMRC_442 to MMRC_0442
lohr_sra[['Patient']] <- gsub("_([^0]\\d+)", "_0\\1", lohr_sra$Patient) 
# fix MMRC_0439_2 to MMRC_0439
lohr_sra[['Patient']] <- gsub("(MMRC_0\\d+)_2", "\\1", lohr_sra$Patient) 

lohr.clinical[['Has.WES.Not.Normal']] <- ifelse(unlist(lapply(lohr.clinical$Patient, check_by_patient, dat = lohr_sra, field = "Assay_Type_s", value = "WXS")),1,0)
lohr.clinical[['Has.WGS.Not.Normal']] <- ifelse(unlist(lapply(lohr.clinical$Patient, check_by_patient, dat = lohr_sra, field = "Assay_Type_s", value = "WGS")),1,0)
qc_inventory <- merge(qc_inventory, lohr.clinical[,c("Patient", "Has.WES.Not.Normal", "Has.WGS.Not.Normal")], by = c("Patient", "Has.WES.Not.Normal", "Has.WGS.Not.Normal"), all = T)


inventory_columns <- c('Has.Clinical.Demographic', 'Has.Clinical.Chemistry', 
                       'Has.Cytogenetic', 'Has.WES', 'Has.WGS', 'Has.RNA')

inventory <- data.frame(Patient = integrated.clinical$Patient,
                        Study   = integrated.clinical$Study,
                        Has.Patient = 1,
                       stringsAsFactors = F)
inventory[inventory_columns] <- NA

inventory["Has.Clinical.Demographic"] <- ifelse(grepl("M|F", integrated.clinical$D_Gender),1,0)

chem_columns <- names(integrated.clinical)[startsWith(names(integrated.clinical), "CBC") | startsWith(names(integrated.clinical), "DIAG")]
inventory["Has.Clinical.Chemistry"] <- ifelse(apply(!(is.na(integrated.clinical[,chem_columns])), MARGIN = 1, any),1,0)

inventory[["Has.Cytogenetic"]] <- ifelse(unlist(lapply(inventory$Patient, check_by_patient, dat = integrated.cytogenetic, field = "Has.Cytogenetic.Data", value = "1")),1,0)
inventory[["Has.WES"]] <- ifelse(unlist(lapply(inventory$Patient, check_by_patient, dat = qc_inventory, field = "Has.WES.Not.Normal", value = "1")),1,0)
inventory[["Has.WGS"]] <- ifelse(unlist(lapply(inventory$Patient, check_by_patient, dat = qc_inventory, field = "Has.WGS.Not.Normal", value = "1")),1,0)
inventory[["Has.RNA"]] <- ifelse(unlist(lapply(inventory$Patient, check_by_patient, dat = qc_inventory, field = "Has.RNA.CD138plus", value = "1")),1,0)

inventory[["Has.WES.WGS"]]     <- ifelse(inventory$Has.WES == 1 & inventory$Has.WGS == 1 ,1,0)
inventory[["Has.WES.RNA"]]     <- ifelse(inventory$Has.WES == 1 & inventory$Has.RNA == 1 ,1,0)
inventory[["Has.WGS.RNA"]]     <- ifelse(inventory$Has.WGS == 1 & inventory$Has.RNA == 1 ,1,0)
inventory[["Has.WES.WGS.RNA"]] <- ifelse(inventory$Has.WES == 1 & inventory$Has.WGS == 1 & inventory$Has.RNA == 1 ,1,0)

write.table(inventory, paste0("../data/curated/","INTEGRATED" ,"_patient_inventory_", d,".txt"), row.names = F, col.names = T, sep = "\t", quote = F)

countable_fields <- grep("Has", names(inventory), value = T)
for(i in countable_fields){
  inventory[[i]] <- as.numeric(inventory[[i]])
}

summary <- aggregate.data.frame(inventory[,countable_fields], by = list(inventory$Study), sum)
write.table(summary, paste0("../data/curated/counts/","SUMMARY_patient_inventory_", d,".txt"), row.names = F, col.names = T, sep = "\t", quote = F)

## Troubleshooting
# Does "extra" MMRF patient numbers exist because they are not Relevant
# tmp <- inventory[inventory$Patient %in% relevant, ]
# aggregate.data.frame(tmp[,countable_fields], by = list(tmp$Study), sum)

# Count patients from each source
# IA8 README Seq QC table
length(unique(mmrf.seqqc$Patients..KBase_Patient_ID))
# 706

# IA8 README Seq QC table with excluded sample rows removed
included_mmrf.seqqc <- mmrf.seqqc[!grepl("Exclude", mmrf.seqqc$MMRF_Release_Status),]
length(unique(included_mmrf.seqqc$Patients..KBase_Patient_ID))
# 706

# IA8 PER_PATIENT tables look like they have extra samples.
length(unique(mmrf.PER_PATIENT$PUBLIC_ID))
# 912

in_inventory <- inventory[inventory$Study == "MMRF","Patient"]
in_inventory[!(in_inventory %in% mmrf.PER_PATIENT$PUBLIC_ID)]
# "MMRF_2426" is in our inventory 

# how many more in IA9
ia9_seqqc <- read.delim("../data/mmrf/IA9_README/MMRF_CoMMpass_IA9_Seq_QC_Summary.txt", stringsAsFactors = F)
included_ia9 <- mmrf.seqqc[!grepl("Exclude", ia9_seqqc$MMRF_Release_Status),]

# count how many of each field are used per study
logic_clinical <- ifelse(!(is.na(integrated.clinical)),1,0)
summary_of_clin <- t(aggregate.data.frame(logic_clinical, by = list(integrated.clinical$Study), sum))
write.table(summary_of_clin, "../data/curated/Count_of_clinical_fields.txt", sep = "\t", col.names = T)

logic_cyto <- ifelse(!(is.na(integrated.cytogenetic)),1,0)
summary_of_cyto_fields <- t(aggregate.data.frame(logic_cyto, by = list(integrated.cytogenetic$Study), sum))
write.table(summary_of_cyto_fields, "../data/curated/Count_of_cytogenetic_fields.txt", sep = "\t", col.names = T)

countable_columns <- integrated.cytogenetic[,c("t(4;14)", "t(6;14)", "t(8;14)", "t(11;14)", "t(12;14)", "t(14;16)", "t(14;20)", "del(13)", "del(17)", "del(1p)", "del(1q)", "Hyperdiploid")]
cyto_phenotype_counts <- t(aggregate.data.frame(countable_columns, by = list(integrated.cytogenetic$Study), function(x){sum(x, na.rm = T)}))
write.table(cyto_phenotype_counts, "../data/curated/Count_of_cytogenetic_phenotypes.txt", sep = "\t", col.names = T)

positive <- as.numeric(cyto_phenotype_counts)
total    <- as.numeric(summary_of_cyto_fields[rownames(cyto_phenotype_counts),])
proportions <- round(positive / total, 2)
proportions <- matrix(proportions, ncol = 4, byrow = F)

write.table(proportions, "../data/curated/counts/proportion_of_cytogenetic_phenotypes.txt", sep = "\t", col.names = T)
rm(positive, total, proportions)

# aggregate for Andrew's Sage summary
# 
# gender <- table(mmrf.clinical$D_Gender)
# summary_stats <- data.frame(N        = nrow(mmrf.clinical),
#            F.M      = paste(c(gender["Female"], gender["Male"]), collapse = ","),
#            Mean.Age = round(mean(as.numeric(mmrf.clinical$D_Age), na.rm = T),2),
#            Mean.OS  = round(mean(mmrf.clinical$D_OS, na.rm = T), 2),
#            Mean.PFS  = round(mean(mmrf.clinical$D_PFS, na.rm = T), 2),
#            Proportion.Deceased     = round(mean(mmrf.clinical$D_OS_FLAG, na.rm = T), 2),
#            Proportion.Progressing  = round(mean(mmrf.clinical$D_PD_FLAG, na.rm = T), 2)
#            )
# write.table(summary_stats, "../data/curated/summary_stats_for_Andrew_20160922.txt", sep = "\t", col.names = T, row.names = F)

# join integrated tables into a single one for easy filtering

names(integrated.clinical) %in% names(integrated.cytogenetic)
names(integrated.clinical) %in% names(inventory)
names(integrated.cytogenetic) %in% names(integrated.clinical)

integrated <- merge(integrated.clinical, integrated.cytogenetic, by = c("Patient", "Study"), all = T)
integrated <- merge(integrated, inventory, by = c("Patient", "Study"), all = T)

# sort to keep MMRF on the top (just my preference)
integrated[['Study']] <- as.factor(integrated$Study)
proper_order <- c("MMRF", levels(integrated$Study)[!(levels(integrated$Study) %in% "MMRF")])
integrated[['Study']] <- factor(integrated$Study, levels = proper_order)
integrated <- integrated[order(integrated$Study),]

write.table(integrated, paste0("../data/curated/INTEGRATED/","INTEGRATED" ,"_patient_clinical_cyto_inventory_", d,".txt"), row.names = F, col.names = T, sep = "\t", quote = F)

# save the MMRF portion to a SAGE-specific upload file
sage <- integrated[integrated$Study == "MMRF",]
write.table(sage, paste0("../../sage/data/","MMRF_patient_clinical_cyto_inventory_for_SAGE-", d,".txt"), row.names = F, col.names = T, sep = "\t", quote = F)

# verify proper data typing
bak <- integrated
foo <- "D_Gender"

meta <- XLConnect::readWorksheetFromFile(file = "../data/integrated_columns.xlsx", sheet = 1, startRow = 2)
factor_columns <- meta[meta$type == "Factor","names"]

for(foo in factor_columns){
  integrated[integrated[[foo]] == "" & !is.na(integrated[[foo]]),foo] <- NA
  integrated[[foo]] <- as.factor(integrated[[foo]])
  print(levels(integrated[[foo]]))
}

numeric_columns <- meta[meta$type == "Numeric","names"]

for(foo in numeric_columns){
  integrated[integrated[[foo]] == "" & !is.na(integrated[[foo]]),foo] <- NA
  integrated[[foo]] <- as.numeric(integrated[[foo]])
  print(summary(integrated[[foo]]))
}


# write out text datafile for SAS
library(foreign)
foreign::write.foreign(integrated, 
                       datafile = paste0("../data/curated/sas/","INTEGRATED" ,"_patient_clinical_cyto_inventory_", d,".txt"), 
                       codefile = paste0("../data/curated/sas/","INTEGRATED" ,"_patient_clinical_cyto_inventory_", d,".sas"),
                       package="SAS")




