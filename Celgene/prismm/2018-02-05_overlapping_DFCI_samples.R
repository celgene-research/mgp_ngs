library(toolboxR)
library(tidyverse)

# wgs.tumor <- auto_read("~/rancho/celgene/prismm/data/set2-3/SecondBatchWGSTumorSamples.xlsx") 
# wgs.normal <- auto_read("~/rancho/celgene/prismm/data/set2-3/SecondBatchWGSNormalSamples.xlsx")
# 
# matched.wgs.patients <- wgs.tumor %>%
#   filter(Collaborator.Participant.ID %in% wgs.normal$Collaborator.Participant.ID) %>%
#   select(Collaborator.Participant.ID)

wgs <- auto_read("~/rancho/celgene/prismm/data/set2-3/SecondBatchWGSTumorSamples.xlsx") %>%
  rename( Patient = Collaborator.Participant.ID)

rna <- auto_read("~/rancho/celgene/mgp/data/Reports/counts.by.individual.2017-08-23.txt") %>%
  filter( INV_Has.RNASeq == 1) %>%
  mutate( Patient = gsub("_", " ", Patient) )

all.rna <- auto_read("~/rancho/celgene/mgp/data/Reports/counts.by.individual.2017-08-23.txt") 
  
  
clinical1 <-  auto_read("~/rancho/celgene/mgp/data/Master/curated.metadata.2017-07-07.txt") %>%
  mutate( Patient = gsub("_", " ", Patient) ) %>%
  filter( Sequencing_Type == "RNA-Seq") %>%
  select(Patient, Disease_Status) %>%
  group_by(Patient) %>%
  summarise_all(Simplify)

clinical2 <-  auto_read("~/rancho/celgene/prismm/data/set2-3/2017-12-05_DFCI_Clinical2.txt") %>%
  mutate( Patient = gsub("_", " ", SampleID),
          Disease_Status = if_else(Relapse == 1, "R", "ND", missing = "") )%>%
  select(Patient, Disease_Status) 

clinical <- bind_rows(clinical1, clinical2)

out <- wgs  %>%
  mutate(rna.mgp = (Patient %in% rna$Patient)) %>%
  # filter(Collaborator.Participant.ID %in% rna$Patient) %>%
  left_join(clinical, by = "Patient")%>%
  group_by(Patient) %>%
  mutate(paired = all(c("ND", "R") %in% Disease_Status)) %>%
  left_join(rna, by = "Patient") %>%
  arrange(Patient)


auto_write(out, "~/rancho/celgene/prismm/data/set2-3/2018-02-05_ALL_annotated_DFCI_samples.txt")

just_ids <- out %>%
  filter( rna.mgp | paired) %>%
  select(Patient)

auto_write(just_ids, "~/rancho/celgene/prismm/data/set2-3/2018-02-05_DFCI_patients_WGS_RNA.txt")

