merge_table_files <- function(file1, file2, id = "File_Name"){
  
  df1 <- read.delim(file1, sep = "\t", check.names = F, as.is = T, stringsAsFactors = F)
  df2 <- read.delim(file2, sep = "\t", check.names = F, as.is = T, stringsAsFactors = F)
  
  df <- merge(x = df1, y = df2, by = id, all = T)
  
  if(dim(df)[1] != dim(df1)[1]){warning(paste("merge of",file1,"and",file2 ,"did not retain proper dimensionality", sep = " "))
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

translocation_consensus_building <- function(df, log_file_path = "/tmp/cyto_consensus.log"){
  
  # print a qc debugging log
  lf <- log_file_path
  if(file.exists(lf)) file.remove(lf)
  log_con <- file(lf, open = "a")
  cat(paste("Patient","Translocation","type_flag","conflicting_technique_results", "decision","raw_results","result", sep = "\t"), file = log_con, sep = "\n")
  
  # get a list of translocation consensus calls to make from dictionary
  consensus_fields <- grep("^CYTO_(.*)_CONSENSUS", names(df), value = T)
  consensus_fields <- gsub("^CYTO_(.*)_CONSENSUS", "\\1", consensus_fields)
  id_columns <- names(df) %in% c("Patient", "Sample_Name", "Sample_Type_Flag", "Disease_Status")
  
  for(p in unique(df$Patient)){
    patient_rows <- df$Patient == p
    
    for(t in consensus_fields){
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
        # per.file[per.file$Patient == "MMRF_1016" & per.file$Sample_Type_Flag == 1, c("CYTO_t(4;14)_FISH")]
        
         
         
        # # all
        # by_technique <- list(FISH=c("1"), MANTA="1")
        # # MANTA
        # by_technique <- list(FISH=c("0"), MANTA="1")
        # # none
        # by_technique <- list()
        # # conflict one technique
        # by_technique <- list(FISH=c("1", "0"))
        # # conflict two categories
        # by_technique <- list(FISH=c("1", "0"), MANTA="1")
        # # double conflict
        # by_technique <- list(FISH=c("1", "0"), MANTA=c("1","0"))
        # 
        # 
        # 
        
        
        
        
        
        
        
        
        

        
        # remove NA techniques
        by_technique <- by_technique[!is.na(by_technique)]
        
        print("-------------------------------")
        print(paste(p,t,type_flag, sep = " "))
        print(str(by_technique))
        
        
        # check for consistency groups
        # all techniques and timepoints have the same result
        if( length(unique(unlist(by_technique))) == 1 ){
          # set this values as consensus for this patient and sample type
          print("all")
          decision <- "all"
          result   <- unique(by_technique)
          df[patient_rows & df$Sample_Type_Flag == type_flag, paste("CYTO",t,"CONSENSUS",sep="_")] <- result
          
        }else if(length(unique(unlist(by_technique["MANTA"]))) == 1 & 
                 "MANTA" %in% names(by_technique)){
          # if we have a good MANTA results, use this
          print("manta")
          decision <- "manta"
          result   <- unique(by_technique["MANTA"])
          df[patient_rows & df$Sample_Type_Flag == type_flag, paste("CYTO",t,"CONSENSUS",sep="_")] <- result
          
        }else if(length(unique(unlist(by_technique["ControlFreec"]))) == 1 & 
                 "ControlFreec" %in% names(by_technique)){
          # if we have a good ControlFreec results, use this
          print("cf")
          decision <- "controlfreec"
          result   <- by_technique["ControlFreec"]
          df[patient_rows & df$Sample_Type_Flag == type_flag, paste("CYTO",t,"CONSENSUS",sep="_")] <- result
          
        }else if(length( by_technique ) == 0 ){
          # if we have a good ControlFreec results, use this
          print("no techniques")
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
  
  # write.table(df, "../data/curated/Integrated/consensized.txt", sep = "\t", row.names = F)
  close.connection(log_con)
  df
}