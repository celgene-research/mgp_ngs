

# merge final clinical tables with desired summary analysis tables
s3clinical      <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData"
local_path      <- "/tmp/curation"
if(!dir.exists(local_path)){dir.create(local_path)}

source("curation_scripts.R")

# copy curated files locally
system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData", "Integrated"), local_path, '--recursive --exclude "*" --include "PER*"', sep = " "))
system(  paste('aws s3 cp', file.path(s3clinical, "ProcessedData", "JointData"), local_path, '--recursive --exclude "*" --include "curated*"', sep = " "))

#######################
# add patient level information, this will be redundant
  df <-  merge_table_files(file1 = file.path(local_path,"PER-FILE_clinical_cyto.txt"),
                           file2 = file.path(local_path,"PER-PATIENT_clinical.txt"),
                           id = c("Patient", "Study"))
  write.table(df, file.path(local_path,"tmp.txt"), row.names = F, col.names = T, sep = "\t", quote = F)

#######################
# CNV
  df <-  merge_table_files(file1 = file.path(local_path,"tmp.txt"),
                         file2 = file.path(local_path,"curated_CNV_ControlFreec.txt"),
                                           id = "File_Name")
  write.table(df, file.path(local_path,"tmp.txt"), row.names = F, col.names = T, sep = "\t", quote = F)

#######################
# Biallelic Inactivation Flags
  df <-  merge_table_files(file1 = file.path(local_path,"tmp.txt"),
                           file2 = file.path(local_path,"curated_BiallelicInactivation_Flag.txt"),
                           id = "File_Name")
  write.table(df, file.path(local_path,"tmp.txt"), row.names = F, col.names = T, sep = "\t", quote = F)
  
#######################
# SNV
df <-  merge_table_files(file1 = file.path(local_path,"tmp.txt"),
                         file2 = file.path(local_path,"curated_SNV_mutect2.txt"),
                         id = "File_Name")
write.table(df, file.path(local_path,"tmp.txt"), row.names = F, col.names = T, sep = "\t", quote = F)

# put back the all table
name <- "PER-FILE_ALL.txt"
system(  paste('aws s3 cp', file.path(local_path,"tmp.txt"), file.path(s3clinical, "ProcessedData", "Integrated", name), '--sse', sep = " "))
return_code <- system('echo $?', intern = T)

# as a failsafe to prevent reading older versions of source files remove the
#  cached version file if transfer was successful.
if(return_code == "0") system(paste0("rm -r ", local))

