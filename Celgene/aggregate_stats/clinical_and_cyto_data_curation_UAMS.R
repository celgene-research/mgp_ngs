# Dan Rozelle
# Sep 19, 2016

# UAMS integrated curation 
#   UAMS_patient_clinical_(date).txt
#   UAMS_patient_cytogenetic_(date).txt

d <- format(Sys.Date(), "%Y-%m-%d")
study <- "UAMS"

# generic curation functions
lookup_by_publicid <- toolboxR::lookup.values(c("PUBLIC_ID"))
lookup_by_patient <- toolboxR::lookup.values(c("Patient"))
check_by_publicid <- toolboxR::check.value(c("PUBLIC_ID"))
check_by_patient <- toolboxR::check.value(c("Patient"))

########## import raw tables and reformat as required
uams.cyto <- XLConnect::readWorksheetFromFile(file = "../data/uams/UAMS_UK_sample info.xlsx", sheet = 1)
uams.clin <- XLConnect::readWorksheetFromFile(file = "../data/uams/UAMS_UK_sample info.xlsx", sheet = 2)
# uams.clin[uams.clin$ISS == "Missing Data","ISS"] <- NA

#remove strange column name formatting
names(uams.cyto) <- gsub("X\\.+","",names(uams.cyto))

# add patient identifiers
uams.cyto[['Patient']] <- sprintf("UAMS_%04d", as.numeric(uams.cyto$MyXI_Trial_ID))
uams.clin[['Patient']] <- sprintf("UAMS_%04d", as.numeric(uams.clin$Trial.number))

# generate a union and sorted patient list from the two sheets
uams_patients <- unique(c(uams.cyto$Patient, uams.clin$Patient))
uams_patients <- uams_patients[order(uams_patients)]

# Generate a blank table
uams.clinical <- data.frame(Patient  = uams_patients,
                            Study   = study,
                   stringsAsFactors = F)

meta <- XLConnect::readWorksheetFromFile("../data/integrated_columns.xlsx", sheet = 1, startRow =2)
uams.clinical[  meta[((meta$category %in% c("demographic", "treatment", "response", "blood", "flow", "misc")) & meta$active), "names"]] <- NA

clean_data <- function(x, dict){
  if(x %in% names(dict)) return(dict[x])
  else return(NA)
}

gender_dict <- list(M = "Male", F = "Female")
uams.clin[['gender_formatted']] <- unlist(lapply(uams.clin$Sex, clean_data, dict = gender_dict ))
uams.clinical[["D_Gender"]] <- unlist(lapply(uams.clinical$Patient, lookup_by_patient, dat = uams.clin, field = "gender_formatted"))

uams.clinical[["D_Age"]] <- unlist(lapply(uams.clinical$Patient, lookup_by_patient, dat = uams.clin, field = "Age"))

iss_dict <- list(`Stage I` = 1, `Stage II` = 2, `Stage III` = 3)
uams.clin[['iss_numeric']] <- unlist(lapply(uams.clin$ISS, clean_data, dict = iss_dict ))
uams.clinical[['D_ISS']] <- as.numeric(unlist(lapply(uams.clinical$Patient, lookup_by_patient, dat = uams.clin, field = "iss_numeric")))

uams.clin[["OS_days"]] <- round(uams.clin$OS_months*30.42, digits = 0)
uams.clinical[['D_OS']] <- as.numeric(unlist(lapply(uams.clinical$Patient, lookup_by_patient, dat = uams.clin, field = "OS_days")))
uams.clinical[['D_OS_FLAG']] <- as.numeric(unlist(lapply(uams.clinical$Patient, lookup_by_patient, dat = uams.clin, field = "OS_status")))

uams.clin[["PFS_days"]] <- round(uams.clin$PFS_months*30.42, digits = 0)
uams.clinical[['D_PFS']] <- as.numeric(unlist(lapply(uams.clinical$Patient, lookup_by_patient, dat = uams.clin, field = "PFS_days")))
uams.clinical[['D_PFS_FLAG']] <-  as.numeric(unlist(lapply(uams.clinical$Patient, lookup_by_patient, dat = uams.clin, field = "PFS_status")))

# although UAMS chemistry units are not listed, I've inspected their ranges before curation. 
# All appear to have similar ranges and are therefore likely reported using the same units.
# boxplot(list(uams = as.numeric(unlist(lapply(uams.clinical$Patient, lookup_by_patient, dat = uams.clin, field = "Serum.albumin"))), mmrf = as.numeric(mmrf.clinical$DIAG_Albumin)))
uams.clinical[["DIAG_Albumin"]] <- as.numeric(unlist(lapply(uams.clinical$Patient, lookup_by_patient, dat = uams.clin, field = "Serum.albumin")))

# boxplot(list(uams = as.numeric(unlist(lapply(uams.clinical$Patient, lookup_by_patient, dat = uams.clin, field = "Corrected.Calcium"))), mmrf = as.numeric(mmrf.clinical$DIAG_Calcium)))
uams.clinical[["DIAG_Calcium"]] <- as.numeric(unlist(lapply(uams.clinical$Patient, lookup_by_patient, dat = uams.clin, field = "Corrected.Calcium")))

# boxplot(list(uams = as.numeric(unlist(lapply(uams.clinical$Patient, lookup_by_patient, dat = uams.clin, field = "Serum.creatinine"))), mmrf = as.numeric(mmrf.clinical$DIAG_Creatinine)))
uams.clinical[["DIAG_Creatinine"]] <- as.numeric(unlist(lapply(uams.clinical$Patient, lookup_by_patient, dat = uams.clin, field = "Serum.creatinine")))

# boxplot(list(uams = as.numeric(unlist(lapply(uams.clinical$Patient, lookup_by_patient, dat = uams.clin, field = "B2.microglobulin"))), mmrf = as.numeric(mmrf.clinical$DIAG_Beta2Microglobulin)))
uams.clinical[["DIAG_Beta2Microglobulin"]] <- as.numeric(unlist(lapply(uams.clinical$Patient, lookup_by_patient, dat = uams.clin, field = "B2.microglobulin")))

# Parse Medical history into boolean columns
medhx_cats <- scan("../data/other/MEDHX_conditions.of.interest.txt", what = character(), sep = "\n")
for(i in medhx_cats){
  # remove meta characters from medhx descriptors
  n <- paste("Has","medhx",gsub("[\\/\\(\\)\\ ]+","_",i), sep = ".")
  # dfci.clinical[[n]] <- ifelse(grepl(i, dfci.clinical$D_Medical_History, fixed = T),1,0)
  uams.clinical[[n]] <- ifelse(grepl(i, uams.clinical$D_Medical_History, fixed = T),1,NA)
}

write.table(uams.clinical, paste0("../data/curated/",study,"/",study,"_patient_clinical_", d,".txt"), row.names = F, col.names = T, sep = "\t", quote = F)


nrow(uams.clinical)
# 462
length(unique(uams.clinical$Patient))
# 463

############ Cytogenetic curation

uams.cytogenetic <- data.frame(Patient = uams.clinical$Patient,
                                Study   = study,
                                stringsAsFactors = F)
uams.cytogenetic[meta[((meta$category %in% c("cytogenetic")) & meta$active), "names"]] <- NA

uams.cytogenetic[['Has.Cytogenetic.Data']] <-  1

uams.cytogenetic[['t(11;14)']] <-  ifelse(unlist(lapply(uams.clinical$Patient, check_by_patient, 
                                          dat = uams.cyto, field = "Translocation_consensus", value = "^11$")), 1,0)
uams.cytogenetic[['t(4;14)']]  <-  ifelse(unlist(lapply(uams.clinical$Patient, check_by_patient, 
                                          dat = uams.cyto, field = "Translocation_consensus", value = "^4$")), 1,0)
uams.cytogenetic[['t(6;14)']]  <-  ifelse(unlist(lapply(uams.clinical$Patient, check_by_patient, 
                                          dat = uams.cyto, field = "Translocation_consensus", value = "^6$")), 1,0)
uams.cytogenetic[['t(14;16)']] <-  ifelse(unlist(lapply(uams.clinical$Patient, check_by_patient,
                                          dat = uams.cyto, field = "Translocation_consensus", value = "^16$")), 1,0)
uams.cytogenetic[['t(14;20)']] <-  ifelse(unlist(lapply(uams.clinical$Patient, check_by_patient, 
                                          dat = uams.cyto, field = "Translocation_consensus", value = "^20$")), 1,0)
uams.cytogenetic[['t(8;14)']]  <-  ifelse(unlist(lapply(uams.clinical$Patient, check_by_patient, 
                                          dat = uams.cyto, field = "MYC.translocation", value = "t(8;14)", fixed_pattern = T)), 1,0)

write.table(uams.cytogenetic, paste0("../data/curated/",study,"/",study ,"_patient_cytogenetic_", d,".txt"), row.names = F, col.names = T, sep = "\t", quote = F)
