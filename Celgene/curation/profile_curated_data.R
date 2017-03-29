### Dan Rozelle, PhD
### drozelle@ranchobiosciences.com
### 2017-02-22
### 
### R-Script to generate formatted summary statistics for a curated dataset. 
### Before running you need two objects:
### 
### df    a data frame with curated columns
### 
### dict  a second dataframe minimally with three columns: 
###  -> names    = column names in df
###  -> class = data type for db.column
###  -> restrictions = what type of summary you'd like
###  
###  Currently we can handle 6 class-restriction pairs
###   numeric-categorical    (e.g. 0=no; 1=yes)
###   numeric-continuous     (0, 1.2, 7e3)
###   character-categorical  (BM; PB)
###   character-pattern      ("GSM[0-9]+\\-[0-9]+") # experimental
###   character-details      ("unformatted text") 
###   date                   ("YYYY-mm-dd")
###   
###   Note: leave "restrictions" column blank for 
###         numeric-continuous and character-details types.

library(dplyr)
# install.packages("ggplot2")
library(ggplot2)

# devtools::install_github("wilkelab/cowplot")
library(cowplot)


profile_curated_data <- function(df, dict){
  
  set.seed(1)
  options(stringsAsFactors = F)
  
  # iterate through all df columns, each generates an applicable summary table,
  # and bind resulting list of df
  blocks <- lapply(names(df), function(x){
    
    # get the dictionary values
    meta         <- as.character(dict %>% filter(names == x) %>% select(class, restrictions))
    Class        <- meta[1]
    Restrictions <- meta[2]
    error.frame <- data.frame(Name = x, Class = Class, Category = "", Summary = "error", Notes = "")
    
    # check if the column is in the dictionary
    if( !(x %in% dict$names) ){
      error.frame$Notes <- "column name not in dictionary"
      return(error.frame) 
    }else if (  all(is.na(df[[x]]))  ) {
      error.frame$Notes <- "all values are NA"
      return(error.frame)   
    }
    
    
    
    # calculate a few parameters
    n.total     <- nrow(df)
    # print(paste(x, Class, sep = " - "))
    
    if( Class == "numeric" ){
      if( !is.numeric(df[[x]]) ){
        error.frame$Notes <- "variable not numeric type as specified"
        error.frame
      }else if ( !is.na(Restrictions) ) {
        
        ### numeric-categorical--------------------
        
        # values <- parse_keyvals(Restrictions)
        # unique(df[[x]])[!(unique(df[[x]]) %in% names(values))]
        
        df %>%
          count_( x) %>%
          mutate( Pct = n/nrow(df),
                  Summary = paste0(n, " (", sprintf("% .1f", Pct*100),"% )") ) %>%
          select_("Category" = x, "Summary") %>%
          mutate(Name = x, Class = Class, Notes = "")
        
      }else{
        ### numeric-continuous--------------------
        n.number  <- sum( !is.na(df[,x]) )
        n.NA      <- sum(  is.na(df[,x]) )
        
        s <- summary(df[[x]])
        data.frame(Name     = x,
                   Class    = Class,
                   Category = c("n", "NA", "range", "mean", "median"),
                   Summary = c(
                     # "4 ( 17.4% )"
                     paste0(n.number, " (", sprintf("% .1f", n.number/n.total*100),"% )"),
                     paste0(n.NA, " (", sprintf("% .1f", n.NA/n.total*100),"% )"),
                     
                     
                     # "35 - 85"
                     paste(s[['Min.']],s[['Max.']], sep = " - "),
                     s[['Mean']],
                     s[['Median']]
                   ),Notes = ""
        )
      }
    }else if( Class == "character" ){
      if( !is.character(df[[x]]) ){
        error.frame$Notes <- "variable not character class as specified"
        error.frame
      }else if ( !is.na(Restrictions) ) {
        
        ### character-categorical--------------------    
        df %>%
          count_( x ) %>%
          mutate( Pct = n/nrow(df) ,
                  Summary = paste0(n, " (", sprintf("% .1f", Pct*100),"% )") ) %>%
          select_("Category" = x, "Summary") %>%
          mutate(Name = x, Class = Class, Notes = "") 
        
      }else {
        ### character-details--------------------
        data.frame(Name = x, 
                   Class = Class, 
                   Category = "example:", 
                   Summary =  as.character(df %>% 
                                             select_(x) %>% 
                                             filter(!is.na(.)) %>% 
                                             filter( . != "" ) %>% 
                                             sample_n(1)),
                   Notes = ""
        )
      }
      
      
      
      
      
      
      
      
      
      
    }else if (Class == "date") {
      ### character-date--------------------
      # parse date, throw error if any fail (previous NAs are ok)
      tryCatch({ 
        d <- lubridate::ymd(df[[x]]) 
        # data.frame(Name = x, Class = Class, Category = "", Summary = "good")
        
        s <- summary(d)
        
        data.frame(
          Name     = x,
          Class    = Class,
          Category = c("n", "range", "mean", "median", NA),
          Summary = c(
            paste0(sum(!is.na(d)), " ( ", sum(!is.na(d))/nrow(df)*100,"% )"), 
            paste(s[['Min.']],s[['Max.']], sep = " to "),
            format(s[['Mean']], date.format),
            format(s[['Median']], date.format),
            sum(is.na(d))),
          Notes = ""    
        )
        
      } ,warning = function(w){
        error.frame
      }
      )
    }else{
      # else ----------------------------------
      error.frame    
    }
    
    
  })
  
  # Join, filter, clean list of summary df objects
  blocks <- blocks[!is.na(blocks)]
  out <- do.call(rbind, blocks)
  out[['sort']] <- 1:nrow(out)
  out[duplicated(out$Name),c("Name", "Class")] <- ""
  out <- select(out, Name, Category, Summary, Notes)
  out
  # 
  # write.table(out, "../data/MOL_study/MOL_QC_table.txt", sep = "\t", 
  #             col.names = T, row.names = F, quote = F)
}


