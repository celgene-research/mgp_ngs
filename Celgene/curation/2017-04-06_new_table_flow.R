source("curation_scripts.R")
PRINTING = TRUE # turn off print to S3 when iterating

system(paste('aws s3 cp',
             file.path(s3, "ClinicalData/ProcessedData/Master/"),
             local,
             '--recursive --exclude "*" --include "curated*"',
             '--exclude "archive*"', 
             sep = " "))

# import master files
files      <- list.files(local, full.names = T)
dts        <- lapply(files, fread)
names(dts) <- gsub("curated_(.*?)\\.txt", "\\1", tolower(basename(files)))
# move metadata and clinical to front
dts        <- c(dts['clinical'], dts[!grepl("clinical", names(dts))])
dts        <- c(dts['metadata'], dts[!grepl("metadata", names(dts))])
names(dts)

# join for per.file.all.txt
per.file.all <- data.table()
for( dt in dts ){
  if( nrow(per.file.all) == 0 ){
    per.file.all <- dt
  }else if( ("File_Name" %in% names(dt)) ){
    if(("Patient" %in% names(dt))){dt <- dt[,!"Patient", with=T]}
    per.file.all <- merge(per.file.all, dt, all=TRUE, fill = T)
  }
}
if(PRINTING) PutS3Table(per.file.all, file.path(s3, "ClinicalData/ProcessedData/Integrated/per.file.all.txt"))

# filter EACH table for nd.tumor only
################################################
nd.tumor.files    <- dts[['metadata']][Disease_Status == "ND" & Sample_Type_Flag == 1, File_Name]
nd.tumor.patients <- dts[['metadata']][Disease_Status == "ND" & Sample_Type_Flag == 1, Patient]

nd.tumor.dts <- lapply(names(dts), function(type){
  dt <- dts[[type]]
  # if has a file_name use that, else use patient
  if( "File_Name" %in% names(dt) ){
    level <- "per.file"
    dt    <- dt[File_Name %in% nd.tumor.files]
  }else{
    level <- "per.patient"
    dt    <- dt[Patient %in% nd.tumor.patients]
  }
  n <- paste(level, type, "nd.tumor.txt", sep = ".")
  if(PRINTING) PutS3Table(dt, file.path(s3, "ClinicalData/ProcessedData/Integrated", n))
  dt
})
names(nd.tumor.dts) <- names(dts)
# filter and print the ALL version too
per.file.all.nd.tumor <- per.file.all[File_Name %in% nd.tumor.files]
if(PRINTING) PutS3Table(per.file.all.nd.tumor, 
                        file.path(s3, "ClinicalData/ProcessedData/Integrated", 
                                  "per.file.all.nd.tumor.txt"))

# compare changes after removing relapse files/patients
sapply(nd.tumor.dts, dim) - sapply(dts, dim)
dim(per.file.all.nd.tumor) - dim(per.file.all)



# collapse each individual table to per.patient
###########################################
collapsed.dts <- lapply(nd.tumor.dts, function(dt){
  local_collapse_dt(dt, column.names = "Patient") })
sapply(collapsed.dts, dim)
names(collapsed.dts) <- names(nd.tumor.dts)

# export each molecular table as per.patient.snv.nd.tumor ...
###########################################
null <- lapply(names(collapsed.dts), function(type){
  n <- paste("per.patient", type, "nd.tumor.txt", sep = ".")
  PutS3Table(collapsed.dts[[type]],
             file.path(s3, "ClinicalData/ProcessedData/Integrated", n))
})



# cbind to get per.patient.unified.all.nd.tumor
# TODO: retain File_Name for each data type for tracing
collapsed.dts <- lapply(collapsed.dts, function(dt){setkey(dt, "Patient")})
per.patient.unified.all.nd.tumor <- data.table()
for( dt in collapsed.dts ){
  if( nrow(per.patient.unified.all.nd.tumor) == 0 ){
    per.patient.unified.all.nd.tumor <- dt
  }else {
    if( ("File_Name" %in% names(dt)) ) dt <- dt[,!"File_Name", with = F]
    per.patient.unified.all.nd.tumor <- merge(per.patient.unified.all.nd.tumor, dt, all=TRUE, fill = T)
  }
  per.patient.unified.all.nd.tumor
}
if(PRINTING) PutS3Table(per.patient.unified.all.nd.tumor, 
                        file.path(s3, "ClinicalData/ProcessedData/Integrated/per.patient.unified.all.nd.tumor.txt"))

RPushbullet::pbPost("note", "done")
