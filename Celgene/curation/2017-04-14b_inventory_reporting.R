# 2017-04-14 Dan Rozelle
# Adding data-type inventory columns to /JointData/curated_metadata table
# Filter curated /Jointdata files to remove excluded files/patients into /MASTER
# Generating binary report matrix
# Summarize per.patient attributes  
# 

source("curation_scripts.R")

copy.s3.to.local(file.path(s3, "ClinicalData/ProcessedData/JointData"),
                 aws.args = '--recursive --exclude "*" --include "curated_*" --exclude "archive*"')
f <- list.files(local, full.names = T)
joint <- lapply(f, fread)
names(joint) <- gsub("curated_([a-z]+).*", "\\1", tolower(basename(f)))
names(joint)

# Import NMF signatures to append to metadata table
nmf <- GetS3Table(file.path(s3, "ClinicalData/OriginalData/Joint/2017-03-08_NMF_mutation_signature.txt")) %>% 
  mutate(
    File_Name = case_when(
      grepl("^_E", .$FullName) ~ gsub(".*_([A-Za-z].*)", "\\1", .$FullName),
      grepl("^H", .$FullName)  ~ gsub("HUMAN_37_pulldown_", "", .$FullName),
      TRUE ~ .$FullName),
    NMF_Signature_Cluster = NMF2) %>%
  select(File_Name, NMF_Signature_Cluster)


# curate clinical and metadata tables based on dictionary revisions
# remove Study, INV columns from clinical
joint$clinical <- joint$clinical %>%  select(-c(Study, starts_with("INV")))
# remove Disease_Type and add INV columns for other tables
joint$metadata <- joint$metadata %>%  select(-c(Disease_Type)) %>%
  mutate( 
    INV_Has.Blood          = as.numeric(File_Name %in% joint$blood[['File_Name']]),
    INV_Has.BI             = as.numeric(File_Name %in% joint$biallelicinactivation[['File_Name']]),
    INV_Has.Clinical       = as.numeric(Patient   %in% joint$clinical[['Patient']]),
    INV_Has.CNV            = as.numeric(File_Name %in% joint$cnv[['File_Name']]),
    INV_Has.RNASeq         = as.numeric(File_Name %in% joint$rnaseq[['File_Name']]),
    INV_Has.SNV            = as.numeric(File_Name %in% joint$snv[['File_Name']]),
    INV_Has.Translocations = as.numeric(File_Name %in% joint$translocations[['File_Name']])  )  %>%
  left_join(nmf, by = "File_Name")


