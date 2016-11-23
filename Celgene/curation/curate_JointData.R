## drozelle@ranchobiosciencs.com
##

d <- format(Sys.Date(), "%Y-%m-%d")

# locations
s3            <- "s3://celgene.rnd.combio.mmgp.external"
s3clinical    <- file.path(s3, "ClinicalData")

local         <- "/tmp/curation"
if(!dir.exists(local)){dir.create(local)}


# CNV --------------------------------------------------------------------
## CNV from Cody (TCAshby@uams.edu)
print("CNV Curation........................................")
  # copy original tables to local
  system(paste('aws s3 cp', 's3://celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/DFCI_MMRF_UAMS/copy_number/copy_number_table.xlsx', local, sep = " "))
  name <- "copy_number_table.xlsx"
  cnv <- readxl::read_excel(file.path(local,name),
                            sheet = 1, # sheet one has all unfiltered results
                            skip = 1 )
  
  # I applied a three step criteria for filtering:
    # 1.) t-test on regions of relative chromosomal stability (chromosome 2 and 10). If neither of them are normal (CN=2) than the sample fails.
    # 2.) Median of the standard deviations of the data points across all chromosomes. If higher than 0.3, than the sample fails.
    # 3.) If there are more than 600 CN segments, then the sample fails.
  cnv <- cnv[cnv$passed_filter == 1,]
  cnv$passed_filter <- NULL
  
  n <- names(cnv)
  n <- paste("CNV",n,"ControlFreec", sep = "_")
  n[1] <- "File_Name"
  names(cnv) <- n
  
  # edit filenames to match integrated table and check 
  cnv$File_Name <- gsub("HUMAN_37_pulldown_", "", cnv$File_Name)
  cnv$File_Name <- gsub("^_E.*_([bcdBCD])", "\\1", cnv$File_Name)
  #all(cnv$File_Name %in% per.file$File_Name)
  
  # write to local
  path <- file.path(local,"curated_CNV_ControlFreec.txt")
  write.table(cnv, path, row.names = F, col.names = T, sep = "\t", quote = F)
  
  # compile a cnv dictionary
  cnv_locations <- data.frame(t(readxl::read_excel(file.path(local,"copy_number_table.xlsx"),
                            sheet = 1, col_names = F )[1:2,]))
  # trim top two lines
  cnv_locations <- cnv_locations[3:nrow(cnv_locations),]
  
  cnv_locations['names'] <-   paste("CNV",cnv_locations$X2,"ControlFreec", sep = "_")
  cnv_locations['key_val'] <- '0"=homozygous deletion"; 1="loss"; 2="normal"; -2="copy number neutral loss of heterozygosity"; 3="gain"; 4="amplification"'
  cnv_locations['description'] <- paste("chromosome_hg19 start position", cnv_locations$X1, sep = " ")
  
  cnv_locations[,c("X1", "X2")] <- NULL
  
  # write to local
  path <- file.path(local,"cnv_dictionary.txt")
  write.table(cnv_locations, path, row.names = F, col.names = T, sep = "\t", quote = F)
  
  name <- "curated_CNV_ControlFreec.txt"
  system(  paste('aws s3 cp', file.path(local, name), file.path(s3clinical, "ProcessedData", "JointData", name), '--sse', sep = " "))
  
  name <- "cnv_dictionary.txt"
  system(  paste('aws s3 cp', file.path(local, name), file.path(s3clinical, "ProcessedData", "Integrated", name), '--sse', sep = " "))
  return_code <- system('echo $?', intern = T)
  if(return_code == "0") system(paste0("rm -r ", local))
  rm(cnv, cnv_locations)

# translocation --------------------------------------------------------------------
## Translocations using MANTA from Brian (BWalker2@uams.edu)
print("Translocation Curation........................................")
  
  # locations
  s3clinical <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData"
  local      <- "/tmp/curation"
  if(!dir.exists(local)){dir.create(local)}
  
  # get current original files
  name <- "All_translocation_Summaries_from_BWalker_2016-10-04_zeroed_dkr.xlsx"
  s3.path <- file.path(s3clinical,"OriginalData", "Joint", name)
  system(  paste('aws s3 cp', s3.path, local, sep = " "))
  
  local.path=file.path(local, name)
  
  uams <- readxl::read_excel(path=local.path,sheet=1);
  dfci <- readxl::read_excel(path=local.path,sheet=2);
  mmrf <- readxl::read_excel(path=local.path,sheet=3);
  uams[uams == 'N/A'] <- NA;
  dfci[dfci == 'N/A'] <- NA;
  mmrf[mmrf == 'N/A'] <- NA;
  
  df <- data.frame(study=c(rep('UAMS',nrow(uams)),
                           rep('DFCI',nrow(dfci)),
                           rep('MMRF',nrow(mmrf))),
                   ss1 = c(uams$Sample,
                           dfci$Sample,
                           mmrf$SampleSet1
                   ),
                   ss2 = c(uams$Sample,
                           dfci$Sample,
                           mmrf$SampleSet2
                   ),
                   File_Name=c(uams$simple_name,
                               dfci$Sample,
                               
                               # parse mmrf filenames from first two columns
                               unlist( mapply(function(uno, dos){
                                 if( !is.na(uno) & uno != "0"){
                                   s <- uno
                                 }else{
                                   s <- dos
                                 }
                                 gsub("^.*(MMRF.*)$","\\1",s)
                               }, mmrf$SampleSet1, mmrf$SampleSet2))
                              
                   ),
                   CYTO_Hyperdiploid_ControlFreec=c(uams$UK_HRD_CALL == 'HRD',
                                                    dfci$HRD_summary == 'HRD',
                                                    mmrf$HRD_Summary == 'HRD'),
                   CYTO_Translocation_CONSENSUS=c(as.character(uams$UK_Tx_CALL),
                                                  as.character(dfci$TC_summary),
                                                  as.character(mmrf$TC_Summary)),
                   
                   "CYTO_1q_plus_ControlFreec" = c(rep(NA, times = nrow(uams)),
                                                   dfci$`ControlFreec_1Q+` == "1Q+",
                                                   mmrf$`ControlFreec_1Q+` == "1Q+"),
                   "CYTO_amp(1q)_ControlFreec" = c(rep(NA, times = nrow(uams)),
                                                   rep(NA, times = nrow(dfci)),
                                                   mmrf$`ControlFreec_1Q+` == "GAIN"),
                   "CYTO_del(1q)_ControlFreec" = c(rep(NA, times = nrow(uams)),
                                                   rep(NA, times = nrow(dfci)),
                                                   mmrf$`ControlFreec_1Q+` == "DEL1Q"),
                   
                   "CYTO_t(4;14)_MANTA"= c(uams$`MANTA_(4;14)`  != "0",
                                           dfci$`MANTA_(4;14)`  != "0",
                                           mmrf$`MANTA_(4;14)`  != "0"),
                   "CYTO_t(6;14)_MANTA"= c(uams$`MANTA_(6;14)`  != "0",
                                           dfci$`MANTA_(6;14)`  != "0",
                                           mmrf$`MANTA_(6;14)`  != "0"),
                   "CYTO_t(11;14)_MANTA"=c(uams$`MANTA_(11;14)` != "0",
                                           dfci$`MANTA_(11;14)` != "0",
                                           mmrf$`MANTA_(11;14)` != "0"),
                   "CYTO_t(14;16)_MANTA"=c(uams$`MANTA_(14;16)` != "0",
                                           dfci$`MANTA_(14;16)` != "0",
                                           mmrf$`MANTA_(14;16)` != "0"),
                   "CYTO_t(14;20)_MANTA"=c(uams$`MANTA_(14;20)` != "0",
                                           dfci$`MANTA_(14;20)` != "0",
                                           mmrf$`MANTA_(14;20)` != "0"),
                   "CYTO_MYC_MANTA"=     c(uams$`MANTA_MYC`     != "0",
                                           dfci$`MANTA_MYC`     != "0",
                                           mmrf$`MANTA_MYC`     != "0"),
                   
                   
                   check.names = F, stringsAsFactors = F
  )
  
  df[df==TRUE]  <- "1"
  df[df==FALSE] <- "0"
  
  name <- paste("curated", name, sep = "_")
  name <- gsub("xlsx", "txt", name)
  local.path <- file.path(local,name)
  write.table(df, local.path, row.names = F, col.names = T, sep = "\t", quote = F)
  rm(df)
  
  # put curated file back as ProcessedData
  system(  paste('aws s3 cp', local.path, file.path(s3clinical,"ProcessedData", "JointData", name), "--sse", sep = " "))
  return_code <- system('echo $?', intern = T)
  
  # as a failsafe to prevent reading older versions of source files remove the
  #  cached version file if transfer was successful.
  if(return_code == "0") system(paste0("rm -r ", local))
  rm(dfci, mmrf, uams)
  
  
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
  
  
  