# Dan Rozelle
# Sep 19, 2016
# rev 20161024 edit to directly acces s3 objects

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
study <- "DFCI"
d <- format(Sys.Date(), "%Y-%m-%d")

# locations
s3clinical <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData"
raw_inventory <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/Integrated/file_inventory.txt"
local      <- "/tmp/curation"
  if(!dir.exists(local)){dir.create(local)}

# get current original files
original <- file.path(s3clinical,study)
system(  paste('aws s3 cp', original, local, '--recursive', sep = " "))
system(  paste('aws s3 cp', raw_inventory, local, sep = " "))

################################################
# clean up the inventory entries and lookup values with df
name <- "file_inventory.txt"
inv <- read.delim(file.path(local,name), stringsAsFactors = F)
inv <- inv[inv$Study == "DFCI",]

  # nothing to add to the inventory sheet, but keep it in memory
  #  so we can add the filename to other tables and populate file-level better
lookup_by_samplename <- lookup.values("Sample_Name")

name <- paste("curated", study, name, sep = "_")
path <- file.path(local,name)
write.table(inv, path, row.names = F, col.names = T, sep = "\t", quote = F)


################################################
name <- "DFCI_WES_clinical_info_new.xlsx"
df <- readxl::read_excel(file.path(local,name), sheet = 1)
df<-df[complete.cases(df$Sample),]
df[["Study"]] <- study
# some of the values in Sample column are missing their suffix 
#  but they appear to all be early tumor samples ("a")
df[["Sample_Name"]] <- paste0(df$Patient, "a")

# move data that doesn't need to be cleaned to proper column names
df[,c("D_Age", "D_OS_FLAG", "D_OS",          "D_PFS_FLAG", "D_PFS")] <-
df[,c("Age",   "Death",     "Days_survived", "Relapse.1",  "Days_until_relapse")]

# encode and rename columns from yes/no to 1/0
df[,c( "CYTO_t(11;14)_FISH", "CYTO_t(4;14)_FISH", "CYTO_t(14;16)_FISH",
      "CYTO_del(1p)_FISH", "CYTO_1q_plus_FISH", "CYTO_del(12p)_FISH", "CYTO_del(13q)_FISH",
      "CYTO_del(14q)_FISH", "CYTO_del(16q)_FISH")] <- unlist(apply(df[,26:34], MARGIN = 2, function(x){
        as.numeric(dplyr::recode(tolower(x), yes="1", no="0" , .default = NA_character_))
      }))

# rename columns already encoded 1/0
df[,c("CYTO_Hyperdiploid_FISH","CYTO_del(17)_FISH")] <- df[,c("HYPER", "Del(17p)")]

# we don't currently have these fields, but they may come in handy
df["D_Diagnosis_Date"] <-format(lubridate::ymd_hms(df$Diagnosis), format = "%Y-%m-%d")
df["D_Relapse_Date"] <-format(df$Relapse, format = "%Y-%m-%d")
df["D_Last_Visit_Date"] <-format(df$Last_visit, format = "%Y-%m-%d")
df[['File_Name']] <- unlist(lapply(df$Sample_Name, lookup_by_samplename, dat = inv, field = "File_Name"))

name <- paste("curated", name, sep = "_")
name <- gsub("xlsx", "txt", name)
path <- file.path(local,name)
write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
rm(df)

### second tab of this workbook, even though many fields are overlapping, some patients are new
name <- "DFCI_WES_clinical_info_new.xlsx"
df <- readxl::read_excel(file.path(local,name), sheet = 2)
df[['Sample_Name']] <- df$Sample
df[['Patient']] <- gsub("(PD\\d+)[a-z]", "\\1", df$Sample)
df[["Study"]] <- study
df[['CYTO_Karyotype_FISH']] <- df$Karyotype
df[['CYTO_del(17p)_FISH']]  <- ifelse(grepl("Del(17p)", df$Karyotype, fixed = T),1,0)
df[['CYTO_del(12p)_FISH']]  <- ifelse(grepl("Del(12p)", df$Karyotype, fixed = T),1,0)
df[['CYTO_t(4;14)_FISH']]   <- ifelse(grepl("t(4;14)", df$Karyotype, fixed = T),1,0)
df[['CYTO_t(14;16)_FISH']]  <- ifelse(grepl("t(14;16)", df$Karyotype, fixed = T),1,0)
df[['CYTO_Hyperdiploid_FISH']] <- ifelse(grepl("Hyper", df$Karyotype, fixed = T),1,0)

df[['D_Age']] <- df$Age
df[,"D_OS_FLAG"] <- dplyr::recode(tolower(df$Death), yes="1", no="0" , .default = NA_character_)
df[['File_Name']] <- unlist(lapply(df$Sample_Name, lookup_by_samplename, dat = inv, field = "File_Name"))

name <- paste("curated_sheet2", name, sep = "_")
name <- gsub("xlsx", "txt", name)
path <- file.path(local,name)
write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
rm(df)

### third tab of this workbook, this has patient-level data for a few responses, misc.
name <- "DFCI_WES_clinical_info_new.xlsx"
df <- as.data.frame(  readxl::read_excel(file.path(local,name), sheet = 3, na = "n/a"))

df<-df[complete.cases(df$Sex),]
df[['Patient']] <- df$`Patient ID`
df[["Study"]] <- study
df[['D_Gender']] <- dplyr::recode(tolower(df$Sex), m="Male", f="Female" , .default = NA_character_)
df[['D_Age']] <- df$`Age at diagnosis`
df["D_Diagnosis_Date"] <-format(lubridate::dmy(df$`30/06/Diagnosis date`), format = "%Y-%m-%d")
df$`Karyotype at diagnosis`[df$`Karyotype at diagnosis` == "n/a"] <- ""
df[['CYTO_Karyotype_FISH']] <- df$`Karyotype at diagnosis`

df[['D_ISS']] <- dplyr::recode(df$ISS, III="3", II="2", I="1" , .default = NA_character_)
df[['D_Death_Date']] <- unlist(lapply(df[,grep("Date of death", names(df))+1], function(x){
  if( grepl("^2", x) ){return(NA)
  }else if( !is.na(as.numeric(x))  ){
    format(lubridate::ymd("1899-12-30") +  lubridate::days(as.numeric(x)), format = "%Y-%m-%d")
  }else {return(NA)}
}))

# lots of wonky characters in these fields, remove \n and \t before incorporating again
df <- df[,c("Patient", "Study", "D_Gender", "D_Age", "D_Diagnosis_Date", "D_ISS", "D_Death_Date")]

name <- paste("curated_sheet3", name, sep = "_")
name <- gsub("xlsx", "txt", name)
path <- file.path(local,name)
write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
rm(df)

################################################
## import and curate raw data tables individually into patient-level tables
name <- "DFCI_WES_Cyto.xlsx"
df <- readxl::read_excel(file.path(local,name), sheet = 1, na = "n/a")
df[['Patient']] <- gsub("(PD\\d+).", "\\1",df$Sample)
  df[['CYTO_del(17p)_FISH']]  <- ifelse(grepl("Del(17p)", df$Karyotype, fixed = T),1,0)
  df[['CYTO_del(12p)_FISH']]  <- ifelse(grepl("Del(12p)", df$Karyotype, fixed = T),1,0)
  df[['CYTO_t(4;14)_FISH']]   <- ifelse(grepl("t(4;14)", df$Karyotype, fixed = T),1,0)
  df[['CYTO_t(14;16)_FISH']]  <- ifelse(grepl("t(14;16)", df$Karyotype, fixed = T),1,0)
  df[['CYTO_Hyperdiploid_FISH']] <- ifelse(grepl("Hyper", df$Karyotype, fixed = T),1,0)

df2 <- readxl::read_excel(file.path(local,name), sheet = 2)
  # remove excluded patients
  df2 <- df2[is.na(df2$Exclude),]
  df2$Type <- gsub("Thuird", "Third", df2$Type)
  df2[["Disease_Status"]] <- ifelse(df2$Type == "Normal" | df2$Type == "Early", "ND", "R")
  df2[["Sample_Type_Flag"]] <- ifelse(df2$Type == "Normal", 0,1)
  df2[["Sample_Type"]] <- ifelse(df2$Type == "Normal", "Normal", "NotNormal")

df <- merge(df,df2, by = "Sample", all = T)
  df[['Sample_Name']] <- df$Sample
  df[['File_Name']] <- unlist(lapply(df$Sample_Name, lookup_by_samplename, dat = inv, field = "File_Name"))

name <- paste("curated", name, sep = "_")
name <- gsub("xlsx", "txt", name)
path <- file.path(local,name)
write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
rm(df, df2)

################################################
## import and curate raw data tables individually into patient-level tables
name <- "WES-Metadata.xlsx"
df <- readxl::read_excel(file.path(local,name), sheet = 1, na = "n/a")
  df[['Sample_Name']]     <- df$display_name
  df[['Sample_Type']]     <-  ifelse(grepl("CD138",df$cell_type), "NotNormal", "Normal")
  df[['Sample_Type_Flag']]<-  ifelse(grepl("CD138",df$cell_type), "1", "0")
  df[['Tissue_Type']]     <-  ifelse(grepl("bone",df$tissue), "BM", "PB")
  df[['Cell_Type']]       <-   ifelse(grepl("CD138",df$cell_type), "CD138pos", "PBMC")
  df[['File_Name']]       <- unlist(lapply(df$Sample_Name, lookup_by_samplename, dat = inv, field = "File_Name"))
  

name <- paste("curated", name, sep = "_")
name <- gsub("xlsx", "txt", name)
path <- file.path(local,name)
write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
rm(df)



################################################
name <- "Cytogenetic_DFCI_All-1.xlsx"
df <- readxl::read_excel(file.path(local,name), na = "n/a")
# remove blank and duplicated column names
df <- df[,unique( names(df)[!is.na(names(df))] )]
  df[['Patient']] <- df$Group
  df[["Study"]] <- study
  df[['Sample_Name']] <- df$Sample

  df[['CYTO_Hyperdiploid_FISH']] <- ifelse(grepl("YES", df$HYPER),1,0)
  df[['CYTO_del(17p)_FISH']] <- ifelse(grepl("YES", df$`Del(17p)`),1,0)
  df[['CYTO_del(13q)_FISH']] <- ifelse(grepl("YES", df$`Del(13)`),1,0)
  df[['CYTO_t(11;14)_FISH']] <- ifelse(grepl("YES", df$`t(11;14)`),1,0)
  df[['CYTO_t(4;14)_FISH']] <- ifelse(grepl("YES", df$`t(4;14)`),1,0)
  df[['CYTO_t(14;16)_FISH']] <- ifelse(grepl("YES", df$`t(14;16)`),1,0)
  df[['CYTO_del(12p)_FISH']] <- ifelse(grepl("YES", df$`del(12p)`),1,0)
  df[['CYTO_1q_plus_FISH']] <- ifelse(grepl("YES", df$`+(1q)`),1,0)
  df[['CYTO_del(1p)_FISH']] <- ifelse(grepl("YES", df$`-(1p)`),1,0)
  df[['CYTO_del(14q)_FISH']] <- ifelse(grepl("YES", df$`-(14q)`),1,0)
  df[['CYTO_del(16q)_FISH']] <- ifelse(grepl("YES", df$`-(16q)`),1,0)
  df[['Risk_group']] <- ifelse(grepl("High", df$`Risk group`),"High","Low")
  df[is.na(df$`Risk group`) | df$`Risk group` == "Uncertain risk", "Risk_group"] <- NA
  df[['File_Name']]       <- unlist(lapply(df$Sample_Name, lookup_by_samplename, dat = inv, field = "File_Name"))

name <- paste("curated", name, sep = "_")
name <- gsub("xlsx", "txt", name)
path <- file.path(local,name)
write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
rm(df, inv)

# put curated files back as ProcessedData on S3
processed <- file.path(s3clinical,"ProcessedData",study)
system(  paste('aws s3 cp', local, processed, '--recursive --exclude "*" --include "curated*" --sse', sep = " "))
return_code <- system('echo $?', intern = T)

# as a failsafe to prevent reading older versions of source files remove the 
#  cached version file if transfer was successful.
if(return_code == "0") system(paste0("rm -r ", local))
  
  