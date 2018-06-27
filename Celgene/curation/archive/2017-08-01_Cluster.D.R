#Generate cluster D with 1273 valid WES patients 

source("curation_scripts.R")
s3_cd("/ClinicalData/ProcessedData")

# current inventory table to identify patients with applicable wes results
inv  <- s3_get_table("Reports/counts.by.individual.2017-07-25.txt")

# filter the complete mgp dataset to only consider patients with valid exome results.
mgp.wes <- s3_get_table("ND_Tumor_MM/per.patient.unified.nd.tumor.2017-07-27.txt") %>% 
  filter( Patient %in% inv[inv$INV_Has.nd.snv == 1,"Patient"]) %>%
  mutate(set = "MGP")

#Cluster D patients
patients.D <- mgp.wes %>% select(Patient)

#Filter ND_Tumor_MM tables for cluster D patients
cluster.D <- sapply(s3_ls("ND_Tumor_MM", pattern = "^per.patient", full.names = T), function(table){
  s3_get_with(table,
              FUN = fread) %>%
    filter(Patient %in% patients.D$Patient)
})

#Remove unified table
cluster.D <- cluster.D[-10]

#Get table names
table.names <- sapply(basename(names(cluster.D)), function(name){
  paste(strsplit(name, "\\.")[[1]][3], "subset", sep = ".")
})

#Put cluster D tables
sapply(1:length(cluster.D), function(x){
    s3_put_table(cluster.D[[x]], paste0("Cluster.D/", paste(table.names[x], Sys.Date(), "txt", sep = ".")))
})

#Add patient list
s3_put_table(unname(as.vector(patients.D)), paste("Cluster.D/patient.list", Sys.Date(), "txt", sep="."))