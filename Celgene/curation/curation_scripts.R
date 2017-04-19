
# global vars
d  <- format(Sys.Date(), "%Y-%m-%d")
s3 <- "s3://celgene.rnd.combio.mmgp.external"
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


# This script is meant to facilitate generation of all downstream tables derived
# from a basic per.patient and per.file table. This includes joining to molecular 
# data tables to create "all" versions, filtering for "nd.tumor" versions, collapsing 
# to per.sample versions, and generating a single unified output table for sas.
# 
# This is run without any parameter, just make sure you PutS3Table() any changes to 
# <per.file.clinical.txt> or <per.patient.clinical.txt> before running.

table_process <- function(){
  
  source("qc_and_summary.R")
  per.file    <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Integrated", "per.file.clinical.txt"))
  per.patient <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Integrated", "per.patient.clinical.txt"))
  
  ### Merge and filter tables ----------------------------------------------------
  
  per.patient           <- remove_unsequenced_patients(per.patient, per.file)
  per.patient.clinical  <- per.patient # rename for clarity
  per.file.clinical     <- per.file    # rename for clarity
  
  per.file.all          <- table_merge(per.file.clinical)
  
  # kill here
  per.file.all          <- remove_invalid_samples(per.file.all)
  
  # update inventory flags to per.patient after table merge since patient inventory flags
  #  are not applicable to per-file rows
  per.patient.clinical  <- add_inventory_flags(per.patient.clinical, per.file.clinical)
  
  # Collapse file > sample for some analyses
  per.sample.all        <- local_collapse_dt(per.file.all, column.names = "Sample_Name")
  per.sample.clinical   <- subset_clinical_columns(per.sample.all)
  
  # Filter for ND-tumor sample only
  per.file.all.nd.tumor         <- subset(per.file.all,   Sample_Type_Flag == 1 & Disease_Status == "ND")
  per.sample.all.nd.tumor       <- subset(per.sample.all, Sample_Type_Flag == 1 & Disease_Status == "ND")
  per.patient.clinical.nd.tumor <- subset(per.patient.clinical, INV_Has.ND.NotNormal.sample == 1)
  
  # Select clinical column subsets
  per.file.clinical.nd.tumor    <- subset_clinical_columns(per.file.all.nd.tumor)
  per.sample.clinical.nd.tumor  <- subset_clinical_columns(per.sample.all.nd.tumor)
  
  # if you just want to generate a new unified table you can uncomment
  # per.file.clinical.nd.tumor    <- GetS3Table(file.path(s3, 
  # "ClinicalData/ProcessedData/Integrated", "per.file.clinical.nd.tumor.txt"))
  # per.patient.clinical.nd.tumor <- GetS3Table(file.path(s3, 
  # "ClinicalData/ProcessedData/Integrated", "per.patient.clinical.nd.tumor.txt"))
  
  # make a unified table (file and patient variables) for nd.tumor data
  unified.clinical.nd.tumor <- per.file.clinical.nd.tumor %>%
    group_by(Study, Patient) %>%
    summarise_all(.funs = funs(Simplify(.))) %>%
    ungroup() %>%
    select(Patient, Study_Phase, Visit_Name, Sample_Name, Sample_Type, Sample_Type_Flag, Sequencing_Type, Disease_Status, Tissue_Type:CYTO_t.14.20._CONSENSUS) %>%
    full_join(per.patient.clinical.nd.tumor, ., by = "Patient") %>%
    select(-c(starts_with("INV"))) %>%
    filter(Disease_Type == "MM" | is.na(Disease_Type))
  
  
  # write un-dated PER-FILE and PER-PATIENT files to S3
  write_to_s3integrated <- function(object, name){
    PutS3Table(object = object, s3.path = file.path(s3,"ClinicalData/ProcessedData/Integrated", name))
  }
  write_to_s3integrated(per.file.clinical              ,name = "per.file.clinical.txt")
  write_to_s3integrated(per.file.clinical.nd.tumor     ,name = "per.file.clinical.nd.tumor.txt")
  write_to_s3integrated(per.file.all                   ,name = "per.file.all.txt")
  write_to_s3integrated(per.file.all.nd.tumor          ,name = "per.file.all.nd.tumor.txt")
  
  write_to_s3integrated(per.sample.clinical            ,name = "per.sample.clinical.txt")
  write_to_s3integrated(per.sample.clinical.nd.tumor   ,name = "per.sample.clinical.nd.tumor.txt")
  write_to_s3integrated(per.sample.all                 ,name = "per.sample.all.txt")
  write_to_s3integrated(per.sample.all.nd.tumor        ,name = "per.sample.all.nd.tumor.txt")
  
  write_to_s3integrated(per.patient.clinical           ,name = "per.patient.clinical.txt")
  write_to_s3integrated(per.patient.clinical.nd.tumor  ,name = "per.patient.clinical.nd.tumor.txt")
  
  write_to_s3integrated(unified.clinical.nd.tumor      ,name = "unified.clinical.nd.tumor.txt")
  
  RPushbullet::pbPost("note", title = "table_process done")  
}






write.object <- function(x, path = local, env){
  if( is.environment(env)){  
    df <- get(x, envir = env)
  }else{
    df <- get(x)
  }
  write.table(df, 
              file.path(path, paste0(x,".txt")), 
              sep = "\t", 
              row.names = F, 
              col.names = T, 
              quote = F   )
  file.path(path, paste0(x,".txt"))
}

# copies all updated s3 files in a specified directory prefix to an ./archive subfolder
#  and appends current date.
#  Currently will not work for similar named files only differentiated by extension
Snapshot <- function( prefix ){
  
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


merge_table_files <- function(df1, df2, id = "File_Name"){
  
  df <- merge(x = df1, y = df2, by = id, all = T)
  
  if(dim(df)[1] != dim(df1)[1]){
    warning(paste("merge of did not retain proper dimensionality", sep = " "))
    # print ids of additional columns
    print( df[!(df$id %in% df1$id) ,id])
    return(df)
  }else{df}
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

#' Check for explicit value in df
#'
#' A helper function to build df-specific search tools.
#' These functions are typically used in conjunction with lapply to
#' determine if they are present in a df.
#'
#' Important: since both the child function accepts multiple arguments (...) when
#'            it is built with multiple ids, you must explicitly refer to additional
#'            variables my name (dat, field, value). Without them the function
#'            returns NA even with valid queries.
#'
#' @param X Search term
#' @param dat a lookup table data frame with both "id" and "field" columns
#' @param field the search column name
#' @param value the value to match
#' @param exclude return the inverse logical value.
#' @param unique_match If the combination of specified search terms return multiple
#'                    fields this function will return TRUE by default if ANY match
#'                    the supplied value. Specify unique_match = TRUE to require a
#'                    single field to be identified before comparison.
#' @return logical
#' @export
#' @examples
#'   df <- data.frame(Patient.ID = c("p1", "p1", "p2", "p2", "p3"),
#'                    Visit      = c(1,     2,    1,    2,    NA),
#'                    Test.Result= c("neg","pos","neg", NA,   "pos"),
#'                    stringsAsFactors = F)
#'
#'   check_value_by_patient_id <- check.value("Patient.ID")
#'   check_value_by_patient_id("p1", dat = df, field = "Test.Result", value = "pos")
#'   # TRUE
#'   check_value_by_patient_id("p1", df, "Test.Result", "pos")
#'   # returns NA inappropriately
#'   check_value_by_patient_id("p2", dat = df, field = "Test.Result", value = "pos")
#'   # FALSE
#'
#'   check_by_id_and_visit <- check.value(c("Patient.ID", "Visit"))
#'   check_by_id_and_visit("p2", 1, dat = df, field = "Test.Result", value = "pos")
#'   # FALSE
#'   check_by_id_and_visit("p3", NA, dat = df, field = "Test.Result", value = "pos")
#'   # NA
check.value <- function(ids){
  function(..., dat, field, value, fixed_pattern = F, unique_match = T){
    tryCatch({
      query <- c(...)
      # check arguments
      if( !all(ids %in% names(dat)) ){warning("Specified filter columns do  not exist in lookup table")}
      if( !is.data.frame(dat) ){warning("Lookup table not supplied")}
      if( !field %in% names(dat) ){warning("Specified *field* does not exist in lookup table")}
      if( value == ""){warning("Lookup *value* not supplied")}
      
      #if blank or NA filter terms are supplied return NA
      if(any( c(NA, "") %in% query)) {return(NA)}
      
      # create logical lists for each dat[[id]]==X selection set and combine
      opts <- mapply(ids, query, FUN = function(i,x){ dat[[i]] == x }, SIMPLIFY = F)
      selector <-  Reduce("&", opts)
      # check for unique field match
      if(unique_match & sum(selector) > 1){
        warning(paste0("Multiple rows were matched for ",query," with unique_match required "))}
      
      return(any(grepl( value, dat[[field]][selector], ignore.case = T, fixed = fixed_pattern)))
    },error=function(e){NA})
  }
}



#######################################################
#' Generate function to fetch the value from specified row/column
#'
#' A helper function to build df-specific search tools.
#' These functions are typically used in conjunction with lapply to
#' determine if they are present in a df.
#'
#' @param id Used during function creation to customize which df columns
#'            are used for search. This can be a vector.
#' @param X Search term, this can be a vector
#' @param dat a data frame with both "id" and "field" columns
#' @param field the search column name
#' @return value from field corresponding to search terms. This function
#'         can select multiple field values that are collapsed with
#'         separator to conserve dimensionality
#' @export
#' @examples
#'   df <- data.frame(Patient.ID = c("p1", "p1", "p2", "p2", "p3"),
#'                    Visit      = c(1,     2,    1,    2,    NA),
#'                    Test.Result= c("neg","pos","neg", NA,   "pos"),
#'                    stringsAsFactors = F)
#'    lookup_by_patientid <- lookup.values("Patient.ID")
#'    lookup_by_patientid("patient2", df, "Test.Result")
#'    # "negative"
#'    lookup_by_patientid("patient1", df, "Test.Result")
#'    # "negative; positive"
#'
#'    lookup_by_id_and_visit <- lookup.values(id = c("Patient.ID", "Visit"))
#'    lookup_by_id_and_visit(X = c("patient1", 2), dat = df, field = "Test.Result")
#'    # "positive"
#'
#'    # get results for all patients on their first visit
#'    p <- strsplit(paste(unique(df$Patient.ID),1, sep = ";"), split = ";")
#'    unlist(lapply(p, lookup_by_id_and_visit, dat = df, field = "Test.Result"))
#'    # "negative" "negative"
lookup.values <- function(id) {
  function(..., dat, field, separator = "; ") {
    tryCatch({
      
      #if blank or NA search terms are supplied return NA
      if(any( c(NA, "") %in% c(...))) {return(NA)}
      
      # create logical lists for each dat[[id]]==X selection set
      opts <- mapply(id, c(...), FUN = function(i,x){ dat[[i]] == x }, SIMPLIFY = F)
      # reduce multiple lists to a single logical selector
      selector <-  Reduce("&", opts)
      
      # this function does have the potential to select multiple fields that
      #  must be merged before return to conserve proper dimensionality
      foo <- dat[[field]][selector]
      # return NA if that's all there is
      if(all(is.null(foo))){return(NA)}
      if(all(is.na(foo))){return(NA)}
      # remove blank elements
      foo <- foo[foo != ""]
      # reduce to case-insensitive unique elements, only capitalize if there are case differences
      if(!identical(toupper(unique(foo)),unique(toupper(foo)))){ foo <- toupper(foo)}
      paste(unique(na.exclude(foo)), collapse = separator)
    },error=function(e){NA})
  }
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


# Supports both quoted/unquoted values but value cannot include delimiters 
parse_keyvals <- function(x){
  
  # assume quoted values
  foo   <- unlist(strsplit(x, split = "; "))
  
  y <- gsub(  "^(.*?)=[\\\"]*(.*?)[\\\"]*$", "\\2", foo)
  names(y) <- gsub(  "^(.*?)=[\\\"]*(.*?)[\\\"]*$", "\\1", foo)
  y
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

# 
# mutate_cond Create a simple function for data frames or data tables that can 
# be incorporated into pipelines. This function is like mutate but only acts on 
# the rows satisfying the condition:
# 
#  usage: DF %>% mutate_cond(measure == 'exit', qty.exit = qty, cf = 0, delta.watts = 13)
#  
mutate_cond <- function(.data, condition, ..., envir = parent.frame()) {
  condition <- eval(substitute(condition), .data, envir)
  .data[condition, ] <- .data[condition, ] %>% mutate(...)
  .data
}

table_merge <- function(per.file){
  # this function performs a cbind operation of molecular data
  # CNV, BI, SNV, and RNA-Seq counts to the per.file table
  
  
  s3joint    <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/JointData"
  system(paste('aws s3 cp', s3joint, local, '--recursive --exclude "*" --include "curated*" --exclude "archive*"', sep = " "))
  
  #######################
  df    <-  as.data.table(per.file)
  setkey(df, File_Name)
  
  #######################
  files <- list.files(local, pattern = "^curated", full.names = T)
  new        <- lapply(files, fread)
  names(new) <- gsub("curated_(.*?)_.*", "\\1", tolower(basename(files)))
  
  # Check that all tables have a File_Name column
  if( !all(sapply(new, function(x){"File_Name" %in% names(x)})) ){
    stop("At least one curated table is missing the File_Name column")}
  
  lapply(new, setkey, File_Name)
  
  #######################
  
  all <- df
  for( i in new ){
    all <- merge(all, i, all.x=TRUE)  
  }  
  
  # verify all column added
  sum(sapply(c(list(per.file = df), new), dim)[2,]) - length(new)
  
  # verify no new rows added to curated per.file table
  dim(df)[1] == dim(all)[1]
  
  # export table of rows that were not incorporated
  lapply(1:length(new), function(i){
    unmatched <- new[[i]][!File_Name %in% df$File_Name]
    name      <- paste0("unmatched_during_table_merge_", names(new)[i], ".txt")
    PutS3Table(unmatched, file.path(s3, "ClinicalData/ProcessedData/JointData", name))
    dim(unmatched)[1]
  })
  
  return(all)
}

subset_clinical_columns <- function(df){
  # remove genomic columns
  remove_prefix <- c("SNV", "CNV", "BI")
  n <- names(df)
  for(p in remove_prefix){
    n <- n[ !grepl(p, n) ]
  }
  df <- df[, n]
  df
}

dict <- function(update = T){
  if(update) {
    d <- toolboxR::auto_read(file.path("~/mgp_ngs/Celgene/curation/mgp_dictionary.txt"))
    toolboxR::PutS3Table(object = d, 
                         s3.path = file.path(s3, "ClinicalData/ProcessedData/Integrated/mgp_dictionary.txt"))
    }
  toolboxR::GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Integrated/mgp_dictionary.txt"))
  }