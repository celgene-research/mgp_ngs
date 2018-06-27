
source("curation_scripts.R")

######################
# Get a copy of the Master table, but
s3_cd("/ClinicalData/ProcessedData/Master")
s3_ls()
meta.master <- s3r::s3_get_table("curated.metadata.2017-05-16.txt") 
clin.master <- s3r::s3_get_table("curated.clinical.2017-05-16.txt") 
# make changes on JointData tables
s3_cd("/ClinicalData/ProcessedData/JointData")
s3_ls()
meta.all <- s3r::s3_get_table("curated.metadata.2017-05-16.txt")
clin.all <- s3r::s3_get_table("curated.clinical.2017-05-11.txt")

######################
# check for negative PFS
clin.master %>%  filter(D_PFS < 0) %>% select(Patient, D_PFS_FLAG, D_PFS)
# Patient D_PFS_FLAG D_PFS
# 1 167_006MR          0   -81

# set both PFS and Flag to NA on JointData Table
clin.all[clin.all$Patient == "167_006MR", "D_PFS"]      <- NA
clin.all[clin.all$Patient == "167_006MR", "D_PFS_FLAG"] <- NA


######################
# set PFS and FLAG to NA where FLAG == 0 and OS_FLAG == 1
clin.all %>%  
  filter( D_OS_FLAG == 1 & 
            (D_PFS_FLAG == 0 | is.na(D_PFS))) %>% 
  select(Patient, D_PFS_FLAG, D_PFS, D_OS_FLAG, D_OS)%>%
  knitr::kable()

bad.pfs.rows <- (!is.na(clin.all$D_OS_FLAG) & (clin.all$D_OS_FLAG == 1)) & 
  (is.na(clin.all$D_PFS) | (clin.all$D_PFS_FLAG == 0))

sum(bad.pfs.rows,na.rm = T)
# 36
clin.all[bad.pfs.rows, "D_PFS"] <- NA
clin.all[bad.pfs.rows, "D_PFS_FLAG"] <- NA


#### Add follow-up time to MMRF patients
# lets find the MMRF raw survivial and per-visit follow-up tables to find pfs
per.visit <- s3r::s3_get_csv("/ClinicalData/OriginalData/MMRF_IA10c",
                             "clinical_data_tables/CoMMpass_IA10c_FlatFiles",
                             "PER_PATIENT_VISIT.csv") %>% 
  mutate(Patient = PUBLIC_ID) %>%
  group_by(Patient) %>%
  summarise(D_Response_Assessment = max(AT_RESPONSEASSES, na.rm = T),
            D_Last_Visit          = max(VISITDY, na.rm = T))

#join to jointdata table and order
clin.all <- left_join(clin.all, follow.ups, by = "Patient") %>% 
  order_by_dictionary("clinical")

s3r::s3_put_table(clin.all, "curated.clinical.2017-05-31.txt")

# propagate the new table info
table_flow()
run_master_inventory()
results <- qc_master_tables()
df <- s3r::s3_get_table("../ND_Tumor_MM/per.patient.unified.nd.tumor.2017-05-31.txt")
export_sas(df)

