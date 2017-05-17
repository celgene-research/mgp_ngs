
# global vars
d  <- format(Sys.Date(), "%Y-%m-%d")
s3 <- "s3://celgene.rnd.combio.mmgp.external"

options(stringsAsFactors = FALSE)
# ,
# error = function() { 
#   
#   if(!interactive()) RPushbullet::pbPost("note", "Error", geterrmessage()))
# })


# attach important packages
# devtools::install_github("dkrozelle/toolboxR", force = TRUE)
library(toolboxR)
library(dplyr) # don't load plyr, it will conflict
library(tidyr)
library(data.table)

# this function does not allow specification of directory to 
# prevent inadvertant file deletion 
CleanLocalScratch <- function(){
  path = "/tmp/curation"
  if(dir.exists(path)){system(paste('rm -r', path, sep = " "))}
  dir.create(path)
  path
}
# run on source
local <- CleanLocalScratch()

# moves files from an s3 directory that are not the most current to 
# an /archive subfolder
# 
# NOTE: Currently will not work for similar named files only differentiated by extension
archive <- function(path, aws.args = NULL){
  
  # TODO: prevent recursion to lower directories
  stale.versions <- system(paste('aws s3 ls', paste0(path, "/")), intern = T) %>% 
    as.data.frame() %>%
    transmute(name = gsub("^.* ", "", .),
              root = gsub("^(.*)\\.([0-9\\-]{10})\\..*", "\\1", name),
              date = gsub("^(.*)\\.([0-9\\-]{10})\\..*", "\\2", name)) %>%
    group_by(root) %>%
    arrange(desc(date)) %>%
    # remove directories
    filter(!grepl("\\/$", root)) %>%
    # only consider rows with valid date formats
    filter(grepl("^[0-9]{4}\\-[0-9]{2}\\-[0-9]{2}$", date)) %>%
    # remove the most recent result from eahc root group
    slice(-1)
  
  null <- lapply(stale.versions$name, function(n){
    from <- file.path(path,n)
    to   <- file.path(path, "archive", n)
    system(paste('aws s3 mv', 
                 from, to, 
                 '--sse', aws.args))
  })
}

order_by_dictionary <- function(df, table = NULL, add.missing.columns = T){
  
  if( is.null(table) ) stop('please specify a table or use table=""')
  dict <- get_dict() %>% filter( grepl(table, level) )  
  
  if( add.missing.columns ){
    missing.cols <- dict$names[!dict$names %in% names(df)]
    df[,missing.cols] <- NA
  }
  
  if( any(!names(df) %in% dict$names) ){
    message(
      paste( paste(names(df)[!names(df) %in% dict$names], collapse = ", "), 
             "columns are not in dictionary and will be lost" )
    )
  }
  
  df[,dict$names]
}


call_sample_core_translocations     <- function(translocations){}
call_patient_core_translocations    <- function(translocations, metadata){}

call_secondary_structural_variation <- function(translocations,metadata){
  #
  #  non-exclusive deletions and amplifications, call a per-file consensus based
  #  on multiple possible data sources.
  #
  #   amp(1q) | ND=0, R=1 by FISH | ND=NA, R=NA by MANTA | called as ND=0, R=1
  #   amp(1q) | ND=0, R=1 by FISH | ND=1,  R=NA by MANTA | called as ND=1, R=1
  # currently we only have FISH calls for these, so I'm going to cheat and just transfer those
  # values as the de facto consensus. But I do want to see if they'll cause any clashes
  # then I collapse to nd.tumor patient level
  
  consensus.data <- right_join(metadata, translocations,
                               by = c("Patient", "File_Name")) %>%
    filter(Disease_Status == "ND", Sample_Type_Flag == 1, 
           (Disease_Type == "MM" | is.na(Disease_Type)) ) %>%
    
    select(File_Name, Patient, grep("amp|del|MYC|plus", names(.)), -starts_with("Sample")) %>%
    gather(var, val, -File_Name, -Patient) %>%
    mutate(type      = gsub("CYTO_(.*)_.*", "\\1", var),
           technique = gsub("CYTO_.*_(.*)$", "\\1",var)) %>%
    filter( !is.na(val) )   %>%
    
    # used to identify any conflicted values
    # group_by(Patient, type) %>%
    # mutate() %>%
    # arrange(n)
    
    mutate(type = paste("CYTO", type, "CONSENSUS", sep = "_")) %>%
    spread(type,val)
  
  
  append_df(translocations, consensus.data, id = "File_Name", mode = "safe")
  
}







cytogenetic_consensus_calling <- function(translocations, metadata){
  
  # this revised script performs 3 sequential functions
  # 1. call consensus translocations using multiple techniques (FISH or MANTA). 
  #    If longitudinal samples (ND, R, R2...) are not consistent for an individual translocation 
  #    (t(4;14) ND=1, R=0) then a consensus is only called if the preferred technique is consistent
  # 
  #   t(4;14) | ND=1, R=1 by FISH | ND=NA, R=NA by MANTA | called as ND=1, R=1
  #   t(4;14) | ND=1, R=0 by FISH | ND=NA, R=NA by MANTA | called as ND=NA, R=NA
  #   t(4;14) | ND=1, R=0 by FISH | ND=0, R=0   by MANTA | called as ND=0, R=0
  #   
  # 2. calls the CYTO_Translocation_Consensus field by determining if a single 
  #    t14 consensus translocation has been called for all samples (split by tumor or normal)
  # 
  #   t(4;14)=0;t(6;14)=0;t(11;14)=1;t(14;16)=0 | called as "11" 
  #   t(4;14)=0;t(6;14)=0;t(11;14)=1;t(14;16)=1 | called as "NA" 
  #   t(4;14)=0;t(6;14)=0;t(11;14)=0;t(14;16)=0 | called as ""
  #   
  # 3. similar to step 1, but for non-exclusive deletions and amplifications.
  #
  #   amp(1q) | ND=0, R=1 by FISH | ND=NA, R=NA by MANTA | called as ND=0, R=1
  #   amp(1q) | ND=0, R=1 by FISH | ND=1,  R=NA by MANTA | called as ND=1, R=1
  #
  
  # tidy all translocation columns, filter out NA rows, sort by preferred method 
  sorted <- df %>% 
    # reshape FISH data to long form
    select(Patient, Sample_Name, Study, matches("CYTO_t.*_FISH$"), matches("CYTO_t.*_MANTA$")) %>%
    gather( key = field, value = Value, -c(Patient, Sample_Name,Study) ) %>%
    
    # merge any duplicate File_Name rows, ideally these will be removed at curation
    group_by(Study, Patient, Sample_Name, field) %>%
    summarise(Value = Simplify(Value)) %>%
    
    # split column name 
    separate( field, c("Cat", "Type", "Technique"), "_") %>%
    filter(Value != "NA") %>%
    ungroup()%>%
    
    # sort based on dataset preference for technique type
    # DFCI/UAMS preferd FISH data, MMRF prefers MANTA
    mutate( sort = case_when(
      .$Study %in% c("DFCI", "UAMS") ~ recode(.$Technique, FISH = 1, MANTA = 2),
      .$Study %in% c("MMRF")         ~ recode(.$Technique, FISH = 2, MANTA = 1)
    )) %>%
    group_by(Patient, Sample_Name, Type) %>%
    arrange(Sample_Name, Type, sort) %>%
    select(-sort)
  
  # since translocation calls can be made by multiple unique files per-sample,
  # we need to flag inconsistencies. These are currently retained for QC. 
  conflicted.samples <- sorted  %>%
    filter( length(unique(Value)) >1 ) %>%
    spread(key = Technique, value = Value)
  
  # report conflicted result counts
  x <- ungroup(conflicted.samples) %>% count(Study) %>% unite(x, c(Study, n), sep = " = ")
  message(paste("<conflicted.samples.txt>",
                "Samples with results conflicted between techniques:", 
                paste(x$x, collapse = ", "), 
                sep = " "))
  
  # remove redundant or less preferred translocation calls
  preferred <- sorted  %>%
    # only retain the most preferred value
    slice( 1 ) %>%
    ungroup() %>%
    select(Patient, Sample_Name, Type, Value) 
  
  # call a simplified translocation per-sample (t(4;14 = "4"))
  translocation.consensus <- preferred %>%
    filter( Value == 1 ) %>%
    mutate( Type = gsub("t\\(([0-9]+;[0-9]+)\\)", "\\1", Type)) %>%
    mutate( Type = gsub(";14|14;", "", Type)) %>%
    group_by(Patient, Sample_Name) %>%
    summarise(CYTO_Translocation_Consensus = Simplify(Type))
  # record samples that were tested but don't show any translocations
  no.translocations <- preferred %>% 
    group_by(Patient, Sample_Name) %>%
    summarise(CYTO_Translocation_Consensus = all(Value == "0")) %>%
    filter(CYTO_Translocation_Consensus) %>%
    mutate(CYTO_Translocation_Consensus = "None")
  translocation.consensus <- rbind(translocation.consensus, no.translocations)  
  
  # report patients that don't have consistent translocation consensus for all samples
  # currently this data is retained, but should eventually be converted to NA
  longitudinally.inconsistent.patients <- translocation.consensus %>% 
    group_by(Patient) %>%
    filter( length(unique(CYTO_Translocation_Consensus)) > 1) %>%
    ungroup() %>%
    arrange(Patient, Sample_Name)
  # report inconsistent patient counts
  x <- ungroup(longitudinally.inconsistent.patients) %>% summarise(n())
  message(paste("<longitudinally.inconsistent.patients.txt>",
                x, "patients have inconsistent translocations", 
                sep = " "))
  
  # rename translocation variables for integrated table, spread and merge
  out <- preferred %>%
    mutate(Type = paste("CYTO", .$Type, "CONSENSUS", sep = "_")) %>%
    spread(key = Type, value = Value) 
  # merge consensus calls back to duplicate per-file from per-sample
  out <- merge(df[,c("Sample_Name", "File_Name")], out, by = "Sample_Name", all = T)
  out <- merge(out, translocation.consensus, by = "Sample_Name", all = T)
  # append consensus fields back onto per.file and return
  out <- toolboxR::append_df(df, select(out, -Sample_Name), id = "File_Name")
  
  # log intermediate tables to scratch
  sapply(c("sorted", "conflicted.samples", "longitudinally.inconsistent.patients", 
           "preferred", "translocation.consensus"), write.object, env = environment())
  
  out
}

CleanColumnNamesForSAS <- function(n){
  
  # substitute non-alphanumeric characters
  # n <- gsub("[^[:alnum:]]+", "_", n) # replace and reduce
  n <- gsub("[^[:alnum:]]", "_", n) # simple replacement
  
  
  n <- sapply(n, function(x){
    substr(x,1,32)
  })
  
  if( any(duplicated(n)) ){
    warning(paste("Abbreviated column titles are non-unique:", paste(unique(n[duplicated(n)]), collapse = "; "), sep = " "))
  } else{n}
}


local_collapse_dt <- function(df, column.names, unique = F, conserve.na.columns = T){
  
  dt   <- data.table::as.data.table(df)
  if(conserve.na.columns) dt <- rbindlist(list(dt, as.list(rep("dummy", ncol(dt)))))
  
  # suppress the coersion warning since it is expected
  # <simpleWarning in melt.data.table(dt, id.vars = "Sample_Name", na.rm = TRUE):
  # 'measure.vars' [File_Name, Patient, Study, Study_Phase, ...] are not all of
  # the same type. By order of hierarchy, the molten data value column will be of
  # type 'character'. All measure variables not of type 'character' will be coerced
  # to. Check DETAILS in ?melt.data.table for more on coercion.>
  suppressWarnings(long <- data.table::melt(dt, id.vars = column.names, na.rm = FALSE))
  
  long <- long[, n := length(value), by = c(column.names, "variable")][!is.na(value)]
  
  # filter to remove all NA, blank, or non-duplicated rows
  # remove sample-variable sets that are already unique
  already.unique <- long[n==1]
  duplicated     <- long[n>1]
  
  if(nrow(duplicated) > 0){
    # summarize remaining fields to simplify
    dedup          <- duplicated[, .(value = toolboxR::Simplify(value)), by = c(column.names, "variable", "n")]
    # join and spread
    long <- rbind(already.unique, dedup)
  }else{long <- already.unique}
  
  wide <- data.table::dcast(long,  paste0(paste(column.names, collapse = " + "), " ~ variable") 
                            , value.var = "value")
  # wide <- dplyr::rename_(wide, .dots=setNames("column.names", column.names))
  
  # remove any dummy column conservation rows
  return(wide[get(column.names[1]) != "dummy"])
}




# keep copies of processed data on AWS desktop for easier reading
sync_data_desktop <- function(root.path = "s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData", 
                              local.path = "~/Desktop/ProcessedData/"){
  
  if(!dir.exists(local.path)){stop("local drive not mounted")}
  
  system(  paste('aws s3 sync', 
                 root.path,
                 local.path,
                 # '--exclude "*archive/*"',
                 # '--exclude "*sas/*"',
                 '--delete',
                 # '--dryrun',
                 sep = " "))
}

get_dict <- function(update = T){
  if(update) {
    d <- toolboxR::auto_read(file.path("~/mgp_ngs/Celgene/curation/mgp_dictionary.txt"))
    toolboxR::PutS3Table(object = d, 
                         s3.path = file.path(s3, "ClinicalData/ProcessedData/Resources/mgp_dictionary.txt"))
  }
  toolboxR::GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Resources/mgp_dictionary.txt"))
}

table_flow <- function(write.to.s3 = TRUE, just.master = F){
  PRINTING = write.to.s3 # turn off print to S3 when iterating
  
  # import JointData tables ------------------------------------------------------
  CleanLocalScratch()
  archive(file.path(s3, "ClinicalData/ProcessedData/JointData"))
  system(paste('aws s3 cp',
               file.path(s3, "ClinicalData/ProcessedData/JointData/"),
               local,
               '--recursive --exclude "*" --include "curated*"',
               '--exclude "archive*"', 
               sep = " "))
  
  files      <- list.files(local, full.names = T)
  dts        <- lapply(files, fread)
  dt.names   <- gsub("curated\\.(.*?)[_\\.].*txt", "\\1", tolower(basename(files)))
  if( any(duplicated(dt.names)) )stop("multiple file of the same type were imported")
  names(dts) <- dt.names
  
  ### Filter excluded files ------------------------------------------------------
  valid.files <- dts$metadata[Excluded_Flag == 0 | is.na(Excluded_Flag) ,
                              .(Patient, File_Name)]
  
  master.dts <- lapply(names(dts), function(type){
    dt <- dts[[type]]
    if("File_Name" %in% names(dt)){dt <- dt[File_Name %in% valid.files$File_Name]
    }else if("Patient" %in% names(dt)){dt <- dt[Patient %in% valid.files$Patient]
    }else{stop("table doesn't have a filterable column")}
    
    n    <- paste("curated", type, d, "txt", sep = ".")
    path <- file.path(s3, "ClinicalData/ProcessedData/Master", n)
    if(PRINTING) PutS3Table(dt, path)
    dt
  })
  
  names(master.dts) <- dt.names
  # count excluded rows removed 
  sapply(dts, dim) - sapply(master.dts, dim)
  
  archive(file.path(s3, "ClinicalData/ProcessedData/Master"))
  
  if(just.master) return('Only JointData to Master was processed')
  
  ### Filter ND_Tumor_MM files ---------------------------------------------------
  nd.tumor.files <- master.dts$metadata[Disease_Status     == "ND" & 
                                          Sample_Type_Flag == 1    & 
                                          Disease_Type     == "MM" ,
                                        .(Patient, File_Name)]
  nd.tumor.dts <- lapply(names(master.dts), function(type){
    dt <- master.dts[[type]]
    # if has a file_name use that, else use patient
    if( "File_Name" %in% names(dt) ){
      level <- "per.file"
      dt    <- dt[File_Name %in% nd.tumor.files$File_Name]
    }else{
      level <- "per.patient"
      dt    <- dt[Patient %in% nd.tumor.files$Patient]
    }
    n <- paste(level, type, "nd.tumor", d, "txt", sep = ".")
    path <- file.path(s3, "ClinicalData/ProcessedData/ND_Tumor_MM", n)
    if(PRINTING) PutS3Table(dt, path)
    dt
  })
  names(nd.tumor.dts) <- dt.names
  
  # compare changes after removing relapse files/patients
  sapply(master.dts, dim) - sapply(nd.tumor.dts, dim)
  
  
  ### collapse individual tables to per.patient ----------------------------------
  collapsed.dts <- lapply(names(nd.tumor.dts), function(type){
    
    dt <- local_collapse_dt(nd.tumor.dts[[type]], column.names = "Patient") 
    
    n    <- paste("per.patient", type, "nd.tumor", d, "txt", sep = ".")
    path <- file.path(s3, "ClinicalData/ProcessedData/ND_Tumor_MM", n)
    if(PRINTING) PutS3Table(dt, path)
    dt
  })
  names(collapsed.dts) <- dt.names
  # compare changes after collapse to patients
  sapply(master.dts, dim) - sapply(collapsed.dts, dim)
  
  ### join into unified table -------------------------
  null <- lapply(collapsed.dts, function(dt){
    setkey(dt, Patient)
    if("File_Name" %in% names(dt)) dt[,File_Name:=NULL]
    dt
  })
  
  dt <- collapsed.dts$metadata
  dt <- merge(dt, collapsed.dts$clinical, all = T)
  dt <- merge(dt, collapsed.dts$blood, all = T)
  dt <- merge(dt, collapsed.dts$translocations, all = T)
  
  # sort by dictionary
  dict      <- get_dict()
  matched   <- dict$names[dict$names %in% names(dt)]
  unmatched <- names(dt)[!names(dt) %in% dict$names]
  
  setcolorder(dt, c(matched, unmatched))
  n    <- paste("per.patient", "unified", "nd.tumor", d, "txt", sep = ".")
  path <- file.path(s3, "ClinicalData/ProcessedData/ND_Tumor_MM", n)
  if(PRINTING) PutS3Table(dt, path)
  
  
  # move stale versions to archive subfolder
  archive(file.path(s3, "ClinicalData/ProcessedData/ND_Tumor_MM"))
  
  RPushbullet::pbPost("note", "table_flow() has completed")
}

run_master_inventory <- function(write.to.s3 = TRUE){
  PRINTING = write.to.s3 # turn off print to S3 when iterating
  
  # 2017-04-18 Dan Rozelle
  # 
  # The inventory script uses /Master clinical, metadata, and molecular tables 
  # which have been filtered to remove excluded samples and patients. It write both
  # patient-level inventory matices and study-level count aggregates to a dated 
  # ClinicalData/ProcessedData/Reports file.
  
  # import master tables ------------------------------------------------------
  
  CleanLocalScratch()
  system(paste('aws s3 cp',
               file.path(s3, "ClinicalData/ProcessedData/Master/"),
               local,
               '--recursive --exclude "*" --include "curated*"',
               '--exclude "archive*"', 
               sep = " "))
  f        <- list.files(local, full.names = T)
  dts      <- lapply(f, fread)
  dt.names <- gsub("curated[_\\.]([a-z]+).*", "\\1", tolower(basename(f)))
  if( any(duplicated(dt.names)) )stop("multiple file of the same type were imported")
  names(dts) <- dt.names
  names(dts)
  
  nd <- dts$metadata[Disease_Status == "ND" & Sample_Type_Flag == "1" & 
                       (Disease_Type == "MM" | is.na(Disease_Type)) ,File_Name]
  
  # generate lookup tables for each parameter
  has.demog <- dts$clinical[do.call("|", list(!is.na(D_Gender),   !is.na(D_Age))) ,.(Patient)]
  has.pfsos <- dts$clinical[do.call("|", list(!is.na(D_PFS), !is.na(D_OS))) ,.(Patient)]
  has.iss   <- dts$clinical[!is.na(D_ISS) , .(Patient)]
  under75   <- dts$clinical[!is.na(D_Age)  & D_Age < 75, .(Patient)]
  has.blood <- dts$blood[File_Name %in% nd][do.call("|", list(!is.na(DIAG_Beta2Microglobulin),      !is.na(DIAG_Albumin))) ,.(Patient)]
  
  # NOTE: this includes pateints that only had Relapse results, 
  # you probably want the ND filtered version below
  has.bi    <- dts$biallelicinactivation[do.call("|", list(!is.na(BI_TP53_Flag), !is.na(BI_NRAS_Flag))) ,.(Patient)]
  has.cnv   <- dts$cnv[do.call("|", list(!is.na(CNV_TP53_ControlFreec), !is.na(CNV_NRAS_ControlFreec))) ,.(Patient)]
  has.rna   <- dts$rnaseq[do.call("|", list(!is.na(RNA_ENSG00000141510.16), !is.na(RNA_ENSG00000213281.4))) ,.(Patient)]
  has.snv   <- dts$snv[do.call("|", list(!is.na(SNV_TP53_BinaryConsensus), !is.na(SNV_NRAS_BinaryConsensus))) ,.(Patient)]
  has.trsl  <- dts$translocations[CYTO_Translocation_Consensus %in% c("None", "4", "6", "11", "12", "16", "20")  ,.(Patient)]
  
  has.nd.bi    <- dts$biallelicinactivation[File_Name %in% nd][do.call("|", list(!is.na(BI_TP53_Flag), !is.na(BI_NRAS_Flag))) ,.(Patient)]
  has.nd.cnv   <- dts$cnv[File_Name %in% nd][do.call("|", list(!is.na(CNV_TP53_ControlFreec), !is.na(CNV_NRAS_ControlFreec))) ,.(Patient)]
  has.nd.rna   <- dts$rnaseq[File_Name %in% nd][do.call("|", list(!is.na(RNA_ENSG00000141510.16), !is.na(RNA_ENSG00000213281.4))) ,.(Patient)]
  has.nd.snv   <- dts$snv[File_Name %in% nd][do.call("|", list(!is.na(SNV_TP53_BinaryConsensus), !is.na(SNV_NRAS_BinaryConsensus))) ,.(Patient)]
  has.nd.trsl  <- dts$translocations[File_Name %in% nd][CYTO_Translocation_Consensus %in% c("None", "4", "6", "11", "12", "16", "20")  ,.(Patient)]
  
  # patient-level inventory table  ---------------------------------------------
  inv <- dts$metadata %>% 
    group_by(Study, Patient) %>%
    summarise( 
      INV_Has.ND         = any(Disease_Status == "ND"),
      INV_Has.R          = any(Disease_Status == "R"),
      INV_Has.TumorSample     = any(Sample_Type_Flag == "1"),
      INV_Has.NormalSample    = any(Sample_Type_Flag == "0"),
      INV_Has.ND.TumorSample  = any(paste0(Disease_Status,Sample_Type_Flag) == "ND1"),
      INV_Has.WES        = any(Sequencing_Type == "WES"),
      INV_Has.WGS        = any(Sequencing_Type == "WGS"),
      INV_Has.RNASeq     = any(Sequencing_Type == "RNA-Seq"),
      INV_Has.ND.WES     = any(paste0(Disease_Status,Sequencing_Type) == "NDWES"),
      INV_Has.ND.WGS     = any(paste0(Disease_Status,Sequencing_Type) == "NDWGS"),
      INV_Has.ND.RNASeq  = any(paste0(Disease_Status,Sequencing_Type) == "NDRNA-Seq"),
      INV_Has.R.WES      = any(paste0(Disease_Status,Sequencing_Type) == "RWES"),
      INV_Has.R.WGS      = any(paste0(Disease_Status,Sequencing_Type) == "RWGS"),
      INV_Has.R.RNASeq   = any(paste0(Disease_Status,Sequencing_Type) == "RRNA-Seq"),
      
      INV_Has.Tumor.ND.WES    = any(paste0(Sample_Type_Flag, Disease_Status,Sequencing_Type) == "1NDWES"),
      INV_Has.Tumor.ND.WGS    = any(paste0(Sample_Type_Flag, Disease_Status,Sequencing_Type) == "1NDWGS"),
      INV_Has.Tumor.ND.RNASeq = any(paste0(Sample_Type_Flag, Disease_Status,Sequencing_Type) == "1NDRNA-Seq"),
      INV_Has.Tumor.R.WES    = any(paste0(Sample_Type_Flag, Disease_Status,Sequencing_Type)  == "1RWGS"),
      INV_Has.Tumor.R.WGS    = any(paste0(Sample_Type_Flag, Disease_Status,Sequencing_Type)  == "1RWES"),
      INV_Has.Tumor.R.RNASeq = any(paste0(Sample_Type_Flag, Disease_Status,Sequencing_Type)  == "1RRNA-Seq"),
      
      INV_Has.demog          = any(Patient %in% has.demog$Patient ),
      INV_Has.pfsos          = any(Patient %in% has.pfsos$Patient ),
      INV_Has.iss            = any(Patient %in% has.iss$Patient   ),
      INV_Under75            = any(Patient %in% under75$Patient   ),
      
      INV_Has.blood          = any(Patient %in% has.blood$Patient ),
      INV_Has.nd.bi             = any(Patient %in% has.nd.bi$Patient    ),
      
      INV_Has.cnv            = any(Patient %in% has.cnv$Patient   ),
      INV_Has.rna            = any(Patient %in% has.rna$Patient   ),
      INV_Has.snv            = any(Patient %in% has.snv$Patient   ),
      INV_Has.Translocations = any(Patient %in%  has.trsl$Patient ),
      
      INV_Has.nd.cnv            = any(Patient %in% has.nd.cnv$Patient   ),
      INV_Has.nd.rna            = any(Patient %in% has.nd.rna$Patient   ),
      INV_Has.nd.snv            = any(Patient %in% has.nd.snv$Patient   ),
      INV_Has.nd.Translocations = any(Patient %in%  has.nd.trsl$Patient ),
      
      Cluster.A2    = (INV_Has.ND.TumorSample & 
                         INV_Has.pfsos &
                         INV_Has.nd.cnv & 
                         INV_Has.nd.rna &
                         INV_Has.nd.snv & 
                         INV_Has.nd.Translocations ),
      Cluster.B     = (Cluster.A2 &
                         INV_Has.iss &
                         INV_Under75 & 
                         INV_Has.blood),
      
      
      # UAMS Cluster.C
      # > Start with 1313 WES samples
      # > Keep only samples with copy number data (the ?CopyNumber.Pass? column), which is 1106 samples
      # > We found that patients aged 75 or older perform poorly, so removed them: 916 samples
      # > Required ISS stage data: 831 samples
      # > Survival data required: 800 samples
      
      Cluster.C    = (INV_Has.WES & 
                        INV_Has.nd.cnv &  
                        INV_Under75 &
                        INV_Has.iss &
                        INV_Has.pfsos  ) )%>%
    mutate_if(is.logical, as.numeric)
  
  n <- paste("counts.by.individual", d, "txt", sep = "." )
  if(PRINTING) PutS3Table(inv, file.path(s3, "ClinicalData/ProcessedData/Reports", n))
  
  # study-level matrix --------------------------------------------------------
  per.study.counts <- inv %>% group_by(Study) %>% summarise_if(is.numeric, sum)
  
  aggs <- lapply(list("blood", "clinical", "translocations"), function(type){
    dt <- dts[[type]]
    
    if("File_Name" %in% names(dt)){ 
      dt <- right_join(select(dts$metadata, File_Name, Study), 
                       dt, by = "File_Name") %>%
        group_by(Study) %>%
        summarise_all( funs(INV = sum(!is.na(.)) ))
    }else{
      dt <- right_join(select(dts$metadata, Patient, Study), 
                       dt, by = "Patient") %>%
        group_by(Study)%>%
        summarise_all( funs(INV = sum(!is.na(.)) ))
    }
    names(dt) <- gsub("(.*)_(INV)", "\\2_\\1", names(dt))
    dt
  })
  
  df <- do.call(cbind, c(list(per.study.counts), aggs))
  df <- as.data.frame(t(df), stringsAsFactors = F)
  names(df) <- df[1,]
  df <- df[2:nrow(df),]
  df["Total"] <- apply(df, MARGIN = 1, function(x){sum(as.integer(x))})
  df[grepl("^Study", row.names(df)), "Total"] <- "Total"
  
  df[['Category']] <- row.names(df)
  
  n <- paste("counts.by.study", d, "txt", sep = "." )
  if(PRINTING) PutS3Table(df, file.path(s3, "ClinicalData/ProcessedData/Reports", n), row.names = F, quote = F)
  
  # move stale versions to archive subfolder
  archive(file.path(s3, "ClinicalData/ProcessedData/Reports"))
  
  list(per.patient.counts = inv, 
       per.study.counts = df)
}
export_sas <- function(df){
  
  # this has been adjusted to maintain a very specific export format, edit with care
  # It attempts to retain similarity in variable names and types to <SAS.TEMPLATE_2016-11-23.sas>
  
  # sas column names are very restrictive, and automatically edited if nonconformant
  # 32 char limit only symbol allowed is "_"
  # export to sas automatically replaces each symbol with "_", truncates to 32 but has
  # strange truncation rules (first lower case letters and then trailing upper case letters?)
  # also, use previsouly established names at all cost, this pisses off Biostats ppl
  # clean table names and dictionary names
  
  dict  <- get_dict() %>% filter( sas.name != "")
  
  name2sasname <- setNames(dict$sas.name, dict$names)
  
  # report sas variables we are not exporting
  missing <- paste(names(name2sasname)[!names(name2sasname) %in% names(df)],  
                   collapse = ", ")
  if(missing != "") message(paste("sas variables not exported:", missing))
  
  # select and rename only columns that have sas export names defined in dict
  df <- df[, names(df) %in% names(name2sasname) ]
  names(df) <- name2sasname[names(df)]
  
  # 
  # # Compare with previous export and add back columns that have no info now but 
  # # might will in future analyses
  # p <- "CYTO|FLO|MISC|History"
  # df[,grep(p, setdiff(previous_columns, names(df)), value = T)] <-  NA
  # 
  
  # get a column with type definitions
  types      <- dict[  match(names(df), dict$sas.name), "class"]
  if(any( is.na(types)) ) warning(paste("Column(s):\"", names(df)[is.na(types)], "\" are not defined class in dict", sep = " "))
  
  # coerce each variable
  df <- df %>%
    # convert to appropriate variable type
    mutate_if(types == "numeric",   as.numeric)   %>%
    mutate_if(types == "factor",   as.factor)   %>%
    mutate_if(types == "character" | types == "date", as.character) %>%
    
    # leave NA values explicit and they will be suppressed in export
    mutate_if(types == "character", funs( gsub("^NA$", "", .) ))  %>%
    mutate_if(types == "character", funs( ifelse(is.na(.),"", .) )  ) %>%
    
    # remove all INV counting columns
    select(-c(starts_with("INV")))
  
  # sort columns in dictionary order
  tmp <- df[,dict$sas.name[dict$sas.name %in% names(df)]]
  if( all(dim(tmp) == dim(df)) ){df <- tmp
  }else{ stop("sorted columns didn't retain the same dimensions")}
  
  # export as SAS format
  name <- "unified.nd.tumor"
  root <- paste(name, d, sep = ".")
  local.data.path <- file.path(local, paste0(root,".txt"))
  local.code.path <- file.path(local, paste0(root,".sas"))
  
  foreign::write.foreign(df,
                         datafile = local.data.path,
                         codefile = local.code.path,
                         package="SAS")
  
  # edit sas code table such that empty columns retain character length = 1
  system( paste('sed -i "s/\\$ 0$/\\$ 1/" ', local.code.path, sep = " "))
  
  system(paste('aws s3 cp',
               file.path(local),
               file.path(s3, "ClinicalData/ProcessedData/ND_Tumor_MM/sas/"),
               '--recursive --exclude "*" --include "unified*"',
               '--sse', 
               sep = " "))
  
}

qc_master_tables <- function(log.path = "tmp.log"){
  
  # transfer curated tables from Master directory and test each column 
  # against specific rules as defined in dictionary
  
  
  CleanLocalScratch()
  system(paste('aws s3 cp',
               file.path(s3, "ClinicalData/ProcessedData/Master/"),
               local,
               '--recursive --exclude "*" --include "curated*"',
               '--exclude "archive*"',
               sep = " "))
  f        <- list.files(local, full.names = T)
  dts      <- lapply(f, fread)
  dt.names <- gsub("curated[_\\.]([a-z]+).*", "\\1", tolower(basename(f)))
  if( any(duplicated(dt.names)) )stop("multiple file of the same type were imported")
  names(dts) <- dt.names
  names(dts)
  
  dts <- dts[c(3,5)]
  
  # test functions
  column.exists <- function(x){
    if( !is.null(x) ){ "PASS"
    }else "FAIL"
  }
  
  required <- function(x){
    if( !is.null(x) && all(!is.na(x) & x != "") ){ 
      "PASS"
    }else "FAIL"
  }
  
  log_result <- function(table, column, test, result){
    l <- paste(Sys.time(), result, test, table, column, sep = "\t")  
    write(l, log.path, append = T)
  }
  
  dict <- get_dict()
  unlink(log.path)
  # clean logfile
  lapply(names(dts), function(t){
    
    # filter dictionary for fields in this table
    dict <- dict %>% filter(grepl(t, level))
    
    # iterate through each column
    lapply(dict$names, function(c){
      
      # qc tests
      test.names <- unlist(strsplit(as.character(dict[dict$names == c, "qc.tests"]), 
                                    split = "; "))
      lapply(test.names, function(qc){
        f <- get(qc)
        log_result(t,c,qc,f(dts[[t]][[c]]))
        
      })
    })
  })
  # print FAILED tests
  failed.results <- read.delim(log.path, header = F) %>% 
    filter(V2 == "FAIL") %>% 
    select(-V1) %>%
    rename(Result = V2,
           Test   = V3,
           Table  = V4,
           Column = V5)
  
  # return a table of failed results, make sure any edits are only made to 
  # original JointData and not the filtered Master tables
  failed.results
}

