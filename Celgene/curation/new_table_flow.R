source("curation_scripts.R")
PRINTING = TRUE # turn off print to S3 when iterating

# import JointData tables ------------------------------------------------------
system(paste('aws s3 cp',
             file.path(s3, "ClinicalData/ProcessedData/JointData/"),
             local,
             '--recursive --exclude "*" --include "curated*"',
             '--exclude "archive*"', 
             sep = " "))

files      <- list.files(local, full.names = T)
dts        <- lapply(files, fread)
dt.names   <- gsub("curated_(.*?)[_\\.].*txt", "\\1", tolower(basename(files)))
names(dts) <- dt.names

### Filter excluded files ------------------------------------------------------
valid.files <- dts$metadata[Excluded_Flag == 0 | is.na(Excluded_Flag) ,
                            .(Patient, File_Name)]

master.dts <- lapply(names(dts), function(type){
  dt <- dts[[type]]
  if("File_Name" %in% names(dt)){dt <- dt[File_Name %in% valid.files$File_Name]
  }else if("Patient" %in% names(dt)){dt <- dt[Patient %in% valid.files$Patient]
  }else{stop("table doesn't have a filterable column")}
  
  n <- paste0("curated_", type, ".txt")
  if(PRINTING) PutS3Table(dt, file.path(s3, "ClinicalData/ProcessedData/Master", n))
  dt
})

names(master.dts) <- dt.names
# count excluded rows removed 
sapply(dts, dim) - sapply(master.dts, dim)

### Filter mm.nd.tumor files ---------------------------------------------------
nd.tumor.files <- master.dts$metadata[Disease_Status     == "ND" & 
                                    Sample_Type_Flag == 1    & 
                                    Disease_Type     == "MM" ,
                                  .(Patient, File_Name)]
nd.tumor.dts <- lapply(names(master.dts), function(type){
  dt <- master.dts[[type]]
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
names(nd.tumor.dts) <- dt.names

# compare changes after removing relapse files/patients
sapply(master.dts, dim) - sapply(nd.tumor.dts, dim)


### collapse individual tables to per.patient ----------------------------------
collapsed.dts <- lapply(names(nd.tumor.dts), function(type){
  
  dt <- local_collapse_dt(nd.tumor.dts[[type]], column.names = "Patient") 
  
  if(PRINTING){PutS3Table(dt,
                          file.path(s3, "ClinicalData/ProcessedData/Integrated", 
                                    paste("per.patient", type, "nd.tumor.txt", sep = ".")))
  }
  dt
  })
names(collapsed.dts) <- dt.names
# compare changes after collapse to patients
sapply(master.dts, dim) - sapply(collapsed.dts, dim)

### join metadata and clinical data into unified table -------------------------

setkey(collapsed.dts$metadata, Patient)
setkey(collapsed.dts$clinical, Patient)
unified <- collapsed.dts$metadata[collapsed.dts$clinical]


# sort by dictionary
dict      <- dict()
matched   <- dict$names[dict$names %in% names(unified)]
unmatched <- names(unified)[!names(unified) %in% dict$names]

setcolorder(unified, c(matched, unmatched))
if(PRINTING) PutS3Table(unified, 
                        file.path(s3, "ClinicalData/ProcessedData/Integrated/per.patient.unified.nd.tumor.txt"))

RPushbullet::pbPost("note", "done")
