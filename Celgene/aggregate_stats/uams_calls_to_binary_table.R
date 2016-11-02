library(readxl)

# locations
s3clinical <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData"
local      <- "/tmp/curation"
if(!dir.exists(local)){dir.create(local)}

# get current original files
name <- "All_translocation_Summaries_from_BWalker_2016-10-04_zeroed_dkr.xlsx"
s3.path <- file.path(s3clinical,"OriginalData", name)
system(  paste('aws s3 cp', s3.path, local, sep = " "))

local.path=file.path(local, name)

  uams <- read_excel(path=local.path,sheet=1);
  dfci <- read_excel(path=local.path,sheet=2);
  mmrf <- read_excel(path=local.path,sheet=3);
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
  
  df[df==TRUE] <- "1"
  df[df==FALSE] <- "0"
  
  name <- paste("curated", name, sep = "_")
  name <- gsub("xlsx", "txt", name)
  path <- file.path(local,name)
  write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
  rm(df)

  # put curated file back as ProcessedData
  s3.path    <- file.path(s3clinical,"ProcessedData", name)
  local.path <- file.path(local, name)
  system(  paste('aws s3 cp', local.path, s3.path, "--sse", sep = " "))
  return_code <- system('echo $?', intern = T)

  # as a failsafe to prevent reading older versions of source files remove the
  #  cached version file if transfer was successful.
  if(return_code == "0") system(paste0("rm -r ", local))
  