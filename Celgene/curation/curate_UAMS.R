
# Approach to MGP curation follows the following process:
#  1.) <data.txt> is curated to <curated_data.txt> and moved to /ProcessedData/Study/
#       In these curated files new columns are added using the format specified in 
#       the dictionary file and values are coerced into ontologically accurate values. 
#       This file is not filtered or organized per-se, but provides a nice reference 
#       for where curated value columns are derived.
#  2.) mgp_clinical_aggregated.R is used to leverage our append_df() function, which 
#       loads each table of new data into the main integrated table. Before saving,
#       this script also enforces ontology rules to ensure all columns adhere to 
#       type and factor rules detailed in the <mgp_dictionary.xlsx>.
#  3.) summary scripts are used to generate specific counts and aggregated summary 
#       values.

# vars
study <- "UAMS"
d <- format(Sys.Date(), "%Y-%m-%d")

# locations
s3clinical    <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData"
raw_inventory <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/Integrated/file_inventory.txt"
local         <- "/tmp/curation"
  if(!dir.exists(local)){dir.create(local)}

# get current original files
original <- file.path(s3clinical,study)
system(  paste('aws s3 cp', original, local, '--recursive', sep = " "))
system(  paste('aws s3 cp', raw_inventory, local, sep = " "))

################################################
name <- "UAMS_UK_sample info.xlsx"
df <- readxl::read_excel(file.path(local,name), na = "n/a", sheet = 1)

# chomp column names
names(df) <- gsub("^\\s+|\\s+$","",names(df))

df[['Patient']] <- sprintf("UAMS_%04d", as.numeric(df$MyXI_Trial_ID))
df[["Study"]] <- study
df[['Sample_Name']] <- df$Sample_name
df[['File_Name']] <- df$filename
df[['Sample_Type']] <-  ifelse(grepl("Tumour",df$Type), "NotNormal", "Normal")
df[['Sample_Type_Flag']] <-  ifelse(grepl("Tumour",df$Type), "1", "0")
df[['D_Gender']] <-  ifelse(grepl("M",df$Gender ), "Male", "Female")
df[['Disease_Status']] <-  ifelse(grepl("NDMM",df$experiment), "ND", "MM")
df[['Tissue_Type']]    <-  ifelse(grepl("BM",df$tissue), "BM", "PB")
df[['Cell_Type']]      <-  ifelse(grepl("CD138",df$tissue), "CD138pos", "PBMC")
# TODO: still need to parse translocations

  name <- paste("curated_sheet1", d, name, sep = "_")
  name <- gsub("xlsx", "txt", name)
  path <- file.path(local,name)
  write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)

## Sheet 2
name <- "UAMS_UK_sample info.xlsx"
df2 <- readxl::read_excel(file.path(local,name), sheet = 2)

df2[['Patient']] <- sprintf("UAMS_%04d", as.numeric(df2$`Trial number`))
df2[["Study"]] <- study
df2[df2$ISS != "Missing Data",'D_ISS'] <- unlist(list(`Stage I` = 1, `Stage II` = 2, `Stage III` = 3)[df2$ISS])

df2[["D_OS"]]      <- round(df2$OS_months*30.42, digits = 0)
df2[['D_OS_FLAG']] <- df2$OS_status
df2[["D_PFS"]]     <- round(df2$PFS_months*30.42, digits = 0)
df2[['D_PFS_FLAG']]<- df2$PFS_status
df2[['D_Age']]<- df2$Age

  name <- paste("curated_sheet2", d, name, sep = "_")
  name <- gsub("xlsx", "txt", name)
  path <- file.path(local,name)
  write.table(df2, path, row.names = F, col.names = T, sep = "\t", quote = F)


################################################
# clean up the inventory entries and lookup values with df
name <- "file_inventory.txt"
inv <- read.delim(file.path(local,name), stringsAsFactors = F)
inv <- inv[inv$Study == "UAMS",]

inv[['Patient']] <- unlist(lapply(inv$File_Name, function(x){
  df[df$filename == x,"Patient"]
}))
inv[['Sample_Name']] <- unlist(lapply(inv$File_Name, function(x){
  df[df$filename == x,"Sample_Name"]
}))
 
  name <- paste("curated", d, name, sep = "_")
  path <- file.path(local,name)
  write.table(df2, path, row.names = F, col.names = T, sep = "\t", quote = F)

rm(df, df2, inv)
#######



# put curated files back as ProcessedData on S3
processed <- file.path(s3clinical,"ProcessedData",study)
system(  paste('aws s3 cp', local, processed, '--recursive --exclude "*" --include "curated*" --sse', sep = " "))
return_code <- system('echo $?', intern = T)

# as a failsafe to prevent reading older versions of source files remove the 
#  cached version file if transfer was successful.
if(return_code == "0") system(paste0("rm -r ", local))




