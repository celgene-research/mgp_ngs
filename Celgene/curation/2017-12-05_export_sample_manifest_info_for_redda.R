library(toolboxR)
library(tidyverse)

mgp <- auto_read("../../../data/Master/curated.metadata.2017-07-07.txt") %>%
  filter(Study == "DFCI.2009") %>%
  select(Patient, Sequencing_Type, Disease_Status)

dfci2 <- auto_read("../../../../prismm/data/set2-3/2017-12-05_DFCI_Clinical2.txt")

df <- auto_read("../../../../prismm/data/set2-3/DA0000435_wgs60_samples.csv") %>%
  mutate(Sequencing_Type = "WGS",
         
         Patient = gsub(" ", "_", celgene_id)) %>%
  full_join(dfci2, by = c("Patient"="SampleID")) %>%
  mutate(Disease_Status = if_else(Relapse == 1, "R", "ND")) %>%
  
  bind_rows(mgp)  %>%
  group_by(Patient, Disease_Status) %>%
  summarise(Sequencing_Types = Simplify(Sequencing_Type)) %>%
  spread(Disease_Status, Sequencing_Types)

# auto_write(df, "../../../../prismm/data/set2-3/2018-06-18_partial_IFM2009_seq_types_list.csv")

df %>%  filter(!(Patient %in% c(dfci2$SampleID, mgp$Patient)))
