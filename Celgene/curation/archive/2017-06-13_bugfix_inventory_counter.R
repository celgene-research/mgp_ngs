# add missing patient values to translocation table
# develop bugfix inventory counting to count per-patient and not per-file 
# 
qc_master_tables()
# Result         Test          Table  Column
# 1   FAIL all_required translocations Patient

s3_cd("/ClinicalData/ProcessedData")
s3_ls("JointData")
translocations <- s3_get_table("JointData/curated.translocations.2017-06-13.txt")
meta <- s3_get_table("JointData/curated.metadata.2017-05-16.txt")

missing <- translocations %>% filter( is.na(Patient))

out <- meta %>% 
  select(File_Name, Patient) %>% 
  filter( File_Name %in% missing$File_Name ) %>%
  append_df(translocations, ., id = "File_Name")

write_new_version(df = out, name = "curated.translocations", dir = "JointData")

table_flow(just.master = T)
qc_master_tables()

s3_ls("Master")
dt   <- s3_get_table("Master/curated.translocations.2017-06-13.txt")
meta <- s3_get_table("Master/curated.metadata.2017-06-13.txt")
# per.file table version
inv <- right_join(select(meta, File_Name, Patient, Study), 
                 dt, 
                 by = c("File_Name", "Patient")) %>%
  select(-File_Name) %>%
  group_by(Study, Patient) %>%
  summarise_all( funs(any(!is.na(.)) ) ) %>%
  select(-Patient) %>%
  group_by(Study) %>%
  summarise_all( sum )

# per-patient table version (clinical)
dt   <- s3_get_table("Master/curated.clinical.2017-06-12.txt")
meta <- s3_get_table("Master/curated.metadata.2017-06-13.txt")

inv <- right_join(select(meta, Patient, Study) %>% unique(), 
                  dt, 
                  by = "Patient") %>%
  group_by(Study) %>%
  summarise_all( funs(sum(!is.na(.)) )  )


run_master_inventory()
