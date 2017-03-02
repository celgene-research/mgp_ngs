## drozelle@ranchobiosciencs.com
##
## 2017-02-20 revised to incorporate second iteration of molecular calls
library(data.table)
source("curation_scripts.R")
local <- CleanLocalScratch()

# used to get examples of existing data formats
per.file <- GetS3Table(file.path(s3,"ClinicalData/ProcessedData/Integrated",
                              "per.file.clinical.txt"))
# per.file.examples <- per.file %>% 
#   group_by(Study) %>%
#   sample_n(2) %>%
#   ungroup() %>%
#   select(Patient, Sample_Name, File_Name, File_Name_Actual, File_Path)



# CNV --------------------------------------------------------------------
## CNV from Cody (TCAshby@uams.edu)
print("CNV Curation........................................")

# I applied a three step criteria for filtering:
# 1.) t-test on regions of relative chromosomal stability (chromosome 2 and 10). 
#      If neither of them are normal (CN=2) than the sample fails.
# 2.) Median of the standard deviations of the data points across all chromosomes. 
#      If higher than 0.3, than the sample fails.
# 3.) If there are more than 600 CN segments, then the sample fails.

  # import call file and rename columns for integrated dictionary
  cnv <- GetS3Table(file.path(s3,"ClinicalData/OriginalData/Joint",
                              "2017-02-21_cody_copy_number_table_all.txt"))  
  names(cnv) <- paste("CNV", names(cnv), "ControlFreec", sep = "_")
  cnv <- cnv %>% rename(File_Name = CNV_X_ControlFreec)
  
  # remove files that didn't pass Cody's filter (0=Fail; 1=Pass)
  pass.filter <- GetS3Table(file.path(s3,"ClinicalData/OriginalData/Joint",
                                      "2017-02-21_cody_cnv_samples_passfilter.txt")) 
  # 267 failed; 1174 passed
  # pass.filter %>% group_by(Pass) %>% count()
  
  removed <- cnv[cnv$File_Name %in% pass.filter[pass.filter$Pass == "0", "File_Name"],]
  PutS3Table(removed, file.path(s3,"ClinicalData/ProcessedData/JointData",
                       "2017-02-21_cnvs_NOT_passing_codys_filter.txt")) 
  
  # edit filenames to match File_Name patterns in per-file table
  # DFCI == _EGAR00001321522_EGAS00001001147_B01MYABXX_1_57 => B01MYABXX_1_57
  # UAME == HUMAN_37_pulldown_PD4283a                       => PD4283a
  # MMRF == MMRF_1016_1_BM_CD138pos_T1_KAWGL_L02955         => same
  cnv$File_Name <- case_when(
    grepl("^_E", cnv$File_Name) ~ gsub("^_E.*?_([^E].*)$" , "\\1", cnv$File_Name),
    grepl("^HU", cnv$File_Name) ~ gsub("HUMAN_37_pulldown_" , "", cnv$File_Name),
                           TRUE ~ cnv$File_Name )
  
  # confirm that all valid filenames are matched
  # cnv$File_Name[!(cnv$File_Name %in% per.file$File_Name)]
  
  PutS3Table(cnv, file.path(s3,"ClinicalData/ProcessedData/JointData",
                                "curated_cnv_ControlFreec_2017-02-21.txt")) 
  
# # compile a cnv dictionary
# cnv_locations <- data.frame(t(readxl::read_excel(file.path(local,"copy_number_table.xlsx"),
#                           sheet = 1, col_names = F )[1:2,]))
# # trim top two lines
# cnv_locations <- cnv_locations[3:nrow(cnv_locations),]
# 
# cnv_locations['names'] <-   paste("CNV",cnv_locations$X2,"ControlFreec", sep = "_")
# cnv_locations['key_val'] <- '0"=homozygous deletion"; 1="loss"; 2="normal"; -2="copy number neutral loss of heterozygosity"; 3="gain"; 4="amplification"'
# cnv_locations['description'] <- paste("chromosome_hg19 start position", cnv_locations$X1, sep = " ")
# 
# cnv_locations[,c("X1", "X2")] <- NULL
# 
# # write to local
# path <- file.path(local,"cnv_dictionary.txt")
# write.table(cnv_locations, path, row.names = F, col.names = T, sep = "\t", quote = F)


# Trsl --------------------------------------------------------------------
## Translocations using MANTA from Brian (BWalker2@uams.edu)
print("Translocation Curation........................................")

# df <- GetS3Table(file.path(s3,"ClinicalData/OriginalData/Joint",
#                              "2017-01-11_complete_translocation_table_pass3_FINAL.xlsx"))  

df <- toolboxR::AutoRead("../../../data/OriginalData/Joint/2017-03-02_complete_translocation_table_pass4.xlsx")
  
# Split table into sequencing types, filter to remove NA rows (everything should now be either 0/1)
wes <- df %>% 
  select(starts_with("WES"), Translocation_Summary, Dataset) %>% 
  rename(id = WES_prep_id) %>%
  filter( id != "NA") %>%
  gather( key = field, value = Value, ends_with("MMSET"):ends_with("MAFB") ) %>%
  separate( field, c("Sequencing_Type", "Result"), "_")

wgs <- df %>% 
  select(starts_with("WGS"), Translocation_Summary, Dataset) %>% 
  rename(id = WGS_prep_id) %>%
  filter( id != "NA") %>%
  gather( key = field, value = Value, ends_with("MMSET"):ends_with("MAFB") ) %>%
  separate( field, c("Sequencing_Type", "Result"), "_")

rna <- df %>% 
  select(starts_with("RNA"), Translocation_Summary, Dataset) %>% 
  rename(id = RNA_prep_id) %>%
  filter( id != "NA") %>%
  gather( key = field, value = Value, ends_with("MMSET"):ends_with("MAFB") ) %>%
  separate( field, c("Sequencing_Type", "Result"), "_")

df <- rbind(wes, wgs, rna) %>%
  # code any field with a value as ="1", all others "0"
  mutate( Value = ifelse(is.na(Value),0,1) ) %>%
  # translate etiological groups back to actual MANTA translocation column
  mutate( Result = recode(Result,
                          MMSET = "CYTO_t(4;14)_MANTA",
                          CCND3 = "CYTO_t(6;14)_MANTA",
                          CCND1 = "CYTO_t(11;14)_MANTA",
                          MAF   = "CYTO_t(14;16)_MANTA",
                          MAFA  = "CYTO_t(8;14)_MANTA",
                          MAFB  = "CYTO_t(14;20)_MANTA")) %>%
  # fix provided sample names to match harmonized File_Name field
  mutate(File_Name = case_when(
    .$Dataset == "UAMS" ~ gsub("_.*?_([^E].*)$", "\\1", .$id),
    .$Dataset == "DFCI" ~ gsub(".*_(.*)$", "\\1", .$id),
    .$Dataset == "MMRF" ~ .$id ))


df <-   df %>%
  # TODO: temporary fix to allow duplicated file names
  select(File_Name, Result, Value) %>%
  group_by(File_Name, Result) %>%
  summarise(Value = Simplify(Value)) %>%
  
  # spread back to integrated table layout
  spread(key = Result, value = Value)

PutS3Table(out, file.path(s3,"ClinicalData/ProcessedData/JointData",
                          "curated_translocation_calls_2017-01-11.txt"))


# SNV --------------------------------------------------------------------
## SNV from Chris (CPWardell@uams.edu)
print("SNV Curation........................................")

# were using a data.table instead of a data.frame due to the large size

f <- "20170213.snvsindels.filtered.metadata.ndmmonly.slim.txt"
system(paste("aws s3 cp",
      file.path(s3,"ClinicalData/OriginalData/Joint",f),
      local,
      "", sep = " "))
snv <- data.table::fread(file.path(local, f))

# select filename and gene name columns, add a "call" column as binary indicator 
#  (Does this gene have any mutations? 0=No; 1=Yes)
DT <- snv[,.(File_Name = tumorname, Hugo_Symbol), .(call = rep(1, length(Hugo_Symbol))) ]
# spread table long to wide so we have a file ~ gene binary matrix
DT <- dcast(DT, File_Name ~ Hugo_Symbol, value.var = "call", fun = function(x){ ifelse(length(x)>=1,1,0) })

# rename columns, remove extraneous underscore characters from gene names
names(DT)    <- gsub("_+", "\\.", names(DT))
names(DT)    <- paste("SNV", names(DT), "BinaryConsensus", sep = "_")
names(DT)[1] <- "File_Name"

# clean File_Name as for CNVs above
DT$File_Name <- gsub("^_E.*?_([^E].*)$", "\\1", DT$File_Name)
DT$File_Name <- gsub("HUMAN_37_pulldown_", "", DT$File_Name)
  
# all(DT$File_Name %in% per.file$File_Name)
# TRUE

PutS3Table(DT, file.path(s3,"ClinicalData/ProcessedData/JointData/",
                         "curated_SNV_BinaryConsensus_2017-02-13.txt"))


# BI --------------------------------------------------------------------
## Biallelic Inactivation calls from Cody (TCAshby@uams.edu)
print("Biallelic Inactivation Curation........................................")

prefix    <- "BI"
technique <- "BiallelicInactivation"
software  <- "Flag"

# copy original tables to local
name    <- 'biallelic_table_cody_2016-11-09.xlsx'  
system(paste('aws s3 cp', file.path(s3clinical, "OriginalData", 'Joint', name), file.path(local, name), sep = " "))

bi <- readxl::read_excel(file.path(local,name),
                         sheet = 1)

# I'm attaching a matrix that contains regions of 'biallelic inactivation'. It's a similar format to the copy number table with genes across the top and patients as the rows. 
# 
# 0 = no inactivation
# 1 = mutation + deletion or homozygous deletion
# 
# Keep in mind the following known caveats:
# 1)       We're not checking the variant allele frequencies so there are potentially some false positives. We're only reporting mutation + deletion or homozygous deletion.
# 2)       We're not checking for regions where there are 2 or more mutations in the same gene which could potentially be another route of biallelic inactivation.
# 3)       We're only reporting samples that passed the copy number filter.
# 4)       We're only checking the genes that were listed in the copy number table.

# remove summary columns/rows
bi <- bi[bi[[1]] != "TOTALS",]
bi$gene <- NULL

#rename columns as BI_Gene_Software
n <- names(bi)
n <- paste(prefix,n,software, sep = "_")
n[1] <- "File_Name"
names(bi) <- n

# edit filenames to match integrated table and check 
bi$File_Name <- gsub("^_E.*_([bcdBCD])", "\\1", bi$File_Name)
# bi$File_Name[!(bi$File_Name %in% per.file$File_Name)]
# all(bi$File_Name %in% per.file$File_Name)
# TRUE

# write to local and S3
name <- paste0("curated_",technique,"_",software,".txt")
path     <- file.path(local,name)
write.table(bi, path, row.names = F, col.names = T, sep = "\t", quote = F)

system(  paste('aws s3 cp', file.path(local, name), file.path(s3clinical, "ProcessedData", "JointData", name), '--sse', sep = " "))

## now make a sparse dictionary
dict <- data.frame(
  names       = names(bi)[2:length(bi)],
  key_val     = '0="no inactivation"; 1="mutation + deletion or homozygous deletion"',
  description = paste("Was biallelic inactivation observed for", 
                      gsub("^.*_(.*)_.*$","\\1", names(bi)[2:length(bi)]), sep = " "),
  stringsAsFactors = F )

# write to local
name <- paste0(technique,"_", "dictionary",".txt")
path     <- file.path(local,name)
write.table(dict, path, row.names = F, col.names = T, sep = "\t", quote = F)
system(  paste('aws s3 cp', file.path(local, name), file.path(s3clinical, "ProcessedData", "Integrated", name), '--sse', sep = " "))
return_code <- system('echo $?', intern = T)
# if(return_code == "0") system(paste0("rm -r ", local))
# rm(list = ls())


