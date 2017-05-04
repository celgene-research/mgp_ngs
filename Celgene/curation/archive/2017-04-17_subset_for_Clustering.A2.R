# in order to facilitate ideal clustering input I've been asked to generate
# a subset of patient-level data that includes only patients with:
# 
#   Clinical outcome data (D_PFS and D_OS)
#   SNP
#   CNV
#   CYTO ( Translocations )
#   RNA  ( Normalized RNA-Seq trascript counts)
#   
# Since I now have these data as individual patient-level summaries for nd.tumor
# data I can simply merge these tables together and retain only intersect rows.
# 
# ########################
# 2017-04-17 came to light today that the curated CNV table includes files with
# invalid results, I'm going to rerun this to exclude.
# 
# this function now relies on having the patient membership designated on the 
# patient inventory table (Reports/2017-04-18_patient_inventory_counts.txt) and will
# filter Integrated/per.patient*nd.tumor tables based on a designated column   
cluster.name <- "Cluster.A2"


source("curation_scripts.R")

system(paste('aws s3 cp',
             file.path(s3, "ClinicalData/ProcessedData/Integrated/"),
             local,
             '--recursive --exclude "*" --include "per.patient*nd.tumor.txt"',
             '--exclude "archive*"', 
             sep = " "))

files <- list.files(local, full.names = T)
files <- grep("biallelic|blood|clinical|cnv|metadata|rnaseq|snv|translocation",files,value = T)
dts        <- lapply(files, fread)
names(dts) <- gsub(".*patient\\.([a-z]+)\\..*", "\\1", tolower(basename(files)))

# Using the inventory columns on metadata table to get a patient/file filter list
inv              <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Reports/2017-04-18_patient_inventory_counts.txt"))
cluster.patients <- inv %>% filter(grepl("1", inv[[cluster.name]])) %>% .[['Patient']]

filtered.dts <- lapply(dts, function(dt){
  dt[Patient %in% cluster.patients]
})
sapply(filtered.dts, dim)

sapply(filtered.dts, dim) - sapply(dts, dim)

View(filtered.dts$metadata)

# once you've verified that this is filtering correctly you can write the subset 
# to a S3 along with a patient list in README 
tmp <- lapply(names(filtered.dts), function(n){
  dt   <- filtered.dts[[n]]
  name <- paste0(n, "_subset.txt")
 PutS3Table(dt, file.path(s3, "ClinicalData/ProcessedData", cluster.name, name))
})
