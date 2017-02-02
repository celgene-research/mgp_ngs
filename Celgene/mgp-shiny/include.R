#currently only works for tab-delim tables
GetS3Table <- function(s3.path, cache = F){
  name  <- basename(s3.path)
  local <- file.path("/tmp", name)
  system(  paste('aws s3 cp', s3.path, local, sep = " "))
  df <- read.delim(local, sep = "\t", stringsAsFactors = F)
  if(cache == FALSE){unlink(local)}
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

