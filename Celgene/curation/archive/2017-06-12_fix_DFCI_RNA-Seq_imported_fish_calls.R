# looks like some of the dfci cytogenetic calls were not properly appended
# to the top level JointData tables due to a change in column naming.
# 
# Here I'll correct those columns, process table flow, and push a filtered
# subset to sage again

source("curation_scripts.R")

######################
# make changes on JointData tables
s3_cd("/ClinicalData/ProcessedData")
s3_ls("JointData")

dict              <- get_dict()
curated.dfci.2009 <- s3_get_table("Curated_Data_Sources/DFCI/curated_DFCI_2017-02-01_DFCI_RNASeq_Clinical.txt")
translocations    <- s3_get_table("JointData/curated.translocations.2017-05-04.txt")

######################
# add fish data

names(curated.dfci.2009)[!(names(curated.dfci.2009) %in% dict$names)]
# [1] "CYTO_t.4.14._FISH"   "CYTO_t.14.16._FISH"  "CYTO_del.1p._FISH"   "CYTO_del.1p32._FISH" "CYTO_del.16q._FISH"
out <- curated.dfci.2009 %>%
  transmute( File_Name = File_Name,
             CYTO_t_4_14_FISH   = CYTO_t.4.14._FISH,
             CYTO_t_14_16_FISH  = CYTO_t.14.16._FISH,
             CYTO_del_1p_FISH   = CYTO_del.1p._FISH,
             CYTO_del_1p32_FISH = CYTO_del.1p32._FISH,
             CYTO_del_16q_FISH  = CYTO_del.16q._FISH ) %>%
  append_df(translocations,., id = "File_Name")

write_new_version(out, "curated.translocations", "JointData")

######################
# move consensus hyperdiploidy calls to "manta" prefix instead of placing
# directly into the consensus fields, follow this up with consensus caller fcn

translocations <- s3_get_table("JointData/curated.translocations.2017-06-13.txt")
translocations$CYTO_Hyperdiploid_ControlFreec <- translocations$CYTO_Hyperdiploid_CONSENSUS
translocations$CYTO_Hyperdiploid_CONSENSUS    <- NA

######################
# generate new consensus calls

metadata       <- s3r::s3_get_table("JointData/curated.metadata.2017-05-16.txt")
translocations <- call_sample_level_consensus(translocations, metadata)
write_new_version(translocations, "curated.translocations", "JointData")

######################
# propagate the new table info
s3_cd("/ClinicalData/ProcessedData")
table_flow()
(results <- qc_master_tables())
run_master_inventory()

inv <- s3_get_table("Reports/counts.by.study.2017-06-14.txt")
