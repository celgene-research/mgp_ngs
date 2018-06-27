# I'm realizing there are patients and files listed in the "Package Validator" file
# that don't exist anywhere else (SeqQC or in our actual inventory)
# 
# To provide a comprehensive lookup table I'll add any missing File_Names to
# the JointData/curated_metadata table.
# 
source("curation_scripts.R")


### ---------------------------------------------------------------------------
metadata  <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/JointData", 
                                  "curated_metadata_2017-04-17.txt"))%>%
  mutate(source = "curated_metadata")

mmrf.inv  <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/MMRF_IA10c", 
                                  "curated_mmrf.file.inventory.txt")) %>%
  mutate(source = "curated_mmrf.file.inventory")
df  <- append_df(metadata, mmrf.inv, id = "File_Name")

### ---------------------------------------------------------------------------
mmrf.seqqc  <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/MMRF_IA10c", 
                                    "curated_MMRF_CoMMpass_IA10_Seq_QC_Summary.txt")) %>%
  mutate(source = "curated_MMRF_CoMMpass_IA10_Seq_QC_Summary.txt")

df2  <- append_df(df, mmrf.seqqc, id = "File_Name", mode = "append")



### ---------------------------------------------------------------------------
mmrf.pervisit  <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/MMRF_IA10c", 
                                       "curated_MMRF_PER_PATIENT_VISIT.txt")) %>%
  mutate(source = "curated_MMRF_PER_PATIENT_VISIT.txt") %>%
  filter(!is.na(File_Name)) 
df3  <- append_df(df2, mmrf.pervisit, id = "File_Name", mode = "append")


### ---------------------------------------------------------------------------
validator <- GetS3Table(file.path(s3, "ClinicalData/OriginalData/MMRF_IA10c/README_FILES", 
                                  "PackageBuildValidator.txt"), header = F)  %>%
  transmute(
    Patient = V1,
    File_Name = V4,
    
    Sequencing_Type  = case_when(
      grepl("^RNA", .$V5)   ~ "RNA-Seq",
      grepl("^Exome", .$V5) ~ "WES",
      grepl("^LI", .$V5)    ~ "WGS",
      TRUE ~ as.character(NA)),
    Excluded_Flag    = as.numeric(grepl("^Exclude|RNA-No|LI-Neither|Exome-Neither",
                                        .$V5)),
    Excluded_Specify = V5)%>%
  mutate(source = "PackageBuildValidator.txt")

# remove exclude_specify for retained samples and sequencing type from excluded
validator[validator$Excluded_Flag == 0,"Excluded_Specify"] <- NA
out  <- append_df(df3, validator, id = "File_Name", mode = "append")

### ---------------------------------------------------------------------------
# we  clean up and fields that are now conflicted by the merge operation

# MMRF_1244_1_PB_Whole_C1_TSE61_K03611 is showing conflicting exclusion flags
out %>% filter(grepl("; ", Excluded_Flag)) %>% select(File_Name, starts_with("Excl")) 
# we'll trust the more stringent SeqQC excluded flag
out[out$File_Name == "MMRF_1244_1_PB_Whole_C1_TSE61_K03611", "Excluded_Flag" ] <- "1"
  
# somehow we have multiple visit names (and consequently disease_statuses) on the original metadata table
# I'll overwrite with the more recent SeqQC table data
conflicted  <- out %>% filter(grepl("; ", Disease_Status)) %>% select(File_Name, Disease_Status, Visit_Name) 
replacement <- mmrf.seqqc %>% filter( File_Name %in% conflicted$File_Name) %>% select(File_Name, Disease_Status, Visit_Name)

out <- append_df(out, replacement, id = "File_Name", mode = "replace")

# We have weird annotations with those weird SRR files, if missing values I'll assume they
# are all WGS Baseline samples (they're all sample_seq = _1) but leave Disease_Type and Exlude_Flag as NA
missing <- out %>% filter(!is.na(File_Path)) %>% filter(is.na(Disease_Status)) %>% 
  select(File_Name, File_Path, Disease_Status, Sequencing_Type, Excluded_Flag)

out[out$File_Name %in% missing$File_Name, "Disease_Status"]  <- "ND"
out[out$File_Name %in% missing$File_Name, "Sequencing_Type"] <- "WGS"

### ---------------------------------------------------------------------------
### push this new version to JointData and archive the previous version

system(paste('aws s3 mv',
             file.path(s3, "ClinicalData/ProcessedData/JointData", "curated_metadata_2017-04-17.txt"),
             file.path(s3, "ClinicalData/ProcessedData/JointData/archive", "curated_metadata_2017-04-17.txt"),
             '--sse', sep = " "))

PutS3Table(out, 
           file.path(s3, "ClinicalData/ProcessedData/JointData",
                     "curated_metadata_2017-05-03.txt"))
