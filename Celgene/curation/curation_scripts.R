
# global vars
d  <- format(Sys.Date(), "%Y-%m-%d")
s3 <- "s3://celgene.rnd.combio.mmgp.external"
# devtools::install_github("dkrozelle/toolboxR")
library(toolboxR, quietly = T)
library(dplyr) # don't load plyr, it will conflict
library(tidyr)

# this function does not allow specification of directory to 
# prevent inadvertant file deletion 
CleanLocalScratch <- function(){
  path = "/tmp/curation"
  if(dir.exists(path)){system(paste('rm -r', path, sep = " "))}
  dir.create(path)
  path
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

# copies all updated s3 files in a specified directory prefix to an ./Archive subfolder
#  and appends current date
Snapshot <- function( prefix ){
  
  pre     <- system(paste('aws s3 ls', paste0(prefix, "/"), sep = " "), intern = T)
  archive <- system(paste('aws s3 ls', paste0(file.path(prefix, "Archive"),"/"), sep = " "), intern = T)
  
  
  archive.table <- data.frame(
    root    = gsub(".*[0-9] (.*)_[0-9].*","\\1",archive),
    version = gsub(".*_(.*)\\..*","\\1",archive),
    stringsAsFactors = F ) %>%
    group_by(root) %>%
    summarise(latest = max(version))

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
      end    <- file.path(prefix, "Archive", d.name)
      system(paste("aws s3 cp",start, end, "--sse", sep = " "))
      d.name
    }
  }))
  
  out
}
#currently only works for tables (csv, tab-delim txt or xlsx)
GetS3Table <- function(s3.path, cache = F){
  name  <- basename(s3.path)
  local.filename <- file.path("/tmp", name)
  system(  paste('aws s3 cp', s3.path, local.filename, sep = " "))
  df <- toolboxR::AutoRead(local.filename)
  if(cache == FALSE){unlink(local.filename)}
  df
}

#currently only works for tab-delim tables
PutS3Table <- function(object, s3.path, cache = F){
  name  <- basename(s3.path)
  local <- file.path("/tmp", name)
  write.table(object, local, row.names = F, quote = F, sep = "\t")
  
  system(  paste('aws s3 cp', local, s3.path, "--sse", sep = " "))
  if(cache == FALSE){unlink(local)}
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
  n <- gsub("[^[:alnum:]]+", "_", n)
  
  
  n <- sapply(n, function(x){
    substr(x,1,32)
  })
  
  if( any(duplicated(n)) ){
    warning(paste("Abbreviated column titles are non-unique:", paste(unique(n[duplicated(n)]), collapse = "; "), sep = " "))
  } else{n}
}


local_collapse_dt <- function(df, column.names, unique = F){
  
  dt   <- data.table::as.data.table(df)
  
  # suppress the coersion warning since it is expected
  # <simpleWarning in melt.data.table(dt, id.vars = "Sample_Name", na.rm = TRUE):
  # 'measure.vars' [File_Name, Patient, Study, Study_Phase, ...] are not all of
  # the same type. By order of hierarchy, the molten data value column will be of
  # type 'character'. All measure variables not of type 'character' will be coerced
  # to. Check DETAILS in ?melt.data.table for more on coercion.>
  suppressWarnings(long <- data.table::melt(dt, id.vars = column.names, na.rm = TRUE))
  
  # filter to remove all NA, blank, or non-duplicated rows
  # remove sample-variable sets that are already unique
  already.unique <- long[(value != "NA"), n := .N, by = c(column.names, "variable")][n==1, 1:3]
  duplicated     <- long[(value != "NA"), n := .N, by = c(column.names, "variable")][n>1, 1:3]
  
  # summarize remaining fields to simplify
  dedup          <- duplicated[, .(value = toolboxR::Simplify(value)), by = c(column.names, "variable")]
  
  # join and spread
  long <- rbind(already.unique, dedup)
  wide <- data.table::dcast(long, get(column.names) ~ variable, value.var = "value" )
  wide <- dplyr::rename_(wide, .dots=setNames("column.names", column.names))
  wide
  
}
