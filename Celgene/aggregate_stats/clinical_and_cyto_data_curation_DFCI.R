# Dan Rozelle
# Sep 19, 2016

# DFCI integrated curation 
#   DFCI_patient_clinical_(date).txt
#   DFCI_patient_cytogenetic_(date).txt
#   DFCI_patient_inventory_(date).txt

d <- format(Sys.Date(), "%Y-%m-%d")
study <- "DFCI"

# generic curation functions
lookup_by_publicid <- toolboxR::lookup.values(c("PUBLIC_ID"))
lookup_by_patient <- toolboxR::lookup.values(c("Patient"))
check_by_publicid <- toolboxR::check.value(c("PUBLIC_ID"))
check_by_patient <- toolboxR::check.value(c("Patient"))

########## import raw tables and reformat as required
# Since we only have one workbook for DFCI, this becomes our master patient list.
dfci.cyto <- XLConnect::readWorksheetFromFile(file = "../data/dfci/DFCI_WES_Cyto.xlsx", sheet = 1)
dfci.visit <- XLConnect::readWorksheetFromFile(file = "../data/dfci/DFCI_WES_Cyto.xlsx", sheet = 2)
dfci.cyto[['Patient']] <- gsub("(PD\\d+).", "\\1",dfci.cyto$Sample)
dfci.visit[['Patient']] <- gsub("(PD\\d+).", "\\1",dfci.visit$Sample)

# remove excluded patients
dfci.visit <- dfci.visit[is.na(dfci.visit$Exclude),]

dfci_patients <- unique(c(dfci.cyto$Patient, dfci.visit$Patient))
dfci_patients <- dfci_patients[order(dfci_patients)]

meta <- XLConnect::readWorksheetFromFile("../data/integrated_columns.xlsx", sheet = 1, startRow =2)

# Generate a blank table
dfci.clinical <- data.frame(Patient  = dfci_patients,
                            Study   = study,
                   stringsAsFactors = F)
# add empty clinical columns
dfci.clinical[meta[((meta$category %in% c("demographic", "treatment", "response", "blood", "flow", "misc")) & meta$active), "names"]] <- NA

# yup, that's all we have for DFCI!

# Parse Medical history into boolean columns
medhx_cats <- scan("../data/other/MEDHX_conditions.of.interest.txt", what = character(), sep = "\n")
for(i in medhx_cats){
  n <- paste("Has","medhx",gsub("[\\/\\(\\)\\ ]+","_",i), sep = ".")
  # dfci.clinical[[n]] <- ifelse(grepl(i, dfci.clinical$D_Medical_History, fixed = T),1,0)
  dfci.clinical[[n]] <- ifelse(grepl(i, dfci.clinical$D_Medical_History, fixed = T),1,NA)
}

write.table(dfci.clinical, paste0("../data/curated/",study,"/",study,"_patient_clinical_", d,".txt"), row.names = F, col.names = T, sep = "\t", quote = F)


nrow(dfci.clinical)
# 78
length(unique(dfci.clinical$Patient))
# 78

############ Cytogenetic curation

dfci.cytogenetic <- data.frame(Patient = dfci.clinical$Patient,
                                Study   = study,
                                stringsAsFactors = F)
dfci.cytogenetic[meta[((meta$category %in% c("cytogenetic")) & meta$active), "names"]] <- NA

p <- dfci.cytogenetic$Patient
# cytogenetic analysis was not performed on all patients, only those listed on
#  "dfci.cyto" patient worksheet
dfci.cytogenetic[['Has.Cytogenetic.Data']] <- ifelse(p %in% dfci.cyto$Patient, 1,0)

# add description of karyotype
dfci.cytogenetic[["Karyotype"]] <- unlist(lapply(p, lookup_by_patient, 
                                                 dat = dfci.cyto, field = "Karyotype"))

dfci.cytogenetic[['t(4;14)']] <- ifelse(unlist(lapply(p, check_by_patient, dat = dfci.cyto, 
                                                  field = "Karyotype", value = "4;14")),1,0)
dfci.cytogenetic[['del(17)']] <- ifelse(unlist(lapply(p, check_by_patient, dat = dfci.cyto, 
                                                      field = "Karyotype", value = "17p")),1,0)
dfci.cytogenetic[['Hyperdiploid']] <- ifelse(unlist(lapply(p, check_by_patient, dat = dfci.cyto, 
                                                      field = "Karyotype", value = "Hyper")),1,0)
dfci.cytogenetic[['t(14;16)']] <- ifelse(unlist(lapply(p, check_by_patient, dat = dfci.cyto, 
                                                      field = "Karyotype", value = "14;16")),1,0)
dfci.cytogenetic[dfci.cytogenetic$Has.Cytogenetic.Data == 0, c("t(4;14)", "t(6;14)", "t(8;14)", "t(11;14)", "t(12;14)", "t(14;16)", "t(14;20)", "del(13)", "del(17)", "del(1p)", "del(1q)", "Hyperdiploid")] <- NA

write.table(dfci.cytogenetic, paste0("../data/curated/",study,"/",study ,"_patient_cytogenetic_", d,".txt"), row.names = F, col.names = T, sep = "\t", quote = F)
