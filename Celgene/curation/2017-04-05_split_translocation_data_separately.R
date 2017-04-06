# extract translocation columns including consensus calls as separate curated table

source("curation_scripts.R")

per.file.clinical <- toolboxR::GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Integrated/per.file.clinical.txt"))

######
# extract cyto data, remove blank rows, and keep this as a searate curated table
per.file.cyto <- per.file.clinical %>%
  select(File_Name, starts_with("CYTO")) 

has.data <- rbind(apply(per.file.cyto, 1, function(x){
  !all( is.na( x[-1]) )
}))

per.file.cyto <- per.file.cyto[has.data,]

system('aws s3 mv s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/JointData/curated_translocation_calls_2017-03-02.txt s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/JointData/archive/curated_translocation_calls_2017-03-02.txt --sse')
toolboxR::PutS3Table(per.file.cyto, file.path(s3, "ClinicalData/ProcessedData/JointData/curated_translocations_2017-04-05.txt"))

#######
# extract clinical data separately and replace per.file.clinical.txt on S3
per.file.clinical <- toolboxR::GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Integrated/per.file.clinical.txt")) %>%
  select( -starts_with("CYTO"))

toolboxR::PutS3Table(per.file.clinical, file.path(s3, "ClinicalData/ProcessedData/Integrated/per.file.clinical.txt"))
