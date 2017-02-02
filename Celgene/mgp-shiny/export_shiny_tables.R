# Shiny app will sync the ./data directory for an updated version

source("curation_scripts.R")
d <- format(Sys.Date(), "%Y-%m-%d")
s3 <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/Integrated"

per.file    <- GetS3Table(file.path(s3, "per.file.clinical.txt"))
per.sample  <- GetS3Table(file.path(s3, "per.sample.clinical.txt"))
per.patient <- GetS3Table(file.path(s3, "per.patient.clinical.txt"))
dictionary  <- system(paste('aws s3 cp',file.path(s3,"mgp_dictionary.xlsx"), '/tmp/mgp_dictionary.xlsx', sep =" "))

unified.file    <- merge(per.file, per.patient, by = c("Patient", "Study"), all.x = T)
unified.sample  <- toolboxR::CollapseDF(unified.file, "Sample_Name_Tissue_Type")
unified.patient <- toolboxR::CollapseDF(unified.sample, "Patient")
dictionary      <- readxl::read_excel('/tmp/mgp_dictionary.xlsx')
dictionary <- dictionary[,!names(dictionary) %in% ""]

PutS3Table(unified.file, s3.path = file.path(s3, "mgp-shiny/data", paste0("unified.per.file_", d, ".txt")))
PutS3Table(unified.sample, s3.path = file.path(s3, "mgp-shiny/data", paste0("unified.per.sample_", d, ".txt")))
PutS3Table(unified.patient, s3.path = file.path(s3, "mgp-shiny/data", paste0("unified.per.patient_", d, ".txt")))
PutS3Table(dictionary, s3.path = file.path(s3, "mgp-shiny/data", paste0("mgp_dictionary_", d, ".txt")))
