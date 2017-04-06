
source("curation_scripts.R")

per.file.clinical <- toolboxR::GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Integrated/per.file.clinical.txt"))


status <- per.file.clinical %>%
  select(File_Name, File_Path, Patient, Sequencing_Type) %>%
 
  # split concatenated file path strings to match appropriately
  separate(File_Path, c("File_Path1","File_Path2"), "; "  ) %>%
  gather(key, File_Path, c(File_Path1, File_Path2)) %>%
  filter( !is.na(File_Path) ) %>%
  select(-key) %>%
  
  mutate(Excluded_Flag = 0,
         Comment       = "")

status <- toolboxR::GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Integrated/file_inventory.txt")) %>%
  select(File_Name, File_Path, Patient, Sequencing_Type) %>%
  filter( !(File_Path %in% status$File_Path) ) %>%
  mutate(Excluded_Flag = 1,
         Comment       = "") %>%
  
  rbind(status) %>%
  arrange(File_Name)

# add exclusion info from prexisting table
to.exclude <- toolboxR::GetS3Table(file.path(s3, "ClinicalData/ProcessedData/JointData/Excluded_Samples.txt"))
