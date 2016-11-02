## drozelle@ranchobiosciences.com
## UAMS file curation

# vars
study <- "UAMS"
d <- format(Sys.Date(), "%Y-%m-%d")

# locations
s3clinical    <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData"
raw_inventory <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/Integrated/file_inventory.txt"
local         <- "/tmp/curation"
  if(!dir.exists(local)){dir.create(local)}

# get current original files
original <- file.path(s3clinical,"OriginalData",study)
system(  paste('aws s3 cp', original, local, '--recursive', sep = " "))
system(  paste('aws s3 cp', raw_inventory, local, sep = " "))

################################################
name <- "UAMS_UK_sample info.xlsx"
df <- readxl::read_excel(file.path(local,name), sheet = 1)
df[ df == "N/A" ] = NA
# chomp column names
names(df) <- gsub("^\\s+|\\s+$","",names(df))

  df[['Patient']] <- sprintf("UAMS_%04d", as.numeric(df$MyXI_Trial_ID))
  df[["Study"]] <- study
  df[['Sample_Name']] <- df$Sample_name
  df[['File_Name']] <- df$filename
  df[['Sample_Type']] <-  ifelse(grepl("Tumour",df$Type), "NotNormal", "Normal")
  df[['Sample_Type_Flag']] <-  ifelse(grepl("Tumour",df$Type), "1", "0")
  df[['D_Gender']] <-  ifelse(grepl("M",toupper(df$Gender) ), "Male", "Female")
  df[['Disease_Status']] <-  ifelse(grepl("NDMM",df$experiment), "ND", "MM")
  df[['Tissue_Type']]    <-  ifelse(grepl("BM",df$tissue), "BM", "PB")
  df[['Cell_Type']]      <-  ifelse(grepl("CD138",df$tissue), "CD138pos", "PBMC")
  
  df[['CYTO_t(11;14)_FISH']]           <-  ifelse( grepl("11", df$Translocation_consensus),1,0) 
  df[['CYTO_t(4;14)_FISH']]            <-  ifelse( grepl("4", df$Translocation_consensus),1,0) 
  df[['CYTO_t(6;14)_FISH']]            <-  ifelse( grepl("6", df$Translocation_consensus),1,0) 
  df[['CYTO_t(14;16)_FISH']]           <-  ifelse( grepl("16", df$Translocation_consensus),1,0) 
  df[['CYTO_t(14;20)_FISH']]           <-  ifelse( grepl("20", df$Translocation_consensus),1,0) 
  df[['CYTO_MYC_FISH']]  <-  ifelse( df$`MYC translocation` != "0" ,1,0) 

  name <- paste("curated_sheet1", name, sep = "_")
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

  name <- paste("curated_sheet2", name, sep = "_")
  name <- gsub("xlsx", "txt", name)
  path <- file.path(local,name)
  write.table(df2, path, row.names = F, col.names = T, sep = "\t", quote = F)


################################################
# clean up the inventory entries and lookup values with df
name <- "file_inventory.txt"
inv <- read.delim(file.path(local,name), stringsAsFactors = F)
inv <- inv[inv$Study == "UAMS",]

  inv[['File_Name_Actual']] <- gsub("^.*\\/_(.*?)$", "_\\1", inv$File_Path)
  inv[['Patient']] <- unlist(lapply(inv$File_Name, function(x){
    df[df$filename == x,"Patient"]
  }))
  inv[['Sample_Name']] <- unlist(lapply(inv$File_Name, function(x){
    df[df$filename == x,"Sample_Name"]
  }))
 
  name <- paste("curated", study, name, sep = "_")
  path <- file.path(local,name)
  write.table(inv, path, row.names = F, col.names = T, sep = "\t", quote = F)

rm(df, df2, inv)
#######



# put curated files back as ProcessedData on S3
processed <- file.path(s3clinical,"ProcessedData",study)
system(  paste('aws s3 cp', local, processed, '--recursive --exclude "*" --include "curated*" --sse', sep = " "))
return_code <- system('echo $?', intern = T)

# as a failsafe to prevent reading older versions of source files remove the 
#  cached version file if transfer was successful.
if(return_code == "0") system(paste0("rm -r ", local))

