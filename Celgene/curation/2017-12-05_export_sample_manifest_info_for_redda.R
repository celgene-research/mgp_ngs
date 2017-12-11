library(toolboxR)
library(tidyverse)

clinical <- auto_read("../../../data/Master/curated.clinical.2017-08-08.txt")
metadata <- auto_read("../../../data/Master/curated.metadata.2017-07-07.txt") %>%
  group_by(Patient) %>%
  summarise_all(Simplify)

df <- clinical %>%
  left_join(metadata, by = "Patient") %>%
  select(Patient,
         Study,
         D_Gender,
         D_Age,
         File_Name_Actual,
         Sequencing_Type,
         Disease_Status,
         Disease_Type,
         Tissue_Type,
         Cell_Type)

auto_write(df, "~/Downloads/mgp_patient_list.txt")
