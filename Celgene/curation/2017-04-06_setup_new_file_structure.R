
source("curation_scripts.R")

# fully curated domain tables will go in the ClinicalData/ProcessedData/Master
# directory. These all share a similar shape, with files/patients in rows and
# variable columns. All tables will use a harmonized File_Name identifier in 
# addition to a Patient files to make joins easier
# ( with the exception of curated.clinical.txt which uses Patient ).
# 
# Any updates should be made directly to these tables since they are the source
# for all filtered and joined descendants found in /Integrated/
#

# since some of these tables are very large I'll transfer locally and read in 
# with fread since my normal fetch function doesn't yet utilize data.tables
system(paste('aws s3 cp',
             file.path(s3, "ClinicalData/ProcessedData/Integrated/"),
             local,
             '--recursive --exclude "*" --include "per.file.clinical.txt"',
             '--include "per.patient.clinical.txt" --exclude "archive*"', 
             sep = " "))
system(paste('aws s3 cp',
             file.path(s3, "ClinicalData/ProcessedData/JointData/"),
             local,
             '--recursive --exclude "*" --include "curated*"',
             '--exclude "archive*"', 
             sep = " "))

# read all files into a named list
files <- list.files(local, full.names = T)
dts        <- lapply(files, fread)
names(dts) <- gsub("curated_(.*?)_.*", "\\1", tolower(basename(files)))
names(dts) <- gsub("per.file.clinical.txt", "metadata", names(dts))
names(dts) <- gsub("per.patient.clinical.txt", "clinical", names(dts))

# since I'm running this a few times I need to remove downstream tables
dts <- dts[!names(dts) %in% c( "curated_blood.txt", "curated_metadata.txt")]
names(dts)

# remove the blood results from the metadata table and save separately 
# blood <- dts[['metadata']] %>% 
#   select(File_Name, Patient, Study, CBC_Absolute_Neutrophil:IG_IgE) 
# PutS3Table(blood, file.path(s3, "ClinicalData/ProcessedData/JointData/curated_blood.txt"))
dts[['metadata']] <-   dts[['metadata']] %>% select(-c(CBC_Absolute_Neutrophil:IG_IgE))

# clean a few specific issues per table
# remove INV and Disease_Type columns from clinical (already in metadata)
dts[['clinical']] <- dts[['clinical']] %>% select(-starts_with("INV")) %>% select(-c(Disease_Type))

# add excluded files back to metadata file so we can verify removal 
seqqc   <- GetS3Table(file.path(s3, "ClinicalData/OriginalData/MMRF_IA10c", "README_FILES", 
                             "MMRF_CoMMpass_IA10_Seq_QC_Summary.xlsx")) %>%
  transmute(File_Name        =   `QC Link SampleName`,
            Patient          = `Patients::KBase_Patient_ID`,
            Excluded_Flag    = as.numeric(grepl("^Exclude|RNA-No|LI-Neither|Exome-Neither",
                                                .$MMRF_Release_Status)),
            Excluded_Specify = MMRF_Release_Status)
dts[['metadata']] <- rbindlist(list(dts[['metadata']], 
                                            seqqc[!(seqqc$File_Name %in% dts[['metadata']]$File_Name),]), 
                                       fill = T)

# also add all files for excluded patients
foo <- system('grep -e "MMRF_1015" -e "MMRF_1125" -e "MMRF_1400" -e "MMRF_1457" -e "MMRF_1961" -e "MMRF_2069" -e "MMRF_2088" ~/Desktop/ProcessedData/Integrated/file_inventory.txt | cut -d/ -f6 | sed "s/\\..*//g"', intern=T )
# all filenames are already there, just need to flag tham
# foo %in% curated.dts[['metadata']]$File_Name
left.patients <- c("MMRF_1015","MMRF_1125","MMRF_1400","MMRF_1457","MMRF_1961","MMRF_2069","MMRF_2188")
dts[['metadata']][ Patient %in% left.patients, "Excluded_Flag"]    <- 1
dts[['metadata']][ Patient %in% left.patients, "Excluded_Specify"] <- "Patient left trial"
excluded.files <- dts[['metadata']][Excluded_Flag == 1, File_Name]
# save the entire metadata file for future filtering 
PutS3Table(dts[['metadata']], file.path(s3, "ClinicalData/ProcessedData/JointData/curated_metadata.txt"))

# add patient identifiers and remove excluded results
###########################################
patient.lookup <- dts[['metadata']][,.(Patient, File_Name)] %>% setkey(File_Name)

curated.dts <- lapply(1:length(dts), function(i){
  dt   <- dts[[i]]
  name <- names(dts)[i]
  # add patient column
  if( !("Patient" %in% names(dt)) & ("File_Name" %in% names(dt)) ){ dt <- merge(patient.lookup, dt, all.y = T)}
  # filter to remove excluded files and patients
  if( ("File_Name" %in% names(dt)) ){ dt <- dt[ !File_Name %in% excluded.files ] }
  PutS3Table(dt, file.path(s3, "ClinicalData/ProcessedData/Master", paste0("curated_", name, ".txt")))
  dt
})
names(curated.dts) <- names(dts)
# see what was filtered: removed excluded files, added a patient row
sapply(curated.dts, dim) - sapply(dts, dim)

# this is the end of MASTER files generation,
################################################
################################################
################################################
