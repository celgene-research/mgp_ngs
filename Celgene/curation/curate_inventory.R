
# The inventory script captures filenames of all bam files from SeqData/OriginalData
system('./s3_inventory.sh')

# we need to lookup patient and sample names for UAMS filenames 
system('aws s3 cp "s3://celgene.rnd.combio.mmgp.external/ClinicalData/UAMS/UAMS_UK_sample info.xlsx" ./uams.xlsx')

inv   <- read.delim("file_inventory.txt", stringsAsFactors = F)
uams  <- readxl::read_excel("uams.xlsx")

filenames <- inv[inv$Study == "UAMS" , "Sample_Name"]
trial_id <- unlist(lapply(filenames, function(code){
  uams[uams$filename == code, "MyXI_Trial_ID"]
}))
sample_name <- unlist(lapply(filenames, function(code){
  uams[uams$filename == code, "Sample_name"]
}))
patient_id <- sprintf("UAMS_%04d", as.numeric(trial_id))

inv[inv$Study == "UAMS" , "Patient"]     <- patient_id
inv[inv$Study == "UAMS" , "Sample_Name"] <- sample_name
inv[inv$Study == "UAMS" , "File_Name"]   <- filenames


write.table(inv, "file_inventory.txt", sep = "\t", row.names = F, col.names = T)


# put the new inventory sheet on S3, remove local files
system('aws s3 cp file_inventory.txt s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/Integrated/file_inventory.txt --sse')
system('rm file_inventory.txt uams.xlsx')
rm(inv, uams)

# 
# 
# 
# qc_inventory <- read.csv("../data/other/aggregated_sample_inventory_FADI.csv", stringsAsFactors = F)
# # reformat UAMS patient ids as I've done in the clinical tables UAMS_0000
# qc_inventory[['Patient']] <- unlist(mapply(function(x,y){
#   if( y == "UAMS"){
#     sprintf("UAMS_%04d", as.numeric(x))
#   } else x
# }, qc_inventory$Patient, qc_inventory$Study))
# 
# # I'll add Lohr Seq counts to qc_inventory so we can use a single lookup
# lohr_sra <- read.delim("../data/lohr/sra/SraRunTable_203.txt", stringsAsFactors = F)
# lohr_sra[['Patient']] <- gsub("MMRC", "MMRC_", lohr_sra$submitted_subject_id_s)
# # fix MMRC_442 to MMRC_0442
# lohr_sra[['Patient']] <- gsub("_([^0]\\d+)", "_0\\1", lohr_sra$Patient) 
# # fix MMRC_0439_2 to MMRC_0439
# lohr_sra[['Patient']] <- gsub("(MMRC_0\\d+)_2", "\\1", lohr_sra$Patient) 
# 
# lohr.clinical[['Has.WES.Not.Normal']] <- ifelse(unlist(lapply(lohr.clinical$Patient, check_by_patient, dat = lohr_sra, field = "Assay_Type_s", value = "WXS")),1,0)
# lohr.clinical[['Has.WGS.Not.Normal']] <- ifelse(unlist(lapply(lohr.clinical$Patient, check_by_patient, dat = lohr_sra, field = "Assay_Type_s", value = "WGS")),1,0)
# qc_inventory <- merge(qc_inventory, lohr.clinical[,c("Patient", "Has.WES.Not.Normal", "Has.WGS.Not.Normal")], by = c("Patient", "Has.WES.Not.Normal", "Has.WGS.Not.Normal"), all = T)
# 
# 
# inventory_columns <- c('Has.Clinical.Demographic', 'Has.Clinical.Chemistry', 
#                        'Has.Cytogenetic', 'Has.WES', 'Has.WGS', 'Has.RNA')
# 
# inventory <- data.frame(Patient = integrated.clinical$Patient,
#                         Study   = integrated.clinical$Study,
#                         Has.Patient = 1,
#                         stringsAsFactors = F)
# inventory[inventory_columns] <- NA
# 
# inventory["Has.Clinical.Demographic"] <- ifelse(grepl("M|F", integrated.clinical$D_Gender),1,0)
# 
# chem_columns <- names(integrated.clinical)[startsWith(names(integrated.clinical), "CBC") | startsWith(names(integrated.clinical), "DIAG")]
# inventory["Has.Clinical.Chemistry"] <- ifelse(apply(!(is.na(integrated.clinical[,chem_columns])), MARGIN = 1, any),1,0)
# 
# inventory[["Has.Cytogenetic"]] <- ifelse(unlist(lapply(inventory$Patient, check_by_patient, dat = integrated.cytogenetic, field = "Has.Cytogenetic.Data", value = "1")),1,0)
# inventory[["Has.WES"]] <- ifelse(unlist(lapply(inventory$Patient, check_by_patient, dat = qc_inventory, field = "Has.WES.Not.Normal", value = "1")),1,0)
# inventory[["Has.WGS"]] <- ifelse(unlist(lapply(inventory$Patient, check_by_patient, dat = qc_inventory, field = "Has.WGS.Not.Normal", value = "1")),1,0)
# inventory[["Has.RNA"]] <- ifelse(unlist(lapply(inventory$Patient, check_by_patient, dat = qc_inventory, field = "Has.RNA.CD138plus", value = "1")),1,0)
# 
# inventory[["Has.WES.WGS"]]     <- ifelse(inventory$Has.WES == 1 & inventory$Has.WGS == 1 ,1,0)
# inventory[["Has.WES.RNA"]]     <- ifelse(inventory$Has.WES == 1 & inventory$Has.RNA == 1 ,1,0)
# inventory[["Has.WGS.RNA"]]     <- ifelse(inventory$Has.WGS == 1 & inventory$Has.RNA == 1 ,1,0)
# inventory[["Has.WES.WGS.RNA"]] <- ifelse(inventory$Has.WES == 1 & inventory$Has.WGS == 1 & inventory$Has.RNA == 1 ,1,0)
# 
# write.table(inventory, paste0("../data/curated/","INTEGRATED" ,"_patient_inventory_", d,".txt"), row.names = F, col.names = T, sep = "\t", quote = F)
