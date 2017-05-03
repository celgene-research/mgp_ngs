
# global vars
d  <- format(Sys.Date(), "%Y-%m-%d")
s3 <- "s3://celgene.rnd.combio.mmgp.external"

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

copy.s3.to.local <- function (s3.path, aws.args = "", local.path = local){
  system(paste("aws s3 cp", s3.path, local.path, aws.args, sep = " "))
}

# copies all updated s3 files in a specified directory prefix to an ./archive subfolder
#  and appends current date.
#  Currently will not work for similar named files only differentiated by extension
archive <- function( prefix ){
  
  pre     <- system(paste('aws s3 ls', paste0(prefix, "/"), sep = " "), intern = T)
  archive <- system(paste('aws s3 ls', paste0(file.path(prefix, "archive"),"/"), sep = " "), intern = T)
  
  # summarize what is already archived
  archive.table <- data.frame(
    root    = gsub(".*[0-9] (.*)_[0-9].*","\\1",archive),
    version = gsub(".*_(.*)\\..*","\\1",archive),
    stringsAsFactors = F ) %>%
    group_by(root) %>%
    summarise(latest = max(version))
  
  #summarize the current file versions to see if anything is newer than the archive version
  current.table <- data.frame(
    date  = gsub("^([0-9\\-]+).*","\\1",pre),
    root  = gsub(".* ([^0-9].*)\\..*","\\1",pre),
    path  = gsub(".* ([^0-9].*\\..*)","\\1",pre),
    stringsAsFactors = F   ) %>%
    filter(grepl("^2", date))
  
  out <- unlist(lapply(current.table$root, function(x){
    version <- current.table[current.table$root == x,"date"]
    archive <- archive.table[archive.table$root == x,"latest"]
    if( (length(archive) == 0) || (version >= archive) ){
      
      name   <- current.table[current.table$root == x,"path"]
      d.name <- gsub("(.*)(\\..*)",  paste0("\\1_",d,"\\2"), name)
      start  <- file.path(prefix, name)
      end    <- file.path(prefix, "archive", d.name)
      system(paste("aws s3 cp",start, end, "--sse", sep = " "))
      d.name
    }
  }))
  
  out
}



cytogenetic_consensus_calling <- function(df){
  
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

dict <- function(update = T){
  if(update) {
    d <- toolboxR::auto_read(file.path("~/mgp_ngs/Celgene/curation/mgp_dictionary.txt"))
    toolboxR::PutS3Table(object = d, 
                         s3.path = file.path(s3, "ClinicalData/ProcessedData/Resources/mgp_dictionary.txt"))
    }
  toolboxR::GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Resources/mgp_dictionary.txt"))
  }