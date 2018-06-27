# add all missing and blank dicitonary columns to JointData tables
source("curation_scripts.R")
CleanLocalScratch()
system(paste('aws s3 cp',
             file.path(s3, "ClinicalData/ProcessedData/JointData/"),
             local,
             '--recursive --exclude "*" --include "curated*"',
             '--exclude "archive*"', 
             sep = " "))

files      <- list.files(local, full.names = T)
dts        <- lapply(files, fread)
dt.names   <- gsub("curated_(.*?)[_\\.].*txt", "\\1", tolower(basename(files)))
if( any(duplicated(dt.names)) )stop("multiple file of the same type were imported")
names(dts) <- dt.names

dict <- get_dict()

tables.to.adjust <- c("blood", "clinical", "metadata", "translocations" )
appended.dts <- lapply(tables.to.adjust, function(t){
  dt <- dts[[t]]
  filtered.dict <- dict %>% filter(grepl(t, level))
  missing.columns <- filtered.dict$names[!filtered.dict$names %in% names(dt)]
  dt[,missing.columns] <- NA
  dt
  
})
names(appended.dts) <- tables.to.adjust
sapply(appended.dts, names)


null <- lapply(tables.to.adjust, function(n){
  name <- paste0("curated_", n, "_", d, ".txt")
  path <- file.path(s3, "ClinicalData/ProcessedData/JointData", name)
  # PutS3Table(appended.dts[[n]], path)
  names(appended.dts[[n]])
})

archive(file.path(s3, "ClinicalData/ProcessedData/JointData"))
