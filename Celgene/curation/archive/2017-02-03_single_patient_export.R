# 2017-02-03
# ad hoc export table subset for one patient
# used in presentation to highlight changes in dimensionality

library(dplyr)

root <- "../../../data/ProcessedData/Integrated"
file.names <- list("per.file.clinical.txt", 
                   "per.sample.clinical.txt", 
                   "per.patient.clinical.txt", 
                   "per.file.clinical.nd.tumor.txt", 
                   "per.sample.clinical.nd.tumor.txt", 
                   "per.patient.clinical.nd.tumor.txt")
tmp <- lapply(file.names, function(x){
  df <- toolboxR::AutoRead(file.path(root,x))
  selected <- names(df)[names(df) %in% c("Patient", "Sample_Name", 
                                         "Sample_Name_Tissue_Type", "Disease_Status", 
                                         "Sample_Type", "Cell_Type", "Sequencing_Type", 
                                         "D_OS", "CYTO_t.4.14._CONSENSUS", "File_Name")]
  df <- df %>%
    filter(Patient == "MMRF_1285") %>%
    select(one_of(selected)) 
  write.table(df, file.path("~/Downloads","1285",x), sep = "\t", row.names = F, quote = F)
  
  
})



# deparse(substitute(df))
