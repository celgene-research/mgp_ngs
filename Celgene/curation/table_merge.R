

# merge final clinical tables with desired summary analysis tables
s3clinical      <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData"
local_path      <- "/tmp/curation"
if(!dir.exists(local_path)){dir.create(local_path)}

source("curation_scripts.R")
#######################
# CNV



# copy curated files locally
system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData", "Integrated"), local_path, '--recursive --exclude "*" --include "PER*"', sep = " "))
system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData", "Joint_datasets", "curated_CNV_ControlFreec.txt"), local_path, sep = " "))


df <-  merge_table_files(file1 = file.path(local_path,"PER-FILE_clinical_cyto.txt"),
                         file2 = file.path(local_path,"curated_CNV_ControlFreec.txt"),
                                           id = "File_Name")


write.table(df, file.path(local_path,"PER-FILE_cyto_cnv.txt"), row.names = F, col.names = T, sep = "\t", quote = F)

##
# add patient level information, this will be redundant
df <-  merge_table_files(file1 = file.path(local_path,"PER-FILE_cyto_cnv.txt"),
                         file2 = file.path(local_path,"PER-PATIENT_clinical.txt"),
                         id = "Patient")


write.table(df, file.path(local_path,"PER-FILE_ALL.txt"), row.names = F, col.names = T, sep = "\t", quote = F)

# put back the all table
name <- "PER-FILE_ALL.txt"
system(  paste('aws s3 cp', file.path(local_path,name), file.path(s3clinical, "ProcessedData", "Integrated", name), '--sse', sep = " "))
