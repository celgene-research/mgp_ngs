

source("curation_scripts.R")
dict <- dict()
grep("CYTO.*FISH", dict$names, value = T)

metadata <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/JointData", 
                                 "curated_metadata_2017-05-03.txt")) 
sample2file <- setNames(metadata$File_Name, metadata$Sample_Name)
  
### capture summary delation events from UAMS raw data table
uams <- GetS3Table(file.path(s3, "ClinicalData/OriginalData/UAMS", 
                             "UAMS_UK_sample_info.xlsx"))
names(uams) <- chomp(names(uams) )

uams <- uams %>%
  filter(Type == "Tumour") %>%
  transmute(File_Name          = sample2file[Sample_name],
            CYTO_MYC_FISH      = as.numeric(`MYC translocation` != 0),
            CYTO_del_1q_FISH   = as.numeric(chr.1q_summary == "Deleted"),
            CYTO_del_12p_FISH  = as.numeric(chr.12p_summary == "Deleted"),
            CYTO_del_13q_FISH  = as.numeric(chr.13_summary == "Deleted"),
            CYTO_del_TP53_FISH = as.numeric(TP53_summary == "Deleted"))

### mmrf info was already curated into the processed table, we just need to append to JointData
mmrf <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/MMRF_IA10c", 
                             "curated_MMRF_PER_PATIENT_VISIT.txt")) %>%
  filter( !is.na(File_Name) ) %>%
  transmute(File_Name             = File_Name,
            CYTO_MYC_FISH         = CYTO_MYC_FISH,
            CYTO_amp_1q_FISH      = CYTO_amp.1q._FISH,
            CYTO_1qplus_FISH      = CYTO_1qplus_FISH,
            CYTO_del_1p_FISH      = CYTO_del.1p._FISH,
            CYTO_del_17_17p_FISH  = CYTO_del.17.17p._FISH,
            CYTO_del_13q_FISH     = CYTO_del.13q._FISH)

dfci.2009 <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/DFCI", 
                                  "curated_DFCI_2017-02-01_DFCI_RNASeq_Clinical.txt")) %>%
  transmute(File_Name         = File_Name,
            CYTO_1qplus_FISH  = CYTO_1qplus_FISH,
            CYTO_del_1p_FISH  = CYTO_del.1p._FISH,
            CYTO_del_16q_FISH = CYTO_del.16q._FISH )


dfci <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/DFCI", 
                             "curated_DFCI_published_cyto_calls.txt")) %>%
  transmute(File_Name         = File_Name,
            CYTO_del_1p_FISH     = CYTO_del.1p._FISH,
            CYTO_1qplus_FISH     = CYTO_1qplus_FISH,
            CYTO_del_12p_FISH    = CYTO_del.12p._FISH,
            CYTO_del_13q_FISH    = CYTO_del.13q._FISH,
            CYTO_del_14q_FISH    = CYTO_del.14q._FISH,
            CYTO_del_16q_FISH    = CYTO_del.16q._FISH,
            CYTO_del_17_17p_FISH = CYTO_del.17.17p._FISH)

# bind all the new data together
df <- rbindlist(list(mmrf, uams, dfci, dfci.2009), fill = T)
df <- right_join(select(metadata, File_Name, Patient), df, by = "File_Name")



# add to JointData translocations table
trsl <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/JointData", 
                             "curated_translocations_2017-04-17.txt"))
out <- append_df(trsl, df, id = "File_Name")

system(paste('aws s3 mv',
             file.path(s3, "ClinicalData/ProcessedData/JointData", "curated_translocations_2017-04-17.txt"),
             file.path(s3, "ClinicalData/ProcessedData/JointData/archive/" ),
             '--sse', sep = " "))

PutS3Table(out, 
           file.path(s3, "ClinicalData/ProcessedData/JointData",
                     "curated_translocations_2017-05-03.txt"))
