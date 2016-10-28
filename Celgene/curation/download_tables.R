s3clinical      <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData"
local_path      <- "~/thindrives/mmgp/data/curated"

if(!dir.exists(local_path)){warning("local drive not mounted")}


# We are editing the dictionary spreadsheet locally, so push latest to s3
files <- system(  paste('aws s3 ls',file.path(s3clinical,"ProcessedData","Integrated/"), sep = " "), intern = T)

#trim to filename, this assumes no spaces in filename
files <- gsub("^.* (.*)","\\1",files)

file_includes <- '--exclude "*"'
file_includes <- paste(file_includes, "--include", tail(grep("PER-FILE", files, value = T), n=1), sep = " ")
file_includes <- paste(file_includes, "--include", tail(grep("PER-PATIENT", files, value = T), n=1), sep = " ")
file_includes <- paste(file_includes, "--include", tail(grep("PER-SAMPLE", files, value = T), n=1), sep = " ")
file_includes <- paste(file_includes, "--include", tail(grep("dictionary", files, value = T), n=1), sep = " ")
file_includes

#download the most recent integrated files
system(  paste('aws s3 cp',integrated_path, file.path(local_path,"Integrated/"), "--recursive",  file_includes, sep = " "), intern = T)

# get all the curated dataset files
system(  paste('aws s3 cp',file.path(s3clinical,'ProcessedData/'), local_path, '--recursive --exclude "*" --include "DFCI*" --include "UAMS*" --include "MMRF*"', sep = " "), intern = T)
