library(s3r)
library(tidyverse)
library(toolboxR)
source('curation_scripts.R')

s3_set(bucket = "celgene.rnd.combio.mmgp.external", 
       sse = T,
       cwd = "ClinicalData/ProcessedData/")

s3_ls("Cluster.A2")
new <- s3_get_table("Cluster.A2/clinical.subset.2019-02-02.txt")
s3_ls("Cluster.A2/archive", pattern = "clinical")
prev <- s3_get_table("Cluster.A2/archive/clinical.subset.2018-08-15.txt")

compare_versions <- function(new.df, old.df, key){
  quoted_key <- enquo(key)
  
  new.df <- new.df %>%
    gather(key, new, -(!! quoted_key)) %>% 
    mutate(new = if_else(is.na(new),"NA",new))
  
  old.column.order <- names(old.df)
  
  old.df <- old.df %>%
    gather(key, old, -(!! quoted_key))%>% 
    mutate(old = if_else(is.na(old),"NA",old))

  df <- new.df %>% 
    left_join(old.df) %>% 
    rowwise() %>% 
    mutate(joined = if_else(new!=old,paste0(c(old,new),collapse = "|"),as.character(NA))) %>% 
    filter(!is.na(joined)) %>% 
    select(-new,-old) %>%
    ungroup() %>%
    spread(key, joined,fill = "")
  # 
  # # some unpopulated columns may now be missing, add them back
  # missing_cols <- old.column.order[!old.column.order %in% names(df)]
  # df[,missing_cols] <- NA
  # 
  # # return a well sorted table
  # df[,old.column.order]
  df
}

new_rearr <- compare_versions(new,prev,Patient)

sum(!is.na(prev$D_OS))
sum(!is.na(new$D_OS))

sum(!is.na(prev$D_PFS))
sum(!is.na(new$D_PFS))

hist(prev$D_OS, breaks = 20)
hist(new$D_OS, breaks = 20)
