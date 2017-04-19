source("curation_scripts.R")
PRINTING = TRUE # turn off print to S3 when iterating

# remove "Study" from blood table
# blood <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/JointData/curated_blood_2017-04-17.txt"), reader = "fread")
# PutS3Table(object = blood[,Study:=NULL], s3.path = file.path(s3, "ClinicalData/ProcessedData/JointData/curated_blood_2017-04-17.txt"))


### Filter JointData to Master
system(paste('aws s3 cp',
             file.path(s3, "ClinicalData/ProcessedData/JointData/"),
             local,
             '--recursive --exclude "*" --include "curated*"',
             '--exclude "archive*"', 
             sep = " "))

# import Jointdata files
files      <- list.files(local, full.names = T)
dts        <- lapply(files, fread)
names(dts) <- gsub("curated_(.*?)[_\\.].*txt", "\\1", tolower(basename(files)))
# # move metadata and clinical to front
# dts        <- c(dts['clinical'], dts[!grepl("clinical", names(dts))])
# dts        <- c(dts['metadata'], dts[!grepl("metadata", names(dts))])
# filter for only valid files and patients, put back filtered copies to MASTER
valid.files <- dts$metadata[Excluded_Flag == 0 | is.na(Excluded_Flag) ,.(Patient, File_Name)]

master <- lapply(names(dts), function(type){
  dt <- dts[[type]]
  if("File_Name" %in% names(dt)){dt <- dt[File_Name %in% valid.files$File_Name]
  }else if("Patient" %in% names(dt)){dt <- dt[Patient %in% valid.files$Patient]
  }else{stop("table doesn't have a filterable column")}
  
  n <- paste0("curated_", type, ".txt")
  if(PRINTING) PutS3Table(dt, file.path(s3, "ClinicalData/ProcessedData/Master", n))
  dt
})
names(master) <- names(dts)
# count excluded rows removed 
sapply(dts, dim) - sapply(master, dim)

#######################################
# join for per.file.all.txt
per.file.all <- data.table()
for( dt in master ){
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
nd.tumor.files <- master$metadata[Disease_Status == "ND" & Sample_Type_Flag == 1 & Disease_Type == "MM" ,.(Patient, File_Name)]
nd.tumor.dts <- lapply(names(master), function(type){
  dt <- master[[type]]
  # if has a file_name use that, else use patient
  if( "File_Name" %in% names(dt) ){
    level <- "per.file"
    dt    <- dt[File_Name %in% nd.tumor.files$File_Name]
  }else{
    level <- "per.patient"
    dt    <- dt[Patient %in% nd.tumor.files$Patient]
  }
  n <- paste(level, type, "nd.tumor.txt", sep = ".")
  if(PRINTING) PutS3Table(dt, file.path(s3, "ClinicalData/ProcessedData/Integrated", n))
  dt
})
names(nd.tumor.dts) <- names(master)
# filter and print the ALL version too
per.file.all.nd.tumor <- per.file.all[File_Name %in% nd.tumor.files$File_Name]
if(PRINTING) PutS3Table(per.file.all.nd.tumor, 
                        file.path(s3, "ClinicalData/ProcessedData/Integrated", 
                                  "per.file.all.nd.tumor.txt"))

# compare changes after removing relapse files/patients
sapply(master, dim) - sapply(nd.tumor.dts, dim)


# collapse each individual table to per.patient
###############################################
collapsed.dts <- lapply(nd.tumor.dts, function(dt){
  local_collapse_dt(dt, column.names = "Patient") })
sapply(collapsed.dts, dim)
names(collapsed.dts) <- names(nd.tumor.dts)

# export each molecular table as per.patient.snv.nd.tumor ...
###########################################
null <- lapply(names(collapsed.dts), function(type){
  n <- paste("per.patient", type, "nd.tumor.txt", sep = ".")
  if(PRINTING){PutS3Table(collapsed.dts[[type]],
             file.path(s3, "ClinicalData/ProcessedData/Integrated", n))}
})



# cbind to get per.patient.unified.all.nd.tumor
# TODO: retain File_Name for each data type for tracing
# 
all <- data.table()
for( dt in collapsed.dts ){
  setkey(dt, "Patient")
  if( nrow(all) == 0 ){
    all <- dt[,File_Name:=NULL]
  }else {
    if( ("File_Name" %in% names(dt)) ) dt <- dt[,File_Name:=NULL]
    all <- merge(all, dt, all=TRUE, fill = T)
  }
  print("Study" %in% names(all))
}

# sort by dictionary
dict      <- dict()
matched   <- dict$names[dict$names %in% names(all)]
unmatched <- names(all)[!names(all) %in% dict$names]

setcolorder(all, c(matched, unmatched))
if(PRINTING) PutS3Table(all, 
                        file.path(s3, "ClinicalData/ProcessedData/Integrated/per.patient.unified.all.nd.tumor.txt"))

RPushbullet::pbPost("note", "done")
