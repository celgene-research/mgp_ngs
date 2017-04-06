
source("curation_scripts.R")

# 
# read in unfiltered per.file tables (clinical, translocation, snv, cnv, rna, bi)
# filter to include only nd.tumor files
#   cbind to get per.file.all.nd.tumor
# 
# collapse each individual table to patient
#   export each molecular table as per.patient.snv.nd.tumor ...
#   cbind along with per.patient.clinical to get per.patient.unified.all.nd.tumor 
# 


# read in unfiltered per.file tables
###########################################
per.file.clinical <- toolboxR::GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Integrated/per.file.clinical.txt")) %>%
  select(-starts_with("CYTO")) %>%
  as.data.table() %>%
  setkey("File_Name")

# fetch the individual molecular tables and import as a list of DT so we can parallelize processing
s3joint    <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/JointData"
system(paste('aws s3 cp', s3joint, local, '--recursive --exclude "*" --include "curated*" --exclude "archive*"', sep = " "))
files <- list.files(local, pattern = "^curated", full.names = T)
dts        <- lapply(files, fread)
names(dts) <- gsub("curated_(.*?)_.*", "\\1", tolower(basename(files)))

# # Check that all tables have a File_Name column
# if( !all(sapply(dts, function(x){"File_Name" %in% names(x)})) ){
#   stop("At least one curated table is missing the File_Name column")}
lapply(dts, setkey, File_Name)

# add the clinical table to the list
dts <- c(list(clinical = per.file.clinical), dts)
sapply(dts, dim)

# filter to include only nd.tumor files
###########################################
nd.tumor.lookup <- per.file.clinical[Disease_Status == "ND" &
                                       Sample_Type_Flag == 1,
                                     .(Patient, File_Name)] %>%
  setkey(File_Name)

nd.tumor.dts <- lapply(dts, function(dt){
  # remove Patient column already present on clinical table
  if( "Patient" %in% names(dt) ){dt <- dt[,!"Patient", with = F]}
  # add patient identifiers for nd.tumor samples and filter those without patient
  merge(nd.tumor.lookup, dt, all.y = T)[!is.na(Patient)]
})
lapply(nd.tumor.dts, dim)
# now that they all have PAtient column we can index by both
lapply(nd.tumor.dts, function(dt){
  setkeyv(dt, c("File_Name", "Patient")) })

# cbind individual filtered tables to get per.file.all.nd.tumor
###########################################
per.file.all.nd.tumor <- nd.tumor.lookup %>% setkeyv(c("File_Name", "Patient"))
for( i in nd.tumor.dts ){
  per.file.all.nd.tumor <- merge(per.file.all.nd.tumor, i, all.x=TRUE, fill = T)
}
dim(per.file.all.nd.tumor)


# collapse each individual table to per.patient
###########################################
collapsed.dts <- lapply(nd.tumor.dts, function(dt){
  local_collapse_dt(dt, column.names = "Patient") })
sapply(collapsed.dts, dim)


# export each molecular table as per.patient.snv.nd.tumor ...
###########################################
lapply(names(collapsed.dts), function(type){
  n <- paste("per.patient", type, "nd.tumor.txt", sep = ".")
  PutS3Table(collapsed.dts[[type]], 
             file.path(s3, "ClinicalData/ProcessedData/Integrated", n))
})


# cbind along with per.patient.clinical to get per.patient.unified.all.nd.tumor 
###########################################
per.patient.unified.all.nd.tumor <- toolboxR::GetS3Table(file.path(s3, 
    "ClinicalData/ProcessedData/Integrated/per.patient.clinical.nd.tumor.txt")) %>%
  select(-starts_with("INV")) %>%
  as.data.table() %>%
  setkey("Patient")

for( i in 1:length(collapsed.dts) ){
  setkey(collapsed.dts[[i]], "Patient")

  # rename File_Name in each subtable to retain source info
  # e.g. File_Name --> File_Name_translocations
  setnames(collapsed.dts[[i]], "File_Name", paste("File_Name", names(collapsed.dts)[i], sep = "_"))
  
  per.patient.unified.all.nd.tumor <- merge(per.patient.unified.all.nd.tumor, collapsed.dts[[i]], all.x=TRUE, fill = T)
}
dim(per.patient.unified.all.nd.tumor)

PutS3Table(per.patient.unified.all.nd.tumor, 
           file.path(s3, "ClinicalData/ProcessedData/Integrated/per.patient.unified.all.nd.tumor.txt"))

# and also put a version with just the clinical data (derived from per.patient + collapsed per.file)
x <- per.patient.unified.all.nd.tumor
per.patient.unified.clinical.nd.tumor <- x[,!grep("^SNV|^CNV|^BI|^RNA|^CYTO|^File_Name_", names(x), value = T), with=F]

# PutS3Table(per.patient.unified.clinical.nd.tumor,
           # file.path(s3, "ClinicalData/ProcessedData/Integrated/per.patient.unified.clinical.nd.tumor.txt"))
RPushbullet::pbPost("note", "done")
