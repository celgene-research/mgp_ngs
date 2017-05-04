snv <- toolboxR::AutoRead("../../../data/ProcessedData/JointData/curated_SNV_mutect2.txt")
pfa <- toolboxR::AutoRead("../../../data/PER-FILE_ALL.txt")
  pfa <- pfa[order(pfa$Patient),]

tmp <- merge(pfa[,c("File_Name", "Patient", "Visit_Name", "Sample_Name", "Disease_Status", "Tissue_Type", "Sequencing_Type" )],
             snv[1:3],
             all = T)

tmp[ grepl("MMRF_1049", tmp$Sample_Name),]
tmp[ grepl("PD4283", tmp$Sample_Name),]

ppndta <- toolboxR::AutoRead("../../../data/PER-PATIENT_nd_tumor_ALL.txt")
ppndta[grepl("MMRF_1049", ppndta$Sample_Name), c("Patient", "Visit_Name", "Sample_Name", "Disease_Status", "Tissue_Type", "Sequencing_Type", "SNV_A1CF_mutect2", "SNV_A2M_mutect2" )]
ppndta[grepl("PD4283", ppndta$Sample_Name), c("Patient", "Visit_Name", "Sample_Name", "Disease_Status", "Tissue_Type", "Sequencing_Type", "SNV_A1CF_mutect2", "SNV_A2M_mutect2" )]



collapse_to_patient <- function(df){
  df <- df[df$Sample_Type_Flag == 1 & df$Disease_Status == "ND",]
  df <- aggregate.data.frame(df, by = list(df$Patient), function(x){
    x <- unique(x)
    x <- x[!is.na(x)]
    if(length(x) > 1){print(x)}
    paste(x, collapse = "; ")
  })
  
  return(df)
}

# ppa <- collapse_to_patient(pfa)
# ppa[,c("File_Name", "Sequencing_Type", "File_Name_Actual", "File_Path")] <- NULL


pfa[ grepl("PD4283", pfa$Sample_Name), c("Patient", "Visit_Name", "Sample_Name", "Disease_Status", "Tissue_Type", "Sequencing_Type", "CYTO_Hyperdiploid_CONSENSUS", "CYTO_MYC_CONSENSUS" )]
pfa[ grepl("MMRF_1098", pfa$Sample_Name), c("Patient", "Visit_Name", "Sample_Name", "Disease_Status", "Tissue_Type", "Sequencing_Type", "CYTO_Hyperdiploid_CONSENSUS", "CYTO_MYC_CONSENSUS" )]





