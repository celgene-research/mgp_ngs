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

source("curation_scripts.R")
PRINTING = TRUE # turn off print to S3 when iterating



system(paste('aws s3 cp',
             file.path(s3, "ClinicalData/ProcessedData/Integrated/"),
             local,
             '--recursive --exclude "*" --include "per.patient*nd.tumor.txt"',
             '--exclude "archive*"', 
             sep = " "))

# import master files
files <- list.files(local, full.names = T)
# remove unnecessary tables before import
files <- grep("clinical|cnv|rnaseq|snv|translocation",files,value = T)

dts        <- lapply(files, fread)
names(dts) <- gsub(".*patient\\.([a-z]+)\\..*", "\\1", tolower(basename(files)))

# remove File_Name column and any rows where patients don't have info
# null <- sapply(dts, function(dt){print(dt[1:1000, 1:4])})
complete.dts <- lapply(dts, function(dt){
  if("File_Name" %in% names(dt)){ dt[,File_Name:=NULL] }
  # this only matches the clinical table, remove all but outcome cols
  if("Study" %in% names(dt)){ dt <- dt[,.SD, .SDcols = c("Patient", "D_PFS", "D_OS")] }
  
  rows.with.data <- apply(dt, 1, function(x){
    !all(is.na(x[2:length(x)]))
    })
  
  setkey(dt, "Patient")
  dt[rows.with.data]
})
sapply(complete.dts, dim) - sapply(dts, dim)

# data.table inner join
all <- complete.dts[[1]]
for( dt in complete.dts[2:length(complete.dts)] ){
  all <- all[dt, nomatch=0]
}
if(PRINTING) PutS3Table(all, file.path(s3, "ClinicalData/ProcessedData/Cluster", "per.patient.all.txt"))

# check out the subset
subset <- sample(all$Patient, 10)
dts[['clinical']][Patient %in% subset]
dts[['snv']][Patient %in% subset, 1:10]
dts[['cnv']][Patient %in% subset, 1:10]
dts[['rnaseq']][Patient %in% subset, 1:10]
dts[['translocations']][Patient %in% subset, c(1,25, 30, 32)]

# remove patients that have unambiguous longitudinal translocation consensus
# all <- all[!grepl(";",CYTO_Translocation_Consensus), ]

# finally, we also want to filter the individual type tables, 
# including the previously excluded metadata and BI tables
dts2      <- lapply(c("/tmp/curation/per.patient.metadata.nd.tumor.txt",
                      "/tmp/curation/per.patient.biallelicinactivation.nd.tumor.txt"), fread)
names(dts2) <- c("metadata", "biallelicinactivation")
dts <- c(dts,dts2)

dts.complete <- lapply(names(dts), function(type){
  dt <- dts[[type]]
  dt <- dt[Patient %in% all[,Patient]]
  n <- paste("per.patient", type, "complete.txt", sep = ".")
  if(PRINTING) PutS3Table(dt, file.path(s3, "ClinicalData/ProcessedData/Cluster", n))
  dt
})

RPushbullet::pbPost('note', 'done')

# count appended values in third column to guage collapse efficiency
sapply(complete.dts, function(dt){
  sum(grepl("; ", dt[[3]]))
})


