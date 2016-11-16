

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
minimal_col_names <- names(df)

#######################
# CNV
print("CNV Merge........................................")

df <-  merge_table_files(file1 = file.path(local_path,"tmp.txt"),
                         file2 = file.path(local_path,"curated_CNV_ControlFreec.txt"),
                         id = "File_Name")
write.table(df, file.path(local_path,"tmp.txt"), row.names = F, col.names = T, sep = "\t", quote = F)

#######################
# Biallelic Inactivation Flags
print("BI Merge........................................")

df <-  merge_table_files(file1 = file.path(local_path,"tmp.txt"),
                         file2 = file.path(local_path,"curated_BiallelicInactivation_Flag.txt"),
                         id = "File_Name")
write.table(df, file.path(local_path,"tmp.txt"), row.names = F, col.names = T, sep = "\t", quote = F)

#######################
# SNV
print("SNV Merge........................................")

df <-  merge_table_files(file1 = file.path(local_path,"tmp.txt"),
                         file2 = file.path(local_path,"curated_SNV_mutect2.txt"),
                         id = "File_Name")
write.table(df, file.path(local_path,"tmp.txt"), row.names = F, col.names = T, sep = "\t", quote = F)

# put back the all table
name <- "PER-FILE_ALL.txt"
system(  paste('aws s3 cp', file.path(local_path,"tmp.txt"), file.path(s3clinical, "ProcessedData", "Integrated", name), '--sse', sep = " "))
return_code <- system('echo $?', intern = T)


#######################
# collapse_file_to_patient
#  this needs to reduce the PER-FILE organized table such that it contains a single *ND Tumor* row for each patient
print("Collapse to patient level...........................")

# df <- read.delim(file.path(local_path,"tmp.txt"), stringsAsFactors = F, as.is = T, check.names = F)
df <- df[df$Sample_Type_Flag == 1 & df$Disease_Status == "ND",]

df <- aggregate.data.frame(df, by = list(df$Patient), function(x){
  x <- unique(x)
  x <- x[!is.na(x)]
  # if(length(x) > 1){print(x)}
  paste(x, collapse = "; ")
})

df[,c("Group.1","File_Name" ,"File_Name_Actual","File_Path")] <- NULL


# write to local and S3
name <- "PER-PATIENT_nd_tumor_ALL.txt"
path <- file.path(local,name)
write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
system(  paste('aws s3 cp', path, file.path(s3clinical, "ProcessedData", "Integrated", name), '--sse', sep = " "))

# subset to a minimal clinical data table
df <- df[, minimal_col_names[minimal_col_names %in% names(df)]]
name <- "PER-PATIENT_nd_tumor_clinical.txt"
path <- file.path(local,name)
write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
system(  paste('aws s3 cp', path, file.path(s3clinical, "ProcessedData", "Integrated", name), '--sse', sep = " "))




return_code <- system('echo $?', intern = T)
if(return_code == "0"){ 
  system(paste0("rm -r ", local))
  rm(df)
}
