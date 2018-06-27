# run table_flow function to update master and ND_Tumor_MM tables after
# adding rows to JointData/metadata and FISH data to curated.translocations

source("curation_scripts.R")

# fix a couple of MMRF rows missing Study definition before using it as a lookup table
metadata       <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/JointData",
                                       "curated.metadata.2017-05-03.txt"))
metadata[is.na(metadata$Study), "Study"] <- "MMRF"

clinical       <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/JointData",
                                       "curated.clinical.2017-05-03.txt")) %>%
  select(-Disease_Type)

# call consensus structural variants from the new del/amp/plus calls I added.
# turns out we only had FISH data, and all nd.tumor samples were nonconflicting
# so I just moved FISH to CONSENSUS for export
translocations <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/JointData",
                                       "curated.translocations.2017-05-03.txt"))
translocations <- call_secondary_structural_variation(translocations, metadata)
translocations <- order_by_dictionary(translocations)

# put back the processed tables
PutS3Table(translocations, file.path(s3, "ClinicalData/ProcessedData/JointData",
                                     "curated.translocations.2017-05-04.txt"))
PutS3Table(metadata, file.path(s3, "ClinicalData/ProcessedData/JointData",
                                     "curated.metadata.2017-05-04.txt"))
PutS3Table(clinical, file.path(s3, "ClinicalData/ProcessedData/JointData",
                               "curated.clinical.2017-05-04.txt"))
table_flow()
run_master_inventory()
unified <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/ND_Tumor_MM", 
                                "per.patient.unified.nd.tumor.2017-05-04.txt"))
export_sas(unified)
