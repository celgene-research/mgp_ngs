#Generate cluster E with 1074 CNV WES patients 

source("curation_scripts.R")
s3_cd("/ClinicalData/ProcessedData")

# current inventory table to identify patients with applicable wes results
inv  <- s3_get_table("Reports/counts.by.individual.2017-07-25.txt")

# filter the complete mgp dataset to only consider patients with valid exome results and CNV.
mgp.wes <- s3_get_table("ND_Tumor_MM/per.patient.unified.nd.tumor.2017-07-27.txt") %>% 
  filter( Patient %in% inv[inv$INV_Has.nd.snv == 1 & inv$INV_Has.nd.cnv == 1,"Patient"]) %>%
  mutate(set = "MGP")

#Cluster E patients
patients.E <- mgp.wes %>% select(Patient)

#Filter ND_Tumor_MM tables for cluster E patients
cluster.E <- sapply(s3_ls("ND_Tumor_MM", pattern = "^per.patient", full.names = T), function(table){
  s3_get_with(table,
              FUN = fread) %>%
    filter(Patient %in% patients.E$Patient)
})

#Remove unified table
cluster.E <- cluster.E[-10]

#Get table names
table.names <- sapply(basename(names(cluster.E)), function(name){
  paste(strsplit(name, "\\.")[[1]][3], "subset", sep = ".")
})

#Put cluster E tables
sapply(1:length(cluster.E), function(x){
  s3_put_table(cluster.E[[x]], paste0("cluster.E/", paste(table.names[x], Sys.Date(), "txt", sep = ".")))
})

#Add patient list
s3_put_table(unname(as.vector(patients.E)), paste("cluster.E/patient.list", Sys.Date(), "txt", sep="."))