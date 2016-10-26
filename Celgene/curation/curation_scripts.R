
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
  
  field_update_count <<- 0
  # lapply for each patient, this allows to 
  #  subset to just the rows of a single patient
  l <- lapply(unique(m[[id]]), function(identifier){
    
    # inside the apply, we then perform the merge for each column set
    # x is a character vector of the available values that needs to be collapsed
    a<- apply(m[m[[id]] == identifier, !names(m) %in% c("table")], MARGIN = 2, function(x){
      field_update_count <<- field_update_count + 1
      
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
  updated_fields[[id]] <- unique(m[[id]])
  updated_fields <- updated_fields[, n]
  main[main[[id]] %in% p ,n] <- updated_fields
  # field_update_count
  main$table <- NULL
  
  
  return(main)
}

