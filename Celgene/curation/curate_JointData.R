## drozelle@ranchobiosciencs.com
##
## 2017-02-20 revised to incorporate second iteration of molecular calls

source("curation_scripts.R")
local <- CleanLocalScratch()

# used to get examples of existing data formats
# per.file <- GetS3Table(file.path(s3,"ClinicalData/ProcessedData/Integrated",
#                               "per.file.clinical.txt"))  
# per.file.examples <- per.file %>% 
#   group_by(Study) %>%
#   sample_n(2) %>%
#   ungroup() %>%
#   select(Patient, Sample_Name, File_Name, File_Name_Actual, File_Path)


                    
# CNV --------------------------------------------------------------------
## CNV from Cody (TCAshby@uams.edu)
print("CNV Curation........................................")

  # I applied a three step criteria for filtering:
  # 1.) t-test on regions of relative chromosomal stability (chromosome 2 and 10). If neither of them are normal (CN=2) than the sample fails.
  # 2.) Median of the standard deviations of the data points across all chromosomes. If higher than 0.3, than the sample fails.
  # 3.) If there are more than 600 CN segments, then the sample fails.
  
  # cnv <- GetS3Table(file.path(s3,"ClinicalData/OriginalData/Joint",
  #                             "2017-02-21_cody_copy_number_table_all.txt"))  
  # 
  # 
  # cnv <- cnv %>% rename(File_Name = X)
  # 
  # head(setdiff(cnv$File_Name, per.file$File_Name_Actual))
  # grep("4283", per.file$File_Name, value = T)
  # 
  # cnv <- cnv[cnv$passed_filter == 1,]
  # cnv$passed_filter <- NULL
  # 
  # n <- names(cnv)
  # n <- paste("CNV",n,"ControlFreec", sep = "_")
  # n[1] <- "File_Name"
  # names(cnv) <- n
  # 
  # # edit filenames to match integrated table and check 
  # cnv$File_Name <- gsub("HUMAN_37_pulldown_", "", cnv$File_Name)
  # cnv$File_Name <- gsub("^_E.*_([bcdBCD])", "\\1", cnv$File_Name)
  # #all(cnv$File_Name %in% per.file$File_Name)
  # 
  # # write to local
  # path <- file.path(local,"curated_CNV_ControlFreec.txt")
  # write.table(cnv, path, row.names = F, col.names = T, sep = "\t", quote = F)
  # 
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
  # 
  # name <- "curated_CNV_ControlFreec.txt"
  # system(  paste('aws s3 cp', file.path(local, name), file.path(s3clinical, "ProcessedData", "JointData", name), '--sse', sep = " "))
  # 
  # name <- "cnv_dictionary.txt"
  # system(  paste('aws s3 cp', file.path(local, name), file.path(s3clinical, "ProcessedData", "Integrated", name), '--sse', sep = " "))
  # return_code <- system('echo $?', intern = T)
  # if(return_code == "0") system(paste0("rm -r ", local))
  # rm(cnv, cnv_locations)

# Trsl --------------------------------------------------------------------
## Translocations using MANTA from Brian (BWalker2@uams.edu)
print("Translocation Curation........................................")
  
  trsl <- GetS3Table(file.path(s3,"ClinicalData/OriginalData/Joint",
                   "2017-01-11_complete_translocation_table_pass3_FINAL.xlsx"))  
  
  # Split table into sequencing types, filter to remove NA rows (everything should now be either 0/1)
  
  wes <- trsl %>% 
    select(starts_with("WES"), Translocation_Summary, Dataset) %>% 
    rename(id = WES_prep_id) %>%
    filter( id != "NA") %>%
    gather( key = field, value = Value, ends_with("MMSET"):ends_with("MAFB") ) %>%
    separate( field, c("Sequencing_Type", "Result"), "_")
  
  wgs <- trsl %>% 
    select(starts_with("WGS"), Translocation_Summary, Dataset) %>% 
    rename(id = WGS_prep_id) %>%
    filter( id != "NA") %>%
    gather( key = field, value = Value, ends_with("MMSET"):ends_with("MAFB") ) %>%
    separate( field, c("Sequencing_Type", "Result"), "_")
  
  rna <- trsl %>% 
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
  
  
  out <-   df %>%
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
  
  # copy original tables to local
  local      <- "/tmp/curation"
  if(!dir.exists(local)){dir.create(local)}
  
  name <- "simplified.mutations.20161115.txt"
  s3_path <- file.path(s3,"SeqData/WES/ProcessedData/DFCI_MMRF_UAMS/mutect2", name)
  system(paste('aws s3 cp', s3_path, local, sep = " "))
  
  snv <- read.delim(file.path(local,name))
  snv <- as.data.frame(t(snv))
  
  # edit filenames to match integrated table and check 
  snv[['File_Name']] <- gsub("^X", "", row.names(snv))
  snv[['File_Name']] <- gsub("^_E.*_([bcdBCD])", "\\1", snv$File_Name)
  
  # move File_Name to first column position
  snv <- snv[,c("File_Name", names(snv)[-1] )]
  row.names(snv) <- 1:nrow(snv)
  
  # Previous versions used MMRF Sample_Name identifiers, this is no longer needed with 20161115 version 
  # only problem now is MMRF is listed by sampleid instead of filename
  # we'll need to lookup the filename assuming they are somatic tumor samples
    # system(paste('aws s3 cp', file.path(s3clinical,"ProcessedData","Integrated","PER-FILE_clinical_cyto.txt"), 
    #              file.path(local.path,"PER-FILE_clinical_cyto.txt"), sep = " "))
    # per.file <- read.delim(file.path(local.path,"PER-FILE_clinical_cyto.txt"), 
    #            sep = "\t", as.is = T, check.names = F, stringsAsFactors = F)
    # 
    # mmrf_filename_lookup <- per.file[per.file$Study == "MMRF" & 
    #                                    per.file$Sample_Type_Flag == 1 &
    #                                    per.file$Sequencing_Type == "WES" &
    #                                    per.file$Tissue_Type == "BM"
    #                                  , c("Sample_Name", "File_Name")]
    # # verify that we have no duplicate filenames for each samplename
    # # length(mmrf_filename_lookup$Sample_Name) == length(unique(mmrf_filename_lookup$Sample_Name))
    # # length(snv$File_Name) == length(unique(snv$File_Name))
    # names(mmrf_filename_lookup) <- c("File_Name", "MMRF_File_Name")
    # df <- merge(snv, mmrf_filename_lookup, by = "File_Name", all.x = T)
    # 
    # unified_names <- unlist(apply(df, MARGIN = 1, function(x){
    #   if( grepl("^MMRF", x[['File_Name']]) ){return(x[["MMRF_File_Name"]])
    #     }else{return(x[["File_Name"]])}
    # }))
    # 
    # snv[['File_Name']] <- unified_names
    # # TODO: this only inserts SNV info for a single filename, 
    # #        but it might be appropriate to add for all tumor samples at
    # #        the same timepoint?
    # 
  # rename columns to match dictionary format
  n <- names(snv)
  n <- paste("SNV",n,"mutect2", sep = "_")
  n <- gsub("SNV_File_Name_mutect2","File_Name", n)
  
  names(snv) <- n
    
  name <- "curated_SNV_mutect2.txt"
  local.path <- file.path(local,name)
  write.table(snv, local.path, row.names = F, col.names = T, sep = "\t", quote = F)
  rm(snv)
  
  # put curated file back as ProcessedData
  system(  paste('aws s3 cp', local.path, file.path(s3clinical,"ProcessedData", "JointData", name), "--sse", sep = " "))
 
  
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
  
  
  