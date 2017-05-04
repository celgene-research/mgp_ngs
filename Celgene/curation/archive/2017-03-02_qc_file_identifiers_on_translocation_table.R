source("curation_scripts.R")
per.file <- GetS3Table(file.path(s3,"ClinicalData/ProcessedData/Integrated",
                                 "per.file.clinical.txt"))
exists("long.trsl") # this assumes you've just run the curate_JointData.R translocation function 

multiple.calls <- long.trsl %>%
  group_by(File_Name, Result) %>%
  summarise( n = n(),
             consensus = Simplify(Value)) %>%
  filter( n > 1)
multiple.calls
# good, even though we have duplicated file calls, none appear to be conflicting

mismatched.seq.types <- per.file %>%
  mutate(per.file.Sequencing_Type = gsub("\\-Seq","",Sequencing_Type)) %>%
  select(File_Name, per.file.Sequencing_Type) %>%
  merge(., long.trsl, by = "File_Name") %>%
  mutate(mismatch = (per.file.Sequencing_Type != Sequencing_Type)) %>%
  filter(mismatch) %>%
  group_by(File_Name) %>%
  summarise(per.file.type = Simplify(per.file.Sequencing_Type),
            type = Simplify(Sequencing_Type))

mismatched.seq.types
# These aren't a problem either since the translocation table uses them under 
# these incorrect types, and also the right ones. 
