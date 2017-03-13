source("curation_scripts.R")
source("qc_and_summary.R")
local <- CleanLocalScratch()

per.patient <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Integrated/per.patient.clinical.nd.tumor.txt"))
per.file <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Integrated/per.file.clinical.nd.tumor.txt"))


unified <- per.file %>%
  group_by(Study, Patient) %>%
  summarise_all(.funs = funs(Simplify(.))) %>%
  ungroup() %>%
  select(Patient, Sample_Type, Sequencing_Type, Disease_Status, Tissue_Type:CYTO_t.14.20._CONSENSUS) %>%
  full_join(per.patient, ., by = "Patient") %>%
  select(-c(starts_with("INV"))) %>%
  filter(Disease_Type == "MM" | is.na(Disease_Type))

export_sas(unified, "unified.nd.tumor")
