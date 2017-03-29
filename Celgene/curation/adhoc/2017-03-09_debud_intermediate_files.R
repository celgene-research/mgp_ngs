
n <- toolboxR::GetS3Table(file.path(s3,"ClinicalData/ProcessedData/Integrated/sas/archive/per.patient.nd.tumor.all_2016-11-23.sas"))

one <- readRDS("/tmp/recall/per.file.001.RData")
two <- readRDS("/tmp/recall/per.file.002.RData")
thr <- readRDS("/tmp/recall/per.file.all.003.RData")
four <- readRDS("/tmp/recall/per.file.clinical.nd.tumor.004.RData")

names(one)
names(two)
names(thr)
names(four)
