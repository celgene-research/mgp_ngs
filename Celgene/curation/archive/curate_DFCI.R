## drozelle@ranchobiosciences.com
## DFCI file curation

source("curation_scripts.R")
library(dplyr)

study <- "DFCI"
d <- format(Sys.Date(), "%Y-%m-%d")
s3    <- "s3://celgene.rnd.combio.mmgp.external"
local <- CleanLocalScratch()

# get current original files
system(  paste('aws s3 cp', 
               file.path(s3,"ClinicalData/OriginalData", study), 
               local, 
               '--recursive', sep = " "))
system(  paste('aws s3 cp', 
               file.path(s3, "ClinicalData/ProcessedData/Integrated", "file_inventory.txt"), 
               local, 
               sep = " "))

# inventory ---------------------------------------
# clean up the inventory entries and lookup values with df
name <- "file_inventory.txt"
inv <- read.delim(file.path(local,name), stringsAsFactors = F)
inv <- inv[inv$Study == "DFCI",]

  # split filename into cleaned filename (PD4283b) and 
  #  actual filename (HUMAN_37_pulldown_PD4283a.bam)
  inv[['File_Name_Actual']] <- inv$File_Name
  inv$File_Name <- inv$Sample_Name

  #  so we can add the filename to other tables and populate file-level better
  lookup_by_samplename <- lookup.values("Sample_Name")

name <- paste("curated", study, gsub("^DFCI_","", name), sep = "_")
path <- file.path(local,name)
write.table(inv, path, row.names = F, col.names = T, sep = "\t", quote = F)


# DFCI_WES_clinical_info_new.xlsx ---------------------------------------

name <- "DFCI_WES_clinical_info_new.xlsx"
df <- readxl::read_excel(file.path(local,name), sheet = 1)
  df<-df[complete.cases(df$Sample),]
  df[["Study"]] <- study
  # some of the values in Sample column are missing their suffix 
  #  but they appear to all be early tumor samples ("a")
  df[["Sample_Name"]] <- paste0(df$Patient, "a")
  df[['File_Name']] <- df$Sample_Name
  # move data that doesn't need to be cleaned to proper column names
  df[,c("D_Age", "D_OS_FLAG", "D_OS",          "D_PFS_FLAG", "D_PFS")] <-
  df[,c("Age",   "Death",     "Days_survived", "Relapse.1",  "Days_until_relapse")]
  
  # encode and rename columns from yes/no to 1/0
  # df[,c( "CYTO_t(11;14)_FISH", "CYTO_t(4;14)_FISH", "CYTO_t(14;16)_FISH",
  #       "CYTO_del(1p)_FISH", "CYTO_1qplus_FISH", "CYTO_del(12p)_FISH", "CYTO_del(13q)_FISH",
  #       "CYTO_del(14q)_FISH", "CYTO_del(16q)_FISH")] <- unlist(apply(df[,26:34], MARGIN = 2, function(x){
  #         as.numeric(dplyr::recode(tolower(x), yes="1", no="0" , .default = NA_character_))
  #       }))
  
  # rename columns already encoded 1/0
  # df[,c("CYTO_Hyperdiploid_FISH","CYTO_del(17)_FISH")] <- df[,c("HYPER", "Del(17p)")]
  
  # TODO: we don't currently have these fields, but they may come in handy
  df["D_Diagnosis_Date"] <-format(lubridate::ymd_hms(df$Diagnosis), format = "%Y-%m-%d")
  df["D_Relapse_Date"] <-format(df$Relapse, format = "%Y-%m-%d")
  df["D_Last_Visit_Date"] <-format(df$Last_visit, format = "%Y-%m-%d")
  df[['File_Name_Actual']] <- unlist(lapply(df$Sample_Name, lookup_by_samplename, dat = inv, field = "File_Name_Actual"))
  
  name <- paste("curated", study, gsub("^DFCI_","", name), sep = "_")
  name <- gsub("xlsx", "txt", name)
  path <- file.path(local,name)
  write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
  rm(df)

### second tab of this workbook, even though many fields are overlapping, some patients are new
name <- "DFCI_WES_clinical_info_new.xlsx"
df <- readxl::read_excel(file.path(local,name), sheet = 2)
  df[['Sample_Name']] <- df$Sample
  df[['File_Name']] <- df$Sample_Name
  
  df[['Patient']] <- gsub("(PD\\d+)[a-z]", "\\1", df$Sample)
  df[["Study"]] <- study
  df[['CYTO_Karyotype_FISH']] <- df$Karyotype

  df[['D_Age']] <- df$Age
  df[,"D_OS_FLAG"] <- dplyr::recode(tolower(df$Death), yes="1", no="0" , .default = NA_character_)
  df[['File_Name_Actual']] <- unlist(lapply(df$Sample_Name, lookup_by_samplename, dat = inv, field = "File_Name_Actual"))
  
  name <- gsub(".xlsx", "", name)
  name <- paste("curated", study, gsub("^DFCI_","", name), "s2", "txt",sep = "_")
  name <- gsub("_txt", "\\.txt", name)
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

    df[df$`Patient ID`=="PD4284", "Disease response"] <- "CR"
    response_dict <- list(CR="Complete Response",
                          VGPR="Very Good Partial Response",
                          PR="Partial Response")
    response_encoding <- list(CR="1",
                              VGPR="3",
                              PR="4")
  
    df[['D_Best_Response']] <- unlist(lapply(df$`Disease response`, function(x){
      if(!is.na(x) & x %in% names(response_dict) ){response_dict[x]
        }else {NA}
    }))
      
    df[['D_Best_Response_Code']] <- unlist(lapply(df$`Disease response`, function(x){
       if(!is.na(x) & x %in% names(response_dict) ){response_encoding[x]
      }else {NA}
    }))
  df[['D_ISS']] <- dplyr::recode(df$ISS, III="3", II="2", I="1" , .default = NA_character_)
  df[['D_Death_Date']] <- unlist(lapply(df[,grep("Date of death", names(df))+1], function(x){
    if( grepl("^2", x) ){return(NA)
    }else if( !is.na(as.numeric(x))  ){
      format(lubridate::ymd("1899-12-30") +  lubridate::days(as.numeric(x)), format = "%Y-%m-%d")
    }else {return(NA)}
  }))
  
  # lots of wonky characters in these fields, remove \n and \t before incorporating again
  df <- df[,c("Patient", "Study", "D_Gender", "D_Age", "D_Diagnosis_Date", "D_ISS", "D_Death_Date")]

  name <- gsub(".xlsx", "", name)
  name <- paste("curated", study, gsub("^DFCI_","", name), "s3", "txt",sep = "_")
  name <- gsub("_txt", "\\.txt", name)
  path <- file.path(local,name)
  write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
  rm(df)

  # DFCI_WES_Cyto.xlsx ---------------------------------------
  
## import and curate raw data tables individually into patient-level tables
name <- "DFCI_WES_Cyto.xlsx"
df <- readxl::read_excel(file.path(local,name), sheet = 1, na = "n/a")
df[['Patient']] <- gsub("(PD\\d+).", "\\1",df$Sample)

df2 <- readxl::read_excel(file.path(local,name), sheet = 2)
  # remove excluded patients
  df2 <- df2[is.na(df2$Exclude),]
  df2$Type <- gsub("Thuird", "Third", df2$Type)
  df2[["Disease_Status"]] <- ifelse(df2$Type == "Normal" | df2$Type == "Early"| df2$Type == "Tumour", "ND", "R")
  df2[["Sample_Type_Flag"]] <- ifelse(df2$Type == "Normal", 0,1)
  df2[["Sample_Type"]] <- ifelse(df2$Type == "Normal", "Normal", "NotNormal")

df <- merge(df,df2, by = "Sample", all = T)
  df[['Patient']] <- gsub("(PD\\d+).$","\\1", df$Sample)
  df[['Sample_Name']] <- df$Sample
  df[['File_Name']] <- df$Sample_Name
  df[['File_Name_Actual']] <- unlist(lapply(df$Sample_Name, lookup_by_samplename, dat = inv, field = "File_Name_Actual"))
  
  name <- paste("curated", study, gsub("^DFCI_","", name), sep = "_")
  name <- gsub("xlsx", "txt", name)
  path <- file.path(local,name)
  write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
  rm(df, df2)

  # WES-Metadata.xlsx ---------------------------------------
  
## import and curate raw data tables individually into patient-level tables
name <- "WES-Metadata.xlsx"
df <- readxl::read_excel(file.path(local,name), sheet = 1, na = "n/a")
  df[['Sample_Name']]     <- df$display_name
  df[['Sample_Type']]     <-  ifelse(grepl("CD138",df$cell_type), "NotNormal", "Normal")
  df[['Sample_Type_Flag']]<-  ifelse(grepl("CD138",df$cell_type), "1", "0")
  df[['Tissue_Type']]     <-  ifelse(grepl("bone",df$tissue), "BM", "PB")
  df[['Cell_Type']]       <-   ifelse(grepl("CD138",df$cell_type), "CD138pos", "PBMC")
  df[['File_Name']]       <- df$Sample_Name
  df[['File_Name_Actual']]<- unlist(lapply(df$Sample_Name, lookup_by_samplename, dat = inv, field = "File_Name_Actual"))
  df[['Patient']]         <- gsub("(PD\\d+).$","\\1",df$Sample_Name)

  name <- paste("curated", study, gsub("^DFCI_","", name), sep = "_")
  name <- gsub("xlsx", "txt", name)
path <- file.path(local,name)
write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
rm(df)



# Cytogenetic_DFCI_All-1.xlsx ---------------------------------------

name <- "Cytogenetic_DFCI_All-1.xlsx"
df <- readxl::read_excel(file.path(local,name), na = "n/a")
# remove blank and duplicated column names
df <- df[,unique( names(df)[!is.na(names(df))] )]
  df[['Patient']] <- df$Group
  df[["Study"]] <- study
  df[['Sample_Name']] <- df$Sample
  df[['File_Name']] <- df$Sample_Name
  
  df[['Risk_group']] <- ifelse(grepl("High", df$`Risk group`),"High","Low")
  df[is.na(df$`Risk group`) | df$`Risk group` == "Uncertain risk", "Risk_group"] <- NA
  df[['File_Name_Actual']]<- unlist(lapply(df$Sample_Name, lookup_by_samplename, dat = inv, field = "File_Name_Actual"))
  
  name <- paste("curated", study, gsub("^DFCI_","", name), sep = "_")
  name <- gsub("xlsx", "txt", name)
  path <- file.path(local,name)
  write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
  rm(df)
  
  # DFCI_published_cyto_calls.txt ---------------------------------------
  
name <- "DFCI_published_cyto_calls.txt"
df <- read.delim(file.path(local,name), stringsAsFactors = F)
  df[["Study"]] <- study
  df[['Sample_Name']] <- df$Sample
  df[['File_Name']] <- df$Sample

df2 <- df[,4:14]
  df2[df2 == "YES"]  <- 1
  df2[df2 == "NO"]   <- 0
  df2[df2 == "Subclonal"]   <- 2
  df2[df2 == "Sucbclonal"]   <- 2 #typo in orignal
  df2[df2 == "CN>LOH" ]   <- NA
  df2[df2 == "N/A" ]   <- NA
  
  names(df2) <- c("CYTO_Hyperdiploid_FISH","CYTO_t(11;14)_FISH","CYTO_t(4;14)_FISH",
                  "CYTO_t(14;16)_FISH", "CYTO_del(1p)_FISH", "CYTO_1qplus_FISH",
                  "CYTO_del(12p)_FISH", "CYTO_del(13q)_FISH", "CYTO_del(14q)_FISH",
                  "CYTO_del(16q)_FISH", "CYTO_del(17;17p)_FISH") 
  df <- cbind(df,df2)
  lookup_by_samplename <- lookup.values("Sample_Name")
  df[['File_Name_Actual']]<- 
    unlist(lapply(df$Sample_Name, lookup_by_samplename, dat = inv, field = "File_Name_Actual"))
  
  name <- paste("curated", study, gsub("^DFCI_","", name), sep = "_")
  name <- gsub("xlsx", "txt", name)
  path <- file.path(local,name)
  write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)

  
rm(df, df2, inv)


# DFCI_RNASeq_Clinical.xls ---------------------------------------

name.map <- "2017-01-18_DFCI_RNASeq_Samples.xlsx"

# we're using the R1 filename as the File_Name and appending R1; R2 for File_Name_Actual
map      <- readxl::read_excel(file.path(local,name.map)) %>%
  mutate(Sample_Name = gsub("^(.*)_[ATCG]+_.*", "\\1", File_R1 )) %>%
  mutate(File_Name_Actual = paste(File_R1, File_R2, sep = "; ")) %>%
  mutate(File_Name = gsub(".*(NM[^ ]*R1[^ ]*)\\.fastq.*", "\\1", File_Name_Actual)) %>%
  rename(Patient = SampleID) %>%
  select(-c(File_R1, File_R2)) %>%
  arrange(Patient) 
  

name <- "2017-02-01_DFCI_RNASeq_Clinical.xls"
raw <- read.delim(file.path(local,name), stringsAsFactors = F)

df <- with(raw,
    data.frame(
   Patient            = SampleID 
  ,D_Age         = as.numeric(Age.at.diagnosis)
  ,D_Gender      = recode(Sex, "1"="Male", "2"="Female")
  ,D_ISS         = as.numeric(ISS)
  ,D_OS          = DiagToDeath
  ,D_OS_FLAG     = Death
  ,D_PFS         = DiagToRelapse
  ,D_PFS_FLAG    = Relapse
  
  ,`CYTO_t(4;14)_FISH`  = as.numeric(gsub("9", NA, t_4_14) )
  # ,`CYTO_t(11;14)_FISH` = t_11_14
  ,`CYTO_t(14;16)_FISH` = as.numeric(gsub("9", NA, t_14_16) )
  ,`CYTO_1qplus_FISH`   = Gain_1q
  ,`CYTO_del(1p)_FISH` = Del1p
  # Del1p22
  ,`CYTO_del(1p32)_FISH`= Del1p32
  # Del8p  #MYC?
  # del13_per
  # del17p
  # Trisomie5
  # Trisomie9
  # Trisomie15
  # Monosomie_14
  # del14q
  ,`CYTO_del(16q)_FISH` = del16q
  # del20p
  # del22q
  # Purity
  
  ,stringsAsFactors = F
))

df <- full_join(df, map, by = "Patient") %>%   arrange(is.na(D_Age), Patient)
df[['Study']]            <-  "DFCI.2009"
df[['Sample_Type_Flag']]  <- "1"
df[['Sample_Type']]       <- "NotNormal"
df[['Sequencing_Type']]   <- "RNA-Seq"
df[['Excluded_Flag']]     <- NA
df[['Excluded_Specify']]  <- NA
df[['Disease_Status']]    <- "ND"
df[['Disease_Type']]      <- "MM"
df[['Tissue_Type']]       <- NA
df[['Cell_Type']]         <- NA

# save a table of samples without clinical data
missing.clinical.data <- subset(df, is.na(D_Age)) %>% 
  tidyr::separate(File_Name_Actual, into = c("File_R1", "File_R2"), sep = "; " ) %>%
  select(Patient, File_R1, File_R2)

write.table(missing.clinical.data, "~/thindrives/mgp/DFCI_missing_clinical_data.txt",
            sep = "\t", row.names = F)

name <- paste("curated", study, gsub("^DFCI_","", name), sep = "_")
name <- gsub("xls", "txt", name)
path <- file.path(local,name)
write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
rm(map)

# RNA-Seq inventory ---------------------------------------
name <- "file_inventory.txt"
  inv <- read.delim(file.path(local,name), stringsAsFactors = F)
  inv <- inv[inv$Study == "DFCI.2009",]

  # everything else should already be capture by table above,
  #  but the inventory is the only palce to get File_Path and File_Name_Actual
  inv <- inv %>%
    mutate(File_Name_Actual = File_Name,
           File_Name = gsub("(.*)\\.fastq\\.gz", "\\1", File_Name),
           File_Name = gsub("R2", "R1", File_Name),
           read = gsub(".*(R\\d).*","\\1",  File_Name_Actual) ) %>% 
    group_by(File_Name) %>%
    summarise(File_Name_Actual = paste(File_Name_Actual, collapse = "; "),
              File_Path = paste(File_Path, collapse = "; "))
  
  name <- "curated_DFCI2009_file_inventory.txt"
  path <- file.path(local,name)
  write.table(inv, path, row.names = F, col.names = T, sep = "\t", quote = F)

# to ProcessedData S3 --------------------------------
system(  paste('aws s3 cp',
               local,
               file.path(s3,"ClinicalData/ProcessedData", study),
               '--recursive --exclude "*" --include ',paste0("curated_", study, "*"),
               ' --sse', sep = " "))

