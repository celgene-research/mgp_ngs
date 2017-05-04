# Dan Rozelle
# Sep 19, 2016

# Lohr integrated curation 
#   LOHR_patient_clinical_(date).txt
#   LOHR_patient_cytogenetic_(date).txt

d <- format(Sys.Date(), "%Y-%m-%d")
study <- "LOHR"

# generic curation functions
lookup_by_publicid <- toolboxR::lookup.values(c("PUBLIC_ID"))
lookup_by_patient <- toolboxR::lookup.values(c("Patient"))
check_by_publicid <- toolboxR::check.value(c("PUBLIC_ID"))
check_by_patient <- toolboxR::check.value(c("Patient"))

########## import raw tables and reformat as required
# lohr.supp5 is the table provided as Supplemental Table 5 with the Lohr publication
lohr.supp5 <- read.delim("../data/lohr/lohr-paper-supp/mmc5_Patient_Clinical_Profiles.txt"
                         , stringsAsFactors = F)
lohr.supp5[['Patient']] <- gsub(".*?(\\d+).*", "MMRC_\\1",lohr.supp5$Tumor_Sample_Barcode)

# broad.sampleinfo is provided on the MMGP website, and includes additional information 
# for some Lohr patients
broad.sampleinfo <- read.delim("../data/lohr/broad-mmgp-files/mmrc.sample.information.txt"
                               ,stringsAsFactors = F, na.strings = c("unknown ", "Unknown", "Not available"))
broad.sampleinfo[['Patient']] <- gsub(".*?(\\d+).*", "MMRC_\\1", broad.sampleinfo$Array)

# Clinical columns we want to populate
meta <- XLConnect::readWorksheetFromFile("../data/integrated_columns.xlsx", sheet = 1, startRow =2)

# Generate a blank table
lohr.clinical <- data.frame(Patient  = lohr.supp5$Patient,
                            Study = study,
                            stringsAsFactors = F)
lohr.clinical[meta[((meta$category %in% c("demographic", "treatment", "response", "blood", "flow", "misc")) & meta$active), "names"]] <- NA
lohr.clinical <- lohr.clinical[order(lohr.clinical$Patient),]
row.names(lohr.clinical) <- 1:nrow(lohr.clinical)

# Surprisingly, the Lohr paper supplement and the Broad sample info have different missing data
# so I guess I'll use a merged lookup table. Potentially conflicting info is retained.
concatenated_sample_info <- rbind(lohr.supp5[,c("Patient", "Age.at.Diagnosis", "Gender", "Race", "Diagnosis")]
                                  ,broad.sampleinfo[,c("Patient", "Age.at.Diagnosis", "Gender", "Race", "Diagnosis")])

lohr.clinical[['D_Gender']] <- unlist(lapply(lohr.clinical$Patient, lookup_by_patient, dat = concatenated_sample_info, field = "Gender"))
lohr.clinical[['D_Race']] <- unlist(lapply(lohr.clinical$Patient, lookup_by_patient, dat = concatenated_sample_info, field = "Race"))

lohr.clinical[['D_Race']] <- gsub("Caucasian", "WHITE", lohr.clinical$D_Race)
lohr.clinical[['D_Race']] <- gsub("African American", "BLACKORAFRICAN", lohr.clinical$D_Race)
lohr.clinical[['D_Race']] <- gsub("Asian", "ASIAN", lohr.clinical$D_Race)
lohr.clinical[['D_Race']] <- gsub("Hispanic", "OTHER", lohr.clinical$D_Race)

lohr.clinical[['D_Age']] <- unlist(lapply(lohr.clinical$Patient, lookup_by_patient, dat = concatenated_sample_info, field = "Age.at.Diagnosis"))
lohr.clinical[["D_Cause_of_Death"]] <- unlist(lapply(lohr.clinical$Patient, lookup_by_patient, dat = lohr.supp5, field = "Cause.of.Death"))

# convert Hemoglobin (MW = 16kDa) from g/dL to mmol/L by multiplying by 0.625
# 1 g/dL * 10 dL/L * mol/16000g * 1e3 mmol/mol = 0.625 mmol/L
broad.sampleinfo[["Hemoglobin.mmol.L"]] <- as.numeric(broad.sampleinfo$Hemoglobin..g.dL.)  * 0.625  # mw=16000 g/mole
broad.sampleinfo[["Calcium.mmol.L"]] <- as.numeric(broad.sampleinfo$Serum.calcium..mg.dL.) * 0.2495 # mw=40.1 g/mole
broad.sampleinfo[["Creatinine.umol.L"]] <- as.numeric(broad.sampleinfo$Serum.creatinine..mg.dL.)  * 88.40  # mw=113.12 g/mole



p <- lohr.clinical$Patient
bd <- broad.sampleinfo
lohr.clinical[["CBC_Platelet"]] <- unlist(lapply(p, FUN = lookup_by_patient, dat = bd, field = "Platelets..10.9.L."))
lohr.clinical[["DIAG_Hemoglobin"]] <- unlist(lapply(p, FUN = lookup_by_patient, dat = bd, field = "Hemoglobin.mmol.L"))
lohr.clinical[["DIAG_Albumin"]] <- unlist(lapply(p, FUN = lookup_by_patient, dat = bd, field = "Serum.albumin..g.dL."))
lohr.clinical[["DIAG_Calcium"]] <- unlist(lapply(p, FUN = lookup_by_patient, dat = bd, field = "Calcium.mmol.L"))
lohr.clinical[["DIAG_Creatinine"]] <- unlist(lapply(p, FUN = lookup_by_patient, dat = bd, field = "Creatinine.umol.L"))
lohr.clinical[["DIAG_LDH"]] <- unlist(lapply(p, FUN = lookup_by_patient, dat = bd, field = "Serum.LDH..U.L."))
lohr.clinical[["DIAG_Beta2Microglobulin"]] <- unlist(lapply(p, FUN = lookup_by_patient, dat = bd, field = "Beta2.microglobulin..ug.dL."))
lohr.clinical[["CHEM_CRP"]] <- unlist(lapply(p, FUN = lookup_by_patient, dat = bd, field = "CRP..mg.dL."))
lohr.clinical[["IG_IgL_Kappa"]] <- unlist(lapply(p, FUN = lookup_by_patient, dat = bd, field = "Serum.free.light.chain.kappa..mg.dL."))
lohr.clinical[["IG_M_Protein"]] <- unlist(lapply(p, FUN = lookup_by_patient, dat = bd, field = "M.spike..g.dL."))
lohr.clinical[["IG_IgL_Lambda"]] <- unlist(lapply(p, FUN = lookup_by_patient, dat = bd, field = "Serum.free.light.chain.lambda..mg.dL."))

# Parse Medical history into boolean columns
medhx_cats <- scan("../data/other/MEDHX_conditions.of.interest.txt", what = character(), sep = "\n")
for(i in medhx_cats){
  n <- paste("Has","medhx",gsub("[\\/\\(\\)\\ ]+","_",i), sep = ".")
  # dfci.clinical[[n]] <- ifelse(grepl(i, dfci.clinical$D_Medical_History, fixed = T),1,0)
  lohr.clinical[[n]] <- ifelse(grepl(i, lohr.clinical$D_Medical_History, fixed = T),1,NA)
}

write.table(lohr.clinical, paste0("../data/curated/",study,"/",study,"_patient_clinical_", d,".txt"), row.names = F, col.names = T, sep = "\t", quote = F)


nrow(lohr.clinical)
# 203
length(unique(lohr.clinical$Patient))
# 203

############ Cytogenetic curation

lohr.cytogenetic <- data.frame(Patient = lohr.clinical$Patient,
                                Study   = study,
                                stringsAsFactors = F)
lohr.cytogenetic[meta[((meta$category %in% c("cytogenetic")) & meta$active), "names"]] <- NA

lohr.cytogenetic[['Has.Cytogenetic.Data']] <- ifelse(!is.na(unlist(lapply(lohr.cytogenetic$Patient, lookup_by_patient, dat = lohr.supp5, field = "X1_if_hyperdiploid"))),1,0)
# check_by_patient(fixed_pattern = )


lohr.cytogenetic[['CYTO_t(11;14)_FISH']] <- ifelse(unlist(lapply(lohr.clinical$Patient, check_by_patient, 
                                    dat = lohr.supp5, field = "FISH_Translocation", value = "11;14", fixed_pattern = T)), 1,0)
lohr.cytogenetic[['CYTO_del(17)_FISH']]  <-  ifelse(unlist(lapply(lohr.clinical$Patient, check_by_patient, 
                                                        dat = lohr.supp5, field = "FISH_Translocation", value = "17", fixed_pattern = T)), 1,0)
lohr.cytogenetic[['CYTO_t(14;16)_FISH']] <-  ifelse(unlist(lapply(lohr.clinical$Patient, check_by_patient,
                                                        dat = lohr.supp5, field = "FISH_Translocation", value = "14;16", fixed_pattern = T)), 1,0)
lohr.cytogenetic[['CYTO_t(4;14)_FISH']]  <-  ifelse(unlist(lapply(lohr.clinical$Patient, check_by_patient, 
                                                        dat = lohr.supp5, field = "FISH_Translocation", value = "4;14", fixed_pattern = T)), 1,0)
lohr.cytogenetic[['CYTO_Hyperdiploid_FISH']]  <-as.numeric(unlist(lapply(lohr.clinical$Patient, lookup_by_patient, 
                                                        dat = lohr.supp5, field = "X1_if_hyperdiploid")))

write.table(lohr.cytogenetic, paste0("../data/curated/",study,"/",study ,"_patient_cytogenetic_", d,".txt"), row.names = F, col.names = T, sep = "\t", quote = F)
