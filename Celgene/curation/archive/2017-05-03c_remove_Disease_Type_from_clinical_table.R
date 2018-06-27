# remove redundant Disease_Type from clinical data table
clinical <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/JointData",
                     "curated_clinical_2017-04-17.txt"))

PutS3Table(select(clinical, -Disease_Type),
           file.path(s3, "ClinicalData/ProcessedData/JointData",
                     "curated_clinical_2017-05-03.txt"))

# archive prev version
n <- "curated_clinical_2017-04-17.txt"
system(paste('aws s3 mv',
             file.path(s3, "ClinicalData/ProcessedData/JointData", n),
             file.path(s3, "ClinicalData/ProcessedData/JointData/archive/"),
             '--sse', sep = " "))
