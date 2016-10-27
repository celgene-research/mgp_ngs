# Dan Rozelle
# Sep 19, 2016
# rev 20161024 edit to directly acces s3 objects, new approach

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
study <- "MMRF"
d <- format(Sys.Date(), "%Y-%m-%d")

# locations
s3clinical    <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData"
raw_inventory <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/Integrated/file_inventory.txt"
ia9_data      <- "s3://celgene.rnd.combio.mmgp.external/MMRF_CoMMpass_IA9/clinical_data_tables/CoMMpass_IA9_FlatFiles/"
local         <- "/tmp/curation"
  if(!dir.exists(local)){dir.create(local)}

# get current original files
original <- file.path(ia9_data)
system(  paste('aws s3 cp', original, local, '--recursive', sep = " "))
system(  paste('aws s3 cp', raw_inventory, local, sep = " "))

################################################
# clean up the MMRF inventory entries
name <- "file_inventory.txt"
  inv <- read.delim(file.path(local,name), stringsAsFactors = F)
  inv <- inv[inv$Study == "MMRF",]
  # we can also parse a few more fields from the MMRF names
  
  inv[['Sample_Type']]    <-  ifelse(grepl("CD138pos",inv$File_Name), "NotNormal", "Normal")
  inv[['Sample_Type_Flag']]<- ifelse(grepl("CD138pos",inv$File_Name), "1", "0")
  inv[['Tissue_Type']]    <-  ifelse(grepl("BM",inv$File_Name), "BM", "PB")
  inv[['Cell_Type']]      <-  gsub(".{12}[PBM]+_([A-Za-z0-9]+)_[CT]\\d.*","\\1",inv$File_Name)
  inv[['Disease_Status']] <-  ifelse(grepl("1$", inv$Sample_Name),"ND", "R")
  
  name <- paste("curated", study, name, sep = "_")
  path <- file.path(local,name)
  write.table(inv, path, row.names = F, col.names = T, sep = "\t", quote = F)
  rm(inv)

################################################
# curate per_visit entries with samples taken for the sample-level table
name <- "PER_PATIENT_VISIT.csv"
  pervisit <- read.csv(file.path(local,name), stringsAsFactors = F, 
                       na.strings = c("Not Done", ""))
  # only keep visits with affiliated samples
  pervisit<- pervisit[pervisit$SPECTRUM_SEQ != "",]
  
  df <- data.frame(Patient = pervisit$PUBLIC_ID)
  
  df[["Study"]]       <- study
  df[["Sample_Name"]] <- pervisit$SPECTRUM_SEQ
  df[["Visit_Name"]] <- pervisit$VJ_INTERVAL
  df[["Disease_Status"]] <- ifelse(grepl("1$", df$Sample_Name),"ND", "R")
  df[["Disease_Status_Notes"]] <- pervisit$CMMC_VISIT_NAME
  df[["Sample_Study_Day"]] <- pervisit$BA_DAYOFASSESSM
  df[["CYTO_Has_Conventional_Cytogenetics"]] <- ifelse(pervisit$D_CM_cm == 1, 1,0)
  df[["CYTO_Has_FISH"]] <- ifelse(pervisit$D_TRI_cf == 1, 1,0)

  # df[['CYTO_1q_plus_FISH']]    <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR13 =="Yes" ,1,0)   
    
  df[['CYTO_del(1p)_FISH']]    <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR12 =="Yes" ,1,0) 
  df[['CYTO_t(4;14)_FISH']]    <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR3 == "Yes" ,1,0)   
  df[['CYTO_t(6;14)_FISH']]    <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR4 == "Yes" ,1,0)   
  df[['CYTO_t(8;14)_FISH']]    <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR5 == "Yes" ,1,0)   
  df[['CYTO_t(11;14)_FISH']]   <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR6 == "Yes" ,1,0)    
  df[['CYTO_t(12;14)_FISH']]   <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR7 == "Yes" ,1,0)    
  df[['CYTO_t(14;16)_FISH']]   <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR8 == "Yes" ,1,0)    
  df[['CYTO_t(14;20)_FISH']]   <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR9 == "Yes" ,1,0)    
  df[['CYTO_amp(1q)_FISH']]    <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR13 == "Yes" ,1,0)
  df[['CYTO_del(17)_FISH']]    <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR2 == "Yes" ,1,0)   
  df[['CYTO_del(17p)_FISH']]   <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR11 == "Yes" ,1,0)    
  df[['CYTO_del(13q)_FISH']]   <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR == "Yes" ,1,0)    
  
  df[['CYTO_Hyperdiploid_FISH']]  <- ifelse( pervisit$Hyperdiploid == "Yes" ,1,0)    

  name <- paste("curated", name, sep = "_")
  path <- file.path(local,name)
  write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
  rm(df)

################################################
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
  df[["D_Best_Response_Code"]] <-  unlist(lapply(df$Patient, lookup_by_publicid, dat = respo, field = "bestrespcd"))
  df[["D_Best_Response"]] <-  unlist(lapply(df$Patient, lookup_by_publicid, dat = respo, field = "bestresp"))

  name <- paste("curated", name, sep = "_")
  path <- file.path(local,name)
  write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)
  rm(df)

#######



# put curated files back as ProcessedData on S3
processed <- file.path(s3clinical,"ProcessedData",study)
system(  paste('aws s3 cp', local, processed, '--recursive --exclude "*" --include "curated*" --sse', sep = " "))
return_code <- system('echo $?', intern = T)

# as a failsafe to prevent reading older versions of source files remove the 
#  cached version file if transfer was successful.
if(return_code == "0") system(paste0("rm -r ", local))
  
  