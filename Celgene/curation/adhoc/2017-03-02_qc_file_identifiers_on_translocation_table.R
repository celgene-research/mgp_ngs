# per.file <- toolboxR::AutoRead("../../../data/ProcessedData/Integrated/per.file.clinical.txt")

per.file <- GetS3Table(file.path(s3,"ClinicalData/ProcessedData/Integrated",
                                 "per.file.clinical.txt"))

mismatched.sequencing.types <- per.file %>%
  mutate(per.file.Sequencing_Type = gsub("\\-Seq","",Sequencing_Type)) %>%
  select(File_Name, per.file.Sequencing_Type)%>%
  merge(., df, by = "File_Name") %>%
  mutate(mismatch = (per.file.Sequencing_Type != Sequencing_Type)) %>%
  filter(mismatch) %>%
  group_by(File_Name) %>%
  summarise(per.file.type = Simplify(per.file.Sequencing_Type),
            type = Simplify(Sequencing_Type))
mismatched.sequencing.types
