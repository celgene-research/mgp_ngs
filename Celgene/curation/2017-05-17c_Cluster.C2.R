
inventory.file <- "counts.by.individual.2017-05-17.txt"

inv <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Reports",
                            inventory.file))
patient.lists <- list(Cluster.C = inv[ inv$Cluster.C == 1, "Patient" ],
                      Cluster.C2 = inv[ inv$Cluster.C2 == 1, "Patient" ])

###
source("curation_scripts.R")
archive(file.path(s3, "ClinicalData/ProcessedData/ND_Tumor_MM"))

system(paste('aws s3 cp',
             file.path(s3, "ClinicalData/ProcessedData/ND_Tumor_MM"),
             local,
             '--recursive --exclude "*" --include "per.patient*"',
             '--exclude "archive*" --exclude "*unified*" ', 
             sep = " "))


files <- list.files(local, full.names = T)
files <- grep("biallelic|blood|clinical|cnv|metadata|rnaseq|snv|translocation",files,value = T)
dts        <- lapply(files, fread)
names(dts) <- gsub(".*patient\\.([a-z]+)\\..*", "\\1", tolower(basename(files)))






out <- lapply(names(patient.lists), function(cluster.name){
  
  PutS3Table(patient.lists[[cluster.name]], file.path(s3,"ClinicalData/ProcessedData", cluster.name,
                                                      paste("patient.list",d, "txt", sep = ".")),
             col.names = F)
  
  filtered.dts <- lapply(names(dts), function(table.name){
    dt   <- dts[[table.name]][Patient %in% patient.lists[[cluster.name]]$Patient]
    name <- paste(table.name, "subset",d, "txt", sep = ".")
    PutS3Table(dt, file.path(s3, "ClinicalData/ProcessedData", cluster.name, name))
    dt
  })
  archive(file.path(s3, "ClinicalData/ProcessedData", cluster.name))
  filtered.dts
})

# 
# prev <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Cluster.A2",
#                             "archive/metadata.subset.2017-04-18.txt"))
# new  <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Cluster.A2",
#                              "metadata.subset.2017-05-16.txt"))
# 
# prev$Patient[!prev$Patient %in% new$Patient]
# venn::venn(list(prev$Patient, new$Patient))
# 
# joint.metadata  <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/JointData",
#                              "curated.metadata.2017-05-16.txt"))
# master.metadata  <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Master",
#                                         "curated.metadata.2017-05-16.txt"))
# 
# cluster.c2.meta <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Cluster.C2",
#                                        "metadata.subset.2017-05-17.txt"))
