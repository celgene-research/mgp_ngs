

# qc function returns any master tables inspected for errors so they can be fixed
results <- qc_master_tables()

results

metadata <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/JointData",
                                 "curated.metadata.2017-05-04.txt"))

# Sample_Names
rows <- is.na(metadata$Sample_Name)
metadata[rows, "Sample_Name"] <- gsub("(MMRF_\\d+_\\d+)_.*", "\\1", metadata[rows,]$File_Name)

# Sample_Type and Sample_Type_Flag
rows <- is.na(metadata$Sample_Type)
metadata[rows, "Sample_Type"] <-  case_when(
  grepl("BM_CD138pos", metadata[rows,]$File_Name) ~ "NotNormal",
  grepl("BM_CD138neg", metadata[rows,]$File_Name) ~ "Normal",
  grepl("PB_Whole", metadata[rows,]$File_Name)    ~ "Normal",
  grepl("PB_WBC", metadata[rows,]$File_Name)      ~ "Normal",
  grepl("PB_CD3pos", metadata[rows,]$File_Name)   ~ "Normal",
  grepl("PB_CD138pos", metadata[rows,]$File_Name) ~ "NotNormal",
  TRUE ~ as.character(NA)
  )

metadata[rows, "Sample_Type_Flag"] <-  case_when(
  grepl("BM_CD138pos", metadata[rows,]$File_Name) ~ "1",
  grepl("BM_CD138neg", metadata[rows,]$File_Name) ~ "0",
  grepl("PB_Whole", metadata[rows,]$File_Name)    ~ "0",
  grepl("PB_WBC", metadata[rows,]$File_Name)      ~ "0",
  grepl("PB_CD3pos", metadata[rows,]$File_Name)   ~ "0",
  grepl("PB_CD138pos", metadata[rows,]$File_Name) ~ "1",
  TRUE ~ as.character(NA)
)

# Disease_Status
rows <- is.na(metadata$Disease_Status)
metadata[rows, "Disease_Status"] <-  case_when(
  grepl("^MMRF_\\d+_1_", metadata[rows,]$File_Name) ~ "ND",
  grepl("^MMRF_\\d+_", metadata[rows,]$File_Name) ~ "R",
  TRUE ~ as.character(NA)
)

#  Cell_Type
rows <- is.na(metadata$Cell_Type)
metadata[rows, "Cell_Type"] <-  case_when(
  grepl("BM_CD138pos", metadata[rows,]$File_Name) ~ "CD138pos",
  grepl("BM_CD138neg", metadata[rows,]$File_Name) ~ "CD138neg",
  grepl("PB_Whole", metadata[rows,]$File_Name)    ~ "PBMC",
  grepl("PB_WBC", metadata[rows,]$File_Name)      ~ "PBMC",
  grepl("PB_CD3pos", metadata[rows,]$File_Name)   ~ "CD3pos",
  grepl("PB_CD138pos", metadata[rows,]$File_Name) ~ "CD138pos",
  TRUE ~ as.character(NA)
)



#  Tissue_Type
rows <- is.na(metadata$Tissue_Type)
metadata[rows, "Tissue_Type"] <-  case_when(
  grepl("BM_CD138pos", metadata[rows,]$File_Name) ~ "BM",
  grepl("BM_CD138neg", metadata[rows,]$File_Name) ~ "BM",
  grepl("PB_Whole", metadata[rows,]$File_Name)    ~ "PB",
  grepl("PB_WBC", metadata[rows,]$File_Name)      ~ "PB",
  grepl("PB_CD3pos", metadata[rows,]$File_Name)   ~ "PB",
  grepl("PB_CD138pos", metadata[rows,]$File_Name) ~ "PB",
  TRUE ~ as.character(NA)
)

# visit <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData",
# "Curated_Data_Sources/MMRF_IA10c/curated_MMRF_PER_PATIENT_VISIT.txt"))

#  Disease_Status
rows <- is.na(metadata$Disease_Type)
metadata[rows, "Disease_Type"] <-  case_when(
  grepl("BM_CD138pos", metadata[rows,]$File_Name) ~ "MM",
  grepl("BM_CD138neg", metadata[rows,]$File_Name) ~ "MM",
  grepl("PB_Whole", metadata[rows,]$File_Name)    ~ "MM",
  grepl("PB_WBC", metadata[rows,]$File_Name)      ~ "MM",
  grepl("PB_CD3pos", metadata[rows,]$File_Name)   ~ "MM",
  grepl("PB_CD138pos", metadata[rows,]$File_Name) ~ "PCL",
  TRUE ~ as.character(NA)
)
#  Tissue_Type and Cell_Type for misc sets
metadata[metadata$File_Name == "PD4298c", "Cell_Type"]   <- "CD138"
metadata[metadata$File_Name == "PD4298c", "Tissue_Type"] <- "BM"
metadata[metadata$Study == "DFCI.2009", "Cell_Type"]   <- "CD138"
metadata[metadata$Study == "DFCI.2009", "Tissue_Type"] <- "BM"

# confirm this is empty
tmp <- metadata %>% filter(
  is.na(Sample_Type_Flag) | 
  is.na(Sample_Type) | 
  is.na(Disease_Status) | 
  is.na(Tissue_Type) | 
  is.na(Cell_Type) | 
  is.na(Disease_Type) 
) %>%
  select(File_Name, Sample_Type_Flag, Sample_Type ,Disease_Status, Tissue_Type, Cell_Type, Disease_Type)


# mark missing files as excluded
# PCL files
# missing File_Path
# or Excluded

pcl.samples <- metadata %>%
  mutate(tissue.cell = paste0(Tissue_Type, Cell_Type)) %>%
  group_by(Sample_Name) %>%
  filter( any(tissue.cell == "PBCD138pos"))

unique(pcl.samples$Patient)
metadata[metadata$Patient %in% pcl.samples$Patient, "Disease_Type"] <- "PCL"

metadata[metadata$Disease_Type == "PCL", "Excluded_Flag" ]    <- "1"   
metadata[metadata$Disease_Type == "PCL", "Excluded_Specify" ] <- "PCL sample"    
      
metadata[is.na(metadata$File_Path), "Excluded_Flag" ]    <- "1"   
metadata[is.na(metadata$File_Path), "Excluded_Specify" ] <- "File missing"

PutS3Table(metadata, file.path(s3, "ClinicalData/ProcessedData/JointData",
                                 "curated.metadata.2017-05-16.txt"))

# run again to verify no FAILS
table_flow(just.master = T)
run_master_inventory()
qc_master_tables()

# if everything passed QC, run the whole flow
table_flow()

# fixed one more thing
# MMRF_1309_1 and MMRF_2549_1 were both changed to relapse but should both be Baseline, ND samples 
metadata <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/JointData",
                               "curated.metadata.2017-05-16.txt"))
rows <- grepl("_1_", metadata$Sample_Name)
metadata[rows & (metadata$Disease_Status != "ND"), "Visit_Name"]     <- "Baseline"
metadata[rows & (metadata$Disease_Status != "ND"), "Disease_Status"] <- "ND"


PutS3Table(metadata, file.path(s3, "ClinicalData/ProcessedData/JointData",
                               "curated.metadata.2017-05-16.txt"))

# run again to verify no FAILS
table_flow()
run_master_inventory()
qc_master_tables()

