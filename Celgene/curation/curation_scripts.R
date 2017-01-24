# this function does not allow specification of directory to 
# prevent inadvertant file deletion 
CleanLocalScratch <- function(){
  path = "/tmp/curation"
  if(dir.exists(path)){system(paste('rm -r', path, sep = " "))}
  dir.create(path)
  path
}

# write_to_s3integrated <- s3_writer(s3_path = "/ClinicalData/ProcessedData/Integrated/")
# write_to_s3integrated(foo = new, name = "test.txt")
s3_writer <- function(s3_prefix = "s3://celgene.rnd.combio.mmgp.external/", s3_path){
  function(foo, name){
    local_file <- file.path("/tmp",name)
    s3_file <- file.path(gsub("\\/+$","",s3_prefix), gsub("^\\/+|\\/+$","",s3_path), name)
    
    write.table(foo, local_file, row.names = F, col.names = T, sep = "\t", quote = F)
    system(  paste('aws s3 cp', local_file, s3_file , '--sse', sep = " "))
    response <- system('echo $?', intern = T)
    if( response == 0 ){
      unlink(local_file)
    }else{
      warning(paste("Error writing",name, "to S3", sep = " "))
    }
    response
  }
}
write_to_s3integrated <- s3_writer(s3_path = "/ClinicalData/ProcessedData/Integrated/")

# copies all updated s3 files in a specified directory prefix to an ./Archive subfolder
#  and appends current date
Snapshot <- function( prefix ){
  
  pre     <- system(paste('aws s3 ls', paste0(prefix, "/"), sep = " "), intern = T)
  archive <- system(paste('aws s3 ls', paste0(file.path(prefix, "Archive"),"/"), sep = " "), intern = T)
  
  archive.table <- data.frame(
    root    = gsub(".*[0-9] (.*)_[0-9].*","\\1",archive),
    version = gsub(".*_(.*)\\..*","\\1",archive),
    stringsAsFactors = F
  )
  library(plyr)
  archive.table <- ddply(archive.table, .(root), summarise, latest = max(version) )
  
  current.table <- data.frame(
    date  = gsub("^([0-9\\-]+).*","\\1",pre),
    root  = gsub(".* ([^0-9].*)\\..*","\\1",pre),
    path  = gsub(".* ([^0-9].*\\..*)","\\1",pre),
    stringsAsFactors = F
  )
  # only keep well parsed rows
  current.table <- current.table[grepl("[0-9\\-]+", current.table$date),]
  
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

#currently only works for tab-delim tables
GetS3Table <- function(s3.path, cache = F){
  name  <- basename(s3.path)
  local <- file.path("/tmp", name)
  system(  paste('aws s3 cp', s3.path, local, sep = " "))
  df <- read.delim(local, sep = "\t", stringsAsFactors = F)
  if(cache == FALSE){unlink(local)}
  df
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


clean_values <- function(x, delim = "; "){
  # first we need to split any collapsed strings using the delimited
  # get rid of NA fields
  x <- x[!is.na(x)]
  x <- lapply(x, strsplit, split = delim)
  x <- unlist(x)
  
  # chomp each value
  x <- gsub("^\\s+", "", x)
  x <- gsub("\\s+$", "", x)
  
  # remove duplicate values
  if( length(unique(toupper(x))) == length(unique(x)) ){
    x <- unique(x)
  }else{
    x <- unique(toupper(x))
  }
  x[order(x)]
}

# mode
#   append : append any new values to preexisting values using delimiter
#   replace: replace any preexisting values with new value
#   safe   : only write new value if no preexisting value
append_df <- function(main, new, id = "Patient", 
                      mode = "safe", verbose = TRUE, delim = "; "){
  
  if(!id %in% names(new)){
    message(paste0("dataframe does not contain specified id column: ", id))
    return(main)
  }else if(sum(names(new) %in% names(main)) == 1){
    message(paste0("dataframe does not contain additional columns to add"))
    return(main)
  }
  
  # subset new df to only columns in main
  new <- new[,names(new) %in% names(main)]
  
  # add new rows if new patients are found
  if( any(!new[[id]] %in% main[[id]]) ) {
    for(i in unique(new[[id]][!new[[id]] %in% main[[id]]])){
      main[nrow(main)+1,id] <- i 
    }
  }
  
  # add column to force merged sorting
  main[['table']] <- "main"
  new[['table']]  <- "new"
  
  p <- new[[id]]
  n <- names(new)
  
  # extract the rows and columns of main that are in new
  main_subset   <- main[main[[id]] %in% p ,n]
  
  # merge without any "by" arguments duplicates non-identical rows
  m <- merge(main_subset, new, all = T)
  m <- m[ order(m[,id], m[,"table"]), ]
  
  # lapply for each patient, this allows to 
  #  subset to just the rows of a single patient
  l <- lapply(unique(m[[id]]), function(identifier){
    
    # inside the apply, we then perform the merge for each column set
    # x is a character vector of the available values that needs to be collapsed
    a<- apply(m[m[[id]] == identifier, !names(m) %in% c("table")], MARGIN = 2, function(x){
      
      # capture pre-existing vs new values separately
      original_values <- x[1]
      new_values     <- x[2:length(x)]
      had_value      <- !is.na(original_values) & original_values != ""
      has_new_value  <- any(!is.na(new_values)) & any(new_values != "")
      
      original_values <- clean_values(original_values)
      new_values <- clean_values(new_values)
      
      # Cases:
      # if didn't have a value,      return the new value, this works with blank new values too
      # else if value is the same,   return the value
      # else if the mode is append,  join them and return
      # else if the mode is replace, return the new values
      # else if the mode is safe,    return the old value and warning
      # else warning 
      
      if( had_value == FALSE ){
        out <- new_values
      }else if(has_new_value & all(new_values == original_values)){
        out <- new_values
      }else if(mode == "append"){
        out <- clean_values(c(new_values,original_values))
      }else if(mode == "replace"){
        out <- new_values
      }else if(mode == "safe"){
        #TODO: don't warn if replacement is blank.
        warning(paste0("Identifier:", identifier, " has existing value (",paste(original_values, collapse = "; "),"), attempted overwrite with (",paste(new_values, collapse = "; "), ") with safe mode enabled"))  
        out <- original_values
      }else {
        out <- original_values
        warning("Error005 during datamerge")
      }
      
      if(length(out) == 0){out<-NA}
      if(all(is.na(out))){
        out <- NA
      }else{
        out <- paste(out, collapse = delim)
      }
      
      return(out)
    }) 
    
    a <- c(a, table="joined")
    a
  })
  
  updated_fields <- as.data.frame(Reduce(rbind, l), stringsAsFactors = F)
  # updated_fields[[id]] <- unique(m[[id]])
  # updated_fields <- updated_fields[, n]
  
  main <- main[ order(main[[id]]), ]
  updated_fields <- updated_fields[ order(updated_fields[[id]]), ]
  
  main[main[[id]] %in% p, n] <- updated_fields
  # field_update_count
  main$table <- NULL
  
  
  return(main)
}

cytogenetic_consensus_calling <- function(df, log_file_path = "/tmp/cyto_consensus.log"){
  
  # this script performs 3 sequential functions
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
  
  # df <- per.file
  
  # print a qc debugging log
  lf <- log_file_path
  if(file.exists(lf)) file.remove(lf)
  log_con <- file(lf, open = "a")
  cat(paste("Patient","Translocation","type_flag","conflicting_technique_results", "decision","raw_results","result", sep = "\t"), file = log_con, sep = "\n")
  
  # get a list of translocation consensus calls to make from dictionary
  # Since the translocations should be mutually exclusive we'll call them separately
  translocations <- grep("^CYTO_(t.*)_CONSENSUS", names(df), value = T)
  translocations <- gsub("^CYTO_(t.*)_CONSENSUS", "\\1", translocations)
  
  id_columns <- names(df) %in% c("Patient", "Sample_Name", "Sample_Type_Flag", "Disease_Status")
  
  ### STEP 1
  ### Translocation consensus calls
  for(p in unique(df$Patient)){
    patient_rows <- df$Patient == p
    
    for(t in translocations){
      # get a list of techniques to compare
      techniques <-grep(t, names(df), value = T, fixed = T)
      techniques <- gsub(paste0("CYTO_",t,"_"),"",techniques, fixed = T)
      techniques <- techniques[!(techniques %in% "CONSENSUS")]
      # c("FISH", "MANTA")
      
      for(type_flag in c(0,1)){
        df_sub <- df[patient_rows & df$Sample_Type_Flag == type_flag, id_columns | grepl(t, names(df), fixed = T)]
        
        # get a list of all unique values for each technique
        by_technique <- lapply(techniques, function(technique){
          if(all(is.na(df_sub[,grepl(technique, names(df_sub))]))){return(NA)
          }else{
            unique(df_sub[,grepl(technique, names(df_sub))][!is.na(df_sub[,grepl(technique, names(df_sub))])])
          }
        })
        names(by_technique) <- techniques
        
        # remove NA techniques
        by_technique <- by_technique[!is.na(by_technique)]
        
        # check for consistency groups
        # all techniques and timepoints have the same result
        if( length(unique(unlist(by_technique))) == 1 ){
          # set this values as consensus for this patient and sample type
          decision <- "all"
          result   <- unique(by_technique)
          df[patient_rows & df$Sample_Type_Flag == type_flag, paste("CYTO",t,"CONSENSUS",sep="_")] <- result
          
        }else if(length(unique(unlist(by_technique["MANTA"]))) == 1 & 
                 "MANTA" %in% names(by_technique)){
          # if we have a good MANTA results, use this
          decision <- "manta"
          result   <- unique(by_technique["MANTA"])
          df[patient_rows & df$Sample_Type_Flag == type_flag, paste("CYTO",t,"CONSENSUS",sep="_")] <- result
          
        }else if(length(unique(unlist(by_technique["ControlFreec"]))) == 1 & 
                 "ControlFreec" %in% names(by_technique)){
          # if we have a good ControlFreec results, use this
          decision <- "controlfreec"
          result   <- by_technique["ControlFreec"]
          df[patient_rows & df$Sample_Type_Flag == type_flag, paste("CYTO",t,"CONSENSUS",sep="_")] <- result
          
        }else if(length( by_technique ) == 0 ){
          # if we have a good ControlFreec results, use this
          decision <- "no techniques"
          result   <- NA
          df[patient_rows & df$Sample_Type_Flag == type_flag, paste("CYTO",t,"CONSENSUS",sep="_")] <- result
          
        }else{
          decision <- "ERROR"
          result   <- NA
          df[patient_rows & df$Sample_Type_Flag == type_flag, paste("CYTO",t,"CONSENSUS",sep="_")] <- result
        }
        
        # provide unique values for each technique
        raw_results <- paste(mapply(function(x,y){
          paste(x,y,sep = "=")
        }, names(by_technique), as.character(by_technique)),
        collapse = "; ")
        
        conflicting_technique_results <- length(unique(by_technique)) >1
        
        cat(paste(p,t,type_flag,conflicting_technique_results,decision,raw_results,result, sep = "\t"), file = log_con, sep = "\n")
      }
    }
  }
  
  ### STEP 2
  ### Mutually exclusive translocation calls
  tcalls <- c()
  patient_type_table <- unique(df[,c("Patient", "Sample_Type_Flag")])
  
  CYTO_Translocation_Consensus <- apply(patient_type_table, MARGIN = 1, function(x){
    
    patient_rows <- (df$Patient == x[['Patient']]) & (df$Sample_Type_Flag == x[['Sample_Type_Flag']])
    tmp <- df[patient_rows,  grepl("^CYTO_(t.*)_CONSENSUS", names(df))]
    
    # determine if each translocation had been called by any individual sample
    type <- apply(tmp, MARGIN = 2, function(x){
      any(!is.na(x) & x == 1)
    })
    
    if(sum(type) == 1){ 
      colname <- names(type)[type]
      trsl <- gsub("CYTO_t\\((.*)\\)_CONSENSUS","\\1",colname)
      trsl <- gsub(";14|14;","",trsl)
    }else if(sum(type) == 0){
      trsl <- ""
    }else if(sum(type) > 1){
      trsl <- "ERROR2"
    }else{
      trsl <- "ERROR1"
    }
    trsl
    
  })
  
  # merge the translocation call column back onto teach pateient/sampletype
  df$CYTO_Translocation_Consensus <- NULL
  call_lookup <-   cbind(patient_type_table, CYTO_Translocation_Consensus)
  tmp <- merge(df, call_lookup, by = c("Patient", "Sample_Type_Flag"), all = T)
  
  if(dim(tmp)[1] == dim(df)[1]) {
    df <- tmp
    rm(tmp)
  }else{warning('dimensions do not match between the merged table and file table')}
  
  ### STEP 3
  ### Other cytogenetic consensus calls
  
  # other deletions and amplifications are called on a sample bases and do not need longitudinal harmony
  other_cyto <- grep("^CYTO_([da1HM].*)_CONSENSUS", names(df), value = T)
  other_cyto <- gsub("^CYTO_([da1HM].*)_CONSENSUS", "\\1", other_cyto)
  
  # t<-"amp(1q)"
  for(t in other_cyto){
    # get a list of techniques to compare
    columns <- grep(t, names(df), value = T, fixed = T)
    columns <- grep("CONSENSUS", columns, invert = T, value = T)
    techniques <- gsub(paste0("CYTO_",t,"_"),"",columns, fixed = T)
    # c("FISH", "MANTA")
    
    # reconstruct column names to order by technique priority
    
    
    consensus <- apply(df[, columns], MARGIN = 1, function(x){
      
      # table is organized with "better" techniques to the right
      # FISH < MANTA < ControlFreec
      
      # remove NA value
      x <- x[!is.na(x)]
      
      # if any are remaining return the last element
      if( length(x) > 0 ){return(x[length(x)])
      }else({return(NA)})
      
    })    
    
    df[[paste("CYTO",t,"CONSENSUS" , sep="_")]] <- consensus
    
  }  
  
  close.connection(log_con)
  df
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
  n <- gsub("[^[:alnum:]]", "_", n)
  
  
  n <- sapply(n, function(x){
    substr(x,1,32)
  })
  
  if( any(duplicated(n)) ){
    warning(paste("Abbreviated column titles are non-unique:", paste(unique(n[duplicated(n)]), collapse = "; "), sep = " "))
  } else{n}
}
