## drozelle@ranchobiosciencs.com
##
## 2017-02-20 revised to incorporate second iteration of molecular calls
source("curation_scripts.R")
local <- CleanLocalScratch()

per.file <- toolboxR::GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Integrated/per.file.clinical.txt"))
# import call file and rename columns for integrated dictionary
# this table is huge, so we'll manuallt download and fread
name <- "RNAseq_MMRF_DFCI_Normalized_BatchCorrected_2017-03-30.txt" 
system(paste('aws s3 cp',
             file.path(s3,"ClinicalData/OriginalData/Joint", name),
             local, sep = " "))
# fix the stupid row.names
system(paste('sed -ir "1s/^M/names\tM/g"', file.path(local,name)))
rna        <- fread(file.path(local, name))

gene.names <- as.character(rna$names)
file.names <- names(rna)[2:ncol(rna)]

rna        <- rna[,-1]  
rna        <- transpose(rna)
names(rna) <- gene.names

# convert identifiers to applicable File_Name and bind to front of table
File_Name_Lookup <- case_when((file.names %in% per.file$File_Name) ~ file.names,
                       !(file.names %in% per.file$File_Name) & (file.names %in% per.file$Patient) ~ per.file$File_Name[match(file.names, per.file$Patient)],
                       TRUE ~ as.character(NA))

# filter to only include files that match rows in per.file
rna        <- cbind(File_Name = File_Name_Lookup, rna)
name <- paste0("curated_", name)
PutS3Table(rna[!is.na(File_Name)], file.path(s3, "ClinicalData/ProcessedData/JointData", name))


# write unmatched rows to separate file
unmatched  <- rna[is.na(File_Name)]
unmatched$File_Name <- file.names[!File_Name_Lookup %in% per.file$File_Name]
# "056_002MF.2" "056_003RM.1" "104_001FM.2" "001_057AP.1" "029_006MM.2" "015_016BG.2"
PutS3Table(unmatched, file.path(s3, "ClinicalData/ProcessedData/JointData", "unmatched_RNAseq_counts.txt"))




# 2017-04-06 forgot to add column name prefixes
name <- "curated_RNAseq_MMRF_DFCI_Normalized_BatchCorrected_2017-03-30.txt"
system(paste('aws s3 cp',
             file.path(s3,"ClinicalData/ProcessedData/JointData", name),
             local, sep = " "))
# fix the stupid row.names
system(paste('sed -ir "1s/ENSG/RNA_ENSG/g"', file.path(local,name)))

system(paste('aws s3 cp',
             file.path(local,name),
             file.path(s3,"ClinicalData/ProcessedData/JointData", name),
             '--sse', sep = " "))

