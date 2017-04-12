
source("curation_scripts.R")

rna.594 <- GetS3Table(file.path(s3, 
                            "ClinicalData/ProcessedData/Cluster", 
                            "per.patient.rnaseq.complete.txt"), 
                  reader = "fread")

rna.594[grepl("; ", RNA_ENSG00000000003.14), 1:3]

# revised to specify Disease_Type == "MM" in nd.tumor filtration
#  nd.tumor.files    <- dts[['metadata']][Disease_Status == "ND" & Sample_Type_Flag == 1 & Disease_Type == "MM", File_Name]
#  nd.tumor.patients <- dts[['metadata']][Disease_Status == "ND" & Sample_Type_Flag == 1 & Disease_Type == "MM", Patient]
#  
# source('2017-04-06_new_table_flow.R')
# 
# source('2017-04-07_subset_for_clustering.R')

# QC on commandline
# find . -name "per*" | xargs grep --with-filename --line-number -o -Ei ".{50}; .{50}" -
# # only prints "; "-appended list of File_Names (expected) 
# 
# or after trimming off the first 2 columns (File_Name)
# find . -name "per*" | xargs -n1 cat - | cut -f3- | grep --with-filename --line-number -o -Ei ".{50}; .{50}"
# only prints values from "File_Path"
# 
# count rows in each file, looks like they all have appropriately 580 patients.
# find . -name "per*" | xargs wc -l
# 580 ./per.patient.clinical.complete.txt
# 580 ./per.patient.all.txt
# 580 ./per.patient.cnv.complete.txt
# 580 ./per.patient.snv.complete.txt
# 580 ./per.patient.rnaseq.complete.txt
# 580 ./per.patient.metadata.complete.txt
# 453 ./per.patient.biallelicinactivation.complete.txt
# 580 ./per.patient.translocations.complete.txt
