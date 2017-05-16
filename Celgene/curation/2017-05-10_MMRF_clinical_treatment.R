# 
# Add MMRF treatment data to JointData/curated.clinical table
# 

source("curation_scripts.R")
### import curated tables-------------------------------------------------------
orig <- file.path(s3, "ClinicalData/OriginalData/MMRF_IA10c/clinical_data_tables/CoMMpass_IA10c_FlatFiles")

clinical  <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/JointData", 
                                  "curated.clinical.2017-05-04.txt"))
treat     <- GetS3Table(file.path(orig, "STAND_ALONE_TREATMENT_REGIMEN.csv"))
trt.resp  <- GetS3Table(file.path(orig, "STAND_ALONE_TRTRESP.csv"))

# make a lookup table of all drug shortnames
name2short <-   trt.resp %>% 
  mutate_all(tolower) %>%
  select(trtname, trtshnm) %>%
  # fix drug names that contain value separators
  mutate( trtname = gsub("\\-", "", trtname)) %>%
  mutate( trtshnm = gsub("([vy])\\-([82])", "\\1\\2", trtshnm)) %>%
  mutate( trtname = strsplit(trtname, split = "/"),
          trtshnm = strsplit(trtshnm, split = "-")) %>%
  
  unnest(trtname, trtshnm) %>%
  unique() %>%
  arrange(trtshnm) %>%
  
  #fix a few names
  mutate(trtshnm = gsub("dox(lip.)", "doxlip", trtshnm, fixed = T))

PutS3Table(name2short, file.path(s3, "ClinicalData/ProcessedData/Resources/drug_name_abbreviation_table.txt"))

# list all the therapies applied
therapy.names <- tolower(unique(treat$MMTX_THERAPY))

# capture therapy info for treatment
therapy.info <- trt.resp %>%
  filter( line == 1) %>%
  # since therapy info is sequential, with cumulative name scheme we can just use
  # the last first line therapy
  group_by(public_id) %>%
  
  # make sure entries only on a single row are propogated to last line 1 entry
  mutate(bmtx_n     = as.integer(max(bmtx_seq, na.rm = T)), 
         bmtx_n     = if_else(is.na(bmtx_n), as.integer(0), bmtx_n)) %>%
  mutate(bmtx_1_day = min(bmtx_day, na.rm = T) ) %>%
  mutate(bmtx_type  = Simplify(bmtx_type) ) %>%
  mutate(thername  = gsub(" +\\+ +", "; ", thername) ) %>%
  mutate(thername  = gsub("\\/", "-", thername) ) %>%
  mutate(thershnm  = gsub(" +\\+ +", "; ", thershnm) ) %>%
  
  arrange(desc(trtgroup)) %>%
  slice(1) %>%
  
  select(public_id, trtgroup, therstdy, therendy, thername, thershnm, therclass, bmtx_rec, bmtx_type, bmtx_n, bmtx_1_day) %>%
  rename(TRT_1_trtgroup  = trtgroup,
         TRT_1_therstdy  = therstdy,
         TRT_1_therendy  = therendy,
         TRT_1_thername  = thername,
         TRT_1_thershnm  = thershnm,
         TRT_1_therclass = therclass,
         TRT_1_bmtx_rec  = bmtx_rec,
         TRT_1_bmtx_type = bmtx_type,
         TRT_1_bmtx_n    = bmtx_n,
         TRT_1_bmtx_1_day = bmtx_1_day)




filtered.treat <- treat %>% 
  # replace semicolon with comma since I'll be concatenating fields
  mutate_at( 2:ncol(.), function(x){gsub(";", ",", tolower(x))} ) %>%
  filter(grepl("first", MMTX_TYPE)) 

other.treatments <- filtered.treat %>%
  select(public_id, MMTX_SPECIFY) %>%
  filter( !is.na(MMTX_SPECIFY) &  MMTX_SPECIFY != "" ) %>%
  group_by(public_id) %>%
  summarize(TRT_1_other_names = Simplify(MMTX_SPECIFY))



curated.treatment <- filtered.treat %>% 
  select(public_id, MMTX_THERAPY) %>%
  left_join(., name2short, by = c("MMTX_THERAPY" = "trtname")) %>%
  select( -MMTX_THERAPY )%>%
  mutate(trtshnm = if_else(is.na(trtshnm),"other",trtshnm)) %>%
  unique() %>%
  
  mutate(n = 1) %>%
  mutate(trtshnm = paste("TRT_1", trtshnm, sep = "_")) %>%
  spread(trtshnm, n, fill = 0 ) %>%
  
  mutate(TRT_1_IMID = as.numeric( TRT_1_thal | TRT_1_len | TRT_1_pom) ) %>%
  
  # add therapy class from trt resp
  full_join(therapy.info,., by = "public_id") %>%
  full_join(.,other.treatments, by = "public_id") %>%
  
  rename(Patient = public_id)
Curated_Data_Sources/MMRF_IA10c/
  
  PutS3Table(curated.treatment, 
             file.path(s3, "ClinicalData/ProcessedData/Curated_Data_Sources/MMRF_IA10c",
                       "curated_MMRF_treatment_data_2017-05-11.txt"))

clinical <- order_by_dictionary(clinical, table = "clinical")

out <- append_df(clinical, curated.treatment, id = "Patient", mode = "safe")

PutS3Table(out, 
           file.path(s3, "ClinicalData/ProcessedData/JointData",
                     paste("curated.clinical",d,"txt",sep = ".")))

# update downstream tables 
table_flow()

