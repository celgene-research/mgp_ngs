## 
## Dan Rozelle
## drozelle@ranchobiosciences.com
## 2019-02-27
## 
## can you please update the survival data for IFM2009 based on the 
##  attached Excel Spreadsheet? The flags for OS / PFS are 
##  0 = censored, 1 = event [death or progression]. 
## 

library(s3r)
library(tidyverse)
library(toolboxR)
source('curation_scripts.R')

s3_set(bucket = "celgene.rnd.combio.mmgp.external", 
       sse = T,
       cwd = "ClinicalData")

update <- s3_get_with("OriginalData/DFCI_2009/2019-02-27_IFM_survival_update.xlsx", 
                      FUN = auto_read, fun.args = list(reader = "read_excel")) %>% 
  dplyr::rename(Patient = CelgeneID,
                D_OS       = DeathCensortime,
                D_OS_FLAG  = Death,
                D_PFS      = RelapseCensorTime,
                D_PFS_FLAG = Relapse) %>% 
  select(-OrgID) %>% 
  # Clean some strangely duplicated rows
  mutate(Patient = gsub("\\.[1-2]","",Patient) ) %>% 
  distinct()

# changes
# "056_003RM.1" > 056_003RM
# "056_003RM.2"
# 
# "056_002MF.1" > 056_002MF
# "056_002MF.2"
# 
# "104_001FM.1" > 104_001FM
# "104_001FM.2"
# 
# "001_057AP.1" > 001_057AP
# "029_006MM.2" > 029_006MM
# "015_016BG.2" > 015_016BG
# "009_001FN.2" > 009_001FN


clin <- s3_get_table('ProcessedData/JointData/curated.clinical.2019-01-26.txt')
meta <- s3_get_table('ProcessedData/JointData/curated.metadata.2019-02-02.txt')

dfci <- meta %>% filter(Study=="DFCI.2009")

clin_dfci <- clin %>% 
  filter(Patient %in% dfci$Patient)

compare_versions(new.df = update,old.df = clin_dfci, key = Patient)

# venn::venn(list(
#   new_IFM = update$Patient,
#   MGP = clin$Patient,
#   MGP_IFM = dfci$Patient
# ))

setdiff(update$Patient,clin$Patient)
# character(0)

# now confirm logical changes in PFS/OS
df<- update %>% 
  left_join(select(clin, Patient, D_PFS, D_PFS_FLAG, D_OS, D_OS_FLAG), by = "Patient") %>% 
  gather()

df <- left_join(select(clin_dfci, Patient, D_PFS, D_PFS_FLAG, D_OS, D_OS_FLAG),
                select(update, Patient, D_PFS, D_PFS_FLAG, D_OS, D_OS_FLAG),
                by = "Patient"
                ) %>% 
  mutate(
    deltaPFS = D_PFS.y-D_PFS.x,
    deltaOS  = D_OS.y-D_OS.x)

df %>% 
  filter(deltaPFS < 0) %>% 
  auto_write("Patients with reduced PFS time.tsv")


# 2019-02-27
# Hi Fadi,
# I?ve got this survival data loaded and spotted a few QC issues, would love some 
# guidance before I write the tables. 21 patients are showing reduced PFS time, 
# some are significant (013_006MD changed from 1232 to 24 days PFS)



# TBD
# process table flow to incorporate new IA11 clinical data into Master/NDMM/Cluster tables
# table_flow()
# run_master_inventory()
# cluster_flow()

