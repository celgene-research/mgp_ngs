library(toolboxR)
library(tidyverse)
library(s3r)
s3_set(bucket = "celgene.rnd.combio.mmgp.external", profile = NULL)

s3_ls('ClinicalData/ProcessedData/JointData/')

# export for PRISMM tracking
df <- s3_get_table('ClinicalData/ProcessedData/JointData/curated.metadata.2018-07-20.txt') %>% 
  filter(is.na(Excluded_Flag) | Excluded_Flag != 1) %>% 
  transmute(DA_project_id = "DA0000168",
         celgene_id    = Patient,
         vendor_id = File_Name,
         tissue=Tissue_Type,
         condition=Disease_Status,
         is_normal=if_else(Sample_Type_Flag==0, "Yes", "No", missing = as.character(NA)),
         experiment_type=Sequencing_Type,
         filename=File_Name,
         batch=NA)

auto_write(df, 'mgp_samples_formatted_for_PRISMM.tsv')

auto_write(df, "~/thindrives/Downloads/mgp_file_types.tsv")
