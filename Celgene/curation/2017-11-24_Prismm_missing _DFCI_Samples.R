source("curation_scripts.R")
s3_ls("ClinicalData/ProcessedData/Master/")
df  <- s3_get_table("ClinicalData/ProcessedData/Master/curated.metadata.2017-07-07.txt") %>%
  filter(Study == "DFCI.2009")
new <- auto_read("~/thindrives/Downloads/Copy of Celgene DFCI_DNA QC results_9.22.17-sample type_Celgene response.xls") %>%
  mutate(Patient = gsub(" ", "_",  Collaborator.Participant.ID) )


# patient not in mgp set
new_ids <- setdiff(new$Patient, df$Patient)
new_ids <- gsub("_"," ", new_ids)
auto_write(new_ids, "~/thindrives/Downloads/DFCI_ids_not_in_MGP.csv", col.names = F, quote = F)
