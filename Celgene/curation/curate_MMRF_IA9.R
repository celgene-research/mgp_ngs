## drozelle@ranchobiosciences.com
## MMRF file curation

# vars
study <- "MMRF"
d <- format(Sys.Date(), "%Y-%m-%d")
source("curation_scripts.R")

# locations
s3            <- "s3://celgene.rnd.combio.mmgp.external"
raw_inventory <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/Integrated/file_inventory.txt"

# as a failsafe to prevent reading older versions of source files remove the 
#  cached version file if transfer was successful.
local         <- "/tmp/curation"
system(paste0("rm -r ", local))
dir.create(local)

# get current original files
original <- file.path(s3,"ClinicalData/OriginalData/MMRF_IA9/")
system(  paste('aws s3 cp', original, local, '--recursive', sep = " "))
system(  paste('aws s3 cp', raw_inventory, local, sep = " "))

### file_inventory -------------------------
name <- "file_inventory.txt"
  inv <- read.delim(file.path(local,name), stringsAsFactors = F)
  inv <- inv[inv$Study == "MMRF",]
  
  # remove Sequencing_Type and only use from SeqQC source table
  inv$Sequencing_Type <- NULL
  # we can also parse a few more fields from the MMRF names
  inv[['File_Name_Actual']] <- inv$File_Name
  # remove filename extension
  inv$File_Name <- gsub("^(.*?)\\..*$", "\\1", inv$File_Name)
  inv[['Sample_Type']]    <-  ifelse(grepl("CD138pos",inv$File_Name), "NotNormal", "Normal")
  inv[['Sample_Type_Flag']]<- ifelse(grepl("CD138pos",inv$File_Name), "1", "0")
  inv[['Tissue_Type']]    <-  ifelse(grepl("BM",inv$File_Name), "BM", "PB")
  inv[['Cell_Type']]      <-  gsub(".{12}[PBM]+_([A-Za-z0-9]+)_[CT]\\d.*","\\1",inv$File_Name)
  inv[['Disease_Status']] <-  ifelse(grepl("1$", inv$Sample_Name),"ND", "R")
  
  name <- paste("curated", study, name, sep = "_")
  path <- file.path(local,name)
  write.table(inv, path, row.names = F, col.names = T, sep = "\t", quote = F)

### file_inventory.2 -------------------------
# fetch SRR encoded WGS filenames directly from S3
  df <- data.frame(File_Path = system(paste('aws s3 ls', 
                           's3://celgene.rnd.combio.mmgp.external/SeqData/WGS/OriginalData/MMRF/',
                           '--recursive |',
                           'grep "2.fastq.gz$" | sed "s/.*SeqData/SeqData/"',
                           sep = " "), intern = T),
                   Study = "MMRF",
                   Study_Phase = "",
                   stringsAsFactors = F)
  df[['File_Name_Actual']] <- gsub(".*(SRR.*)", "\\1", df$File_Path)
  
  # these files are named by the SRR run number and must to converted
  # I'm using the import table from Kostas, but this can also be downloaded from SRA
  name <- "data.import.WGS.Kostas.IA3-IA7.xls"
  system(paste("aws s3 cp",
               file.path(s3, "SeqData/WGS/OriginalData/MMRF", name),
               file.path(local, name),
               sep = " "))
  kostas.import <- read.delim(file.path(local, name), stringsAsFactors = F)
  mapping <- data.frame(File_Name_Actual = gsub(".*(SRR.*)", "\\1", kostas.import$filename),
                        File_Name        = kostas.import$vendor_id,
                        stringsAsFactors = F)
  
  df <- merge(df, mapping, by = "File_Name_Actual", all.x = T)
  
  # we can also parse directly from the MMRF names
  df[['Sample_Name']]    <- gsub("^(MMRF_[0-9]+_[0-9]+)_.*$", "\\1", df$File_Name)
  df[['Patient']]    <- gsub("^(MMRF_[0-9]+)_[0-9]+_.*$", "\\1", df$File_Name)
  df[['Sample_Type']]    <-  ifelse(grepl("CD138pos",df$File_Name), "NotNormal", "Normal")
  df[['Sample_Type_Flag']]<- ifelse(grepl("CD138pos",df$File_Name), "1", "0")
  df[['Tissue_Type']]    <-  ifelse(grepl("BM",df$File_Name), "BM", "PB")
  df[['Cell_Type']]      <-  gsub(".{12}[PBM]+_([A-Za-z0-9]+)_[CT]\\d.*","\\1",df$File_Name)
  df[['Disease_Status']] <-  ifelse(grepl("1$", df$Sample_Name),"ND", "R")

  name <- "file.inventory.2.txt"
  name <- paste("curated", study, name, sep = "_")
  path <- file.path(local,name)
  write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
  
### IA9_Seq_QC_Summary -------------------------
# apply higher level sample  variables using IA9 Seq QC table
  name <- "MMRF_CoMMpass_IA9_Seq_QC_Summary.xlsx"
  system(paste("aws s3 cp",
               file.path(s3, "MMRF_CoMMpass_IA9/README_FILES", name),
               file.path(local, name),
               sep = " "))
  
  df <- readxl::read_excel(file.path(local, name))
  df <- data.frame(File_Name       = df$`QC Link SampleName`,
                   Sample_Name     = df$`Visits::Study Visit ID`,
                   Sequencing_Type = gsub("(.*)-.*", "\\1", df$MMRF_Release_Status),
                   Excluded_Flag   = ifelse(grepl("^Exclude|RNA-No|LI-Neither|Exome-Neither",df$MMRF_Release_Status),1,0),                           
                   Excluded_Specify = df$MMRF_Release_Status,                           
                   stringsAsFactors = F)
  
  # remove exclude_specify for retained samples
  df[df$Excluded_Flag == 0,"Excluded_Specify"] <- NA
  df[df$Sequencing_Type == "Exclude", "Sequencing_Type"] <- NA
  df$Sequencing_Type <- plyr::revalue(df$Sequencing_Type, c(RNA="RNA-Seq", 
                                                               LI="WGS", 
                                                               Exome="WES"))
  
  name <- paste("curated", study, gsub("xlsx","txt",name), sep = "_")
  path <- file.path(local,name)
  write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
  
### PER_PATIENT_VISIT -------------------------
# curate per_visit entries with samples taken for the sample-level table
name <- "PER_PATIENT_VISIT.csv"
  pervisit <- read.csv(file.path(local,name), stringsAsFactors = F, 
                       na.strings = c("Not Done", ""))
  # only keep visits with affiliated samples
  pervisit<- pervisit[ !is.na(pervisit$SPECTRUM_SEQ),]
  
  df <- data.frame(Patient = pervisit$PUBLIC_ID,
                   stringsAsFactors = F)
  
  df[["Study"]]       <- study
  df[["Sample_Name"]] <- pervisit$SPECTRUM_SEQ
  df[["Visit_Name"]] <- pervisit$VJ_INTERVAL
  df[["Disease_Status"]] <- ifelse(grepl("1$", df$Sample_Name),"ND", "R")
  df[["Disease_Status_Notes"]] <- pervisit$CMMC_VISIT_NAME
  df[["Sample_Study_Day"]] <- pervisit$BA_DAYOFASSESSM
  df[["CYTO_Has_Conventional_Cytogenetics"]] <- ifelse(pervisit$D_CM_cm == 1, 1,0)
  df[["CYTO_Has_FISH"]] <- ifelse(pervisit$D_TRI_cf == 1, 1,0)

  # df[['CYTO_1qplus_FISH']]    <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR13 =="Yes" ,1,0)   
    
  df[['CYTO_del(1p)_FISH']]    <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR12 =="Yes" ,1,0) 
  df[['CYTO_t(4;14)_FISH']]    <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR3 == "Yes" ,1,0)   
  df[['CYTO_t(6;14)_FISH']]    <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR4 == "Yes" ,1,0)   
  df[['CYTO_t(11;14)_FISH']]   <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR6 == "Yes" ,1,0)    
  df[['CYTO_t(12;14)_FISH']]   <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR7 == "Yes" ,1,0)    
  df[['CYTO_t(14;16)_FISH']]   <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR8 == "Yes" ,1,0)    
  df[['CYTO_t(14;20)_FISH']]   <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR9 == "Yes" ,1,0)    
  df[['CYTO_amp(1q)_FISH']]    <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR13 == "Yes" ,1,0)
  df[['CYTO_del(13q)_FISH']]   <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR == "Yes" ,1,0)    
  
  d17  <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR2 == "Yes" ,TRUE,FALSE)
  d17p <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR11 == "Yes" ,TRUE,FALSE)
  df[['CYTO_del(17;17p)_FISH']]    <-   ifelse(d17 | d17p, 1,0)
  
  df[['CYTO_Hyperdiploid_FISH']]  <- ifelse( pervisit$Hyperdiploid == "Yes" ,1,0)    
  df[['CYTO_MYC_FISH']]    <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR5 == "Yes" ,1,0)   
  
  df[['CBC_Absolute_Neutrophil']] <- pervisit$D_LAB_cbc_abs_neut
  df[['CBC_Platelet']]            <- pervisit$D_LAB_cbc_platelet
  df[['CBC_WBC']]                 <- pervisit$D_LAB_cbc_wbc
  df[['DIAG_Hemoglobin']]         <- pervisit$D_LAB_cbc_hemoglobin
  df[['DIAG_Albumin']]            <- pervisit$D_LAB_chem_albumin
  df[['DIAG_Calcium']]            <- pervisit$D_LAB_chem_calcium
  df[['DIAG_Creatinine']]         <- pervisit$D_LAB_chem_creatinine
  df[['DIAG_LDH']]                <- pervisit$D_LAB_chem_ldh
  df[['DIAG_Beta2Microglobulin']] <- pervisit$D_LAB_serum_beta2_microglobulin
  df[['CHEM_BUN']]                <- pervisit$D_LAB_chem_bun
  df[['CHEM_Glucose']]            <- pervisit$D_LAB_chem_glucose
  df[['CHEM_Total_Protein']]      <- pervisit$D_LAB_chem_totprot
  df[['CHEM_CRP']]                <- pervisit$D_LAB_serum_c_reactive_protein
  df[['IG_IgL_Kappa']]            <- pervisit$D_LAB_serum_kappa
  df[['IG_M_Protein']]            <- pervisit$D_LAB_serum_m_protein
  df[['IG_IgA']]                  <- pervisit$D_LAB_serum_iga
  df[['IG_IgG']]                  <- pervisit$D_LAB_serum_igg
  df[['IG_IgL_Lambda']]           <- pervisit$D_LAB_serum_lambda
  df[['IG_IgM']]                  <- pervisit$D_LAB_serum_igm
  df[['IG_IgE']]                  <- pervisit$D_LAB_serum_ige 
  
  # TODO: verify that we can assume these FISH results are from tumor samples
  # also note, since single samples correspond to multiple filename there is sample info redundancy
  tumor_lookup <- inv[inv$Tissue_Type == "BM" ,c("Sample_Name", "File_Name")]
  df <- merge(df, tumor_lookup, by = "Sample_Name", all.x = T)
  
  name <- paste("curated", name, sep = "_")
  path <- file.path(local,name)
  write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
  rm(df, pervisit, tumor_lookup)

### PER_PATIENT -------------------------
# curate PER_PATIENT entries, requires some standalone tables for calculations
name <- "PER_PATIENT.csv"
  perpatient <- read.csv(file.path(local,name), stringsAsFactors = F)
  
  survival <- read.csv(file.path(local,"STAND_ALONE_SURVIVAL.csv"), stringsAsFactors = F)
  medhx <- read.csv(file.path(local,"STAND_ALONE_MEDHX.csv"), stringsAsFactors = F)
  famhx <- read.csv(file.path(local,"STAND_ALONE_FAMHX.csv"), stringsAsFactors = F)
  respo <- read.csv(file.path(local,"STAND_ALONE_TRTRESP.csv"), stringsAsFactors = F)
  treat <- read.csv(file.path(local,"STAND_ALONE_TREATMENT_REGIMEN.csv"), stringsAsFactors = F)
  
  
  # collapse multiple columns of race info into a single delimited string
  tmp <- perpatient[,c("D_PT_race", "DEMOG_AMERICANINDIA", "DEMOG_ASIAN", "DEMOG_BLACKORAFRICA", "DEMOG_WHITE", "DEMOG_OTHER")]
  decoded_matrix <- data.frame(
    gsub("Checked", "AMERICANINDIAN", tmp$DEMOG_AMERICANINDIA),
    gsub("Checked", "ASIAN", tmp$DEMOG_ASIAN),
    gsub("Checked", "BLACKORAFRICAN", tmp$DEMOG_BLACKORAFRICA),
    gsub("Checked", "WHITE", tmp$DEMOG_WHITE),
    gsub("Checked", "OTHER", tmp$DEMOG_OTHER)
  )
  perpatient[['RACE']] <- apply(decoded_matrix, MARGIN = 1, function(x){
    x <- x[x != ""]
    paste(x, collapse = "; ")
  })
  rm(decoded_matrix, tmp)
  
  
  df <- data.frame(Patient = perpatient$PUBLIC_ID, stringsAsFactors = F)
  df[["D_Gender"]]                <- perpatient$DEMOG_GENDER
  df[["D_Race"]]                  <- perpatient$RACE
  df[["D_Age"]]                   <- perpatient$D_PT_age
  df[["D_ISS"]]                   <- perpatient$D_PT_iss
  
  # Calculate Overall Survival time. This is the reported ttos for deceased patients or 
  #  time to last contact for those who are still living. Last contact is the max value from
  #  PER_PATIENT.D_PT_lstalive, PER_PATIENT.lvisit, or mmrf.survival.oscdy fields. 
  #  NA for any negative values. We need a lookup table to make these calculations.
  
  # df <- data.frame(Patient = mmrf.clinical$Patient,
  #                  stringsAsFactors = F)
  lookup_by_publicid <- lookup.values("public_id")
  df[['ttos']] <- as.integer(unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "ttos")))
  df[['D_PT_ic_day']] <- as.integer(unlist(lapply(df$Patient, lookup_by_publicid, dat = perpatient, field = "D_PT_ic_day")))
  df[['D_PT_lstalive']] <- as.integer(unlist(lapply(df$Patient, lookup_by_publicid, dat = perpatient, field = "D_PT_lstalive")))
  df[['D_PT_lvisitdy']] <- as.integer(unlist(lapply(df$Patient, lookup_by_publicid, dat = perpatient, field = "D_PT_lvisitdy")))
  df[['oscdy']] <- as.integer(unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "oscdy")))
  df[['ttfpd']] <- as.numeric(unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "ttfpd")))
  
  df[['D_OS']] <- as.integer(unlist(apply(df, MARGIN = 1, function(x){
    if(!is.na(x['ttos'])){return(x['ttos'])
    }else if(any(!(is.na(x['D_PT_lstalive'])), !(is.na(x['D_PT_lvisitdy'])), !(is.na(x['oscdy'])))){
      bar <- max(
        suppressWarnings(as.numeric(x['D_PT_lstalive'])),
        suppressWarnings(as.numeric(x['D_PT_lvisitdy'])),
        suppressWarnings(as.numeric(x['oscdy'])),
        na.rm = T)
      if(bar < 0 ){return(NA)
      }else{return(bar)}
    }else{return(NA)}
  })))
  
  # turns out "death day" is a more consistent field than the D_PT_DISCREAS flag,
  # which was missing for a few patients that had a death date. Flag the patient
  #  if they are deceased; 0=no (deathdy == NA); 1=yes (deathdy != NA)
  df[["D_OS_FLAG"]] <- ifelse( is.na( unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "deathdy"))),0,1)
  
  # Progression Free time: time to progression for those who progressed; (ttfpd =	Time to first PD)
  #  time to last contact for those who still have not progressed (mmrf.PER_PATIENT$D_PT_lvisitdy)
  progression_matrix <- data.frame(
    observed.pd = as.numeric(unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "ttfpd"))),
    last.alive  = as.numeric(unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "lstalive"))),
    last.visit  = as.numeric(unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "lvisitdy")))
  )
  
  df[["D_PFS"]] <- apply(progression_matrix, MARGIN = 1, function(x){
    foo <- c( x[[2]], x[[3]])
    # if there is an observed progression, report it
    if( !is.na(x[[1]]) ){
      return(x[[1]])
  
      #else if there is a last visit or last alive day, use the larger
    } else if( any(!is.na(foo)) ){
      foo <- foo[!is.na(foo)]
      m <- max(foo)
      if( m < 0 ){m <- NA}
  
      return(m)
  
    } else{return(NA)}
  })
  
  # has the patient developed progressive disease (1) or not (0)
  df[["D_PFS_FLAG"]] <- ifelse(!is.na(  unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "ttfpd"))  ) ,1,0)
  df[["D_Cause_of_Death"]] <-  unlist(lapply(df$Patient, lookup_by_publicid, dat = perpatient, field = "D_PT_CAUSEOFDEATH"))
  df[["D_Reason_for_Discontinuation"]] <-  unlist(lapply(df$Patient, lookup_by_publicid, dat = perpatient, field = "D_PT_PRIMARYREASON"))
  df[["D_Discontinued"]] <-  unlist(lapply(df$Patient, lookup_by_publicid, dat = perpatient, field = "D_PT_discont"))
  df[["D_Complete"]] <-  unlist(lapply(df$Patient, lookup_by_publicid, dat = perpatient, field = "D_PT_complete"))
  
  # filter response table using line =1 (first line treatment only), trtbresp=1 (Treatment best response) then find that response
  best_response_table <- respo[respo$trtbresp == 1 & respo$line == 1 ,]
  df[["D_Best_Response_Code"]] <-  unlist(lapply(df$Patient, lookup_by_publicid, dat = best_response_table, field = "bestrespcd"))
  df[["D_Best_Response"]] <-  unlist(lapply(df$Patient, lookup_by_publicid, dat = best_response_table, field = "bestresp"))

  name <- paste("curated", name, sep = "_")
  path <- file.path(local,name)
  write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
  rm(df)

### cleanup -------------------------
rm(inv, famhx, medhx, respo, survival, treat, perpatient)

# put curated files back as ProcessedData on S3
processed <- file.path(s3,"ClinicalData/ProcessedData",paste0(study,"_IA9"))
system(  paste('aws s3 cp', local, processed, '--recursive --exclude "*" --include "curated*" --sse', sep = " "))

