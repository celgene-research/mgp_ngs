library(toolboxR)
library(tidyverse)

mgp_rnaseq <- auto_read("../../../data/Master/curated.metadata.2017-07-07.txt") %>%
  filter(Study == "DFCI.2009") %>%
  select(Patient, Sequencing_Type, Disease_Status)

prismm_wgs <- auto_read("../../../../prismm/data/set2-3/2017-12-05_DFCI_Clinical2.txt") %>%
  mutate(Disease_Status = if_else(Relapse == 1, "R", "ND")) %>%
  mutate(Sequencing_Type = "WGS") %>%
  rename(Patient = SampleID) %>%
  select(Patient, Sequencing_Type, Disease_Status)


manifest <- auto_read("../../../../prismm/data/set2-3/DA0000435_wgs60_samples.csv") %>%
 mutate( Patient = gsub(" ", "_", celgene_id)) %>%
  mutate(Sequencing_Type = "WGS") %>%
  select(Patient, Sequencing_Type)
      
df <- bind_rows(list(prismm_wgs, mgp_rnaseq, manifest)) %>%
  group_by(Patient) %>%
  mutate(Disease_Status = Simplify(Disease_Status)) %>%
  mutate(class = paste(Disease_Status, Sequencing_Type, sep = "-"),
         n = 1) %>%
  select(Patient, class, n) %>%
  unique() %>%
  # group_by(Patient, Disease_Status) %>%
  # summarise(Sequencing_Types = Simplify(Sequencing_Type)) %>%
  spread(class, n)

auto_write(df, "../../../../prismm/data/set2-3/2018-06-18_IFM2009_seq_types_list.csv", sep = ",", na = "")


