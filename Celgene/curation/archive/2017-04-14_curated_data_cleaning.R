# 2017-04-14 Dan Rozelle
# Before running the next inventory counts I have a few random
# fixing and clean tasks to perform
#   all curated "JointData" tables should have File_Name and Patient 
#   identifiers where possible. Include all valid results (including valid 
#   information about patients that are excluded from analysis (e.g. PCL, R samples)
# 
# The table will:
# Filter columns in Clinical and Metadata tables to match revised dictionary
# 
# Add NMF signatures, HRD calls, and inventory binary columns to metadata table
# 
# Add Patient identifiers to remaining tables.
# 

source("curation_scripts.R")
dict <- dict()

copy.s3.to.local(file.path(s3, "ClinicalData/ProcessedData/JointData"),
                 aws.args = '--recursive --exclude "*" --include "curated_*" --exclude "archive*"')
f <- list.files(local, full.names = T)
joint <- lapply(f, fread)
names(joint) <- gsub("curated_([a-z]+).*", "\\1", tolower(basename(f)))
names(joint)

######################
# curate clinical and metadata tables based on dictionary revisions
# remove Study, INV columns from clinical
joint$clinical <- joint$clinical %>%  select(-c(Study, starts_with("INV")))

######################
# Add all missing dictionary columns to translocation table, fill NA
current.names <- names(joint$translocations)
fixed.names   <- gsub("[\\(\\)\\;\\._]+", "_", current.names)
names(joint$translocations) <- fixed.names
dict.names    <- dict$names[grepl("translocations", dict$level)]
l             <- nrow(joint$translocations)

t <- lapply(dict.names, function(x){
  if( x %in% fixed.names ) {as.character(joint$translocations[[x]])
  }else rep(as.character(NA), times = l)
})

t        <- data.table(data.frame(t, stringsAsFactors = FALSE))
names(t) <- dict.names

######################
# replace blank hyperdiploid column with new info on translocation table
joint$translocations <- GetS3Table(file.path(s3, "ClinicalData/OriginalData/Joint/2017-04-14_HRD_Calls_from_Cody.txt"), reader = "fread")%>% 
  mutate( File_Name = case_when(
    grepl("^_E", .$SAMPLE.ID) ~ gsub(".*_([A-Za-z].*)", "\\1", .$SAMPLE.ID),
    grepl("^H", .$SAMPLE.ID)  ~ gsub("HUMAN_37_pulldown_", "", .$SAMPLE.ID),
    TRUE ~ .$SAMPLE.ID),
    CYTO_Hyperdiploid_CONSENSUS = as.numeric(HRD_STATUS == "HRD") ) %>%
  select(File_Name, CYTO_Hyperdiploid_CONSENSUS) %>%
  left_join(select(t, -CYTO_Hyperdiploid_CONSENSUS), ., by = "File_Name") %>% as.data.table

# # get a list of the nd.tumor File_Names for each patient for summarizing 
# # ND.tumor-specific translocation consensus
# # summary table with patient and nd.consensus
# nd.tumor.files <- joint$translocations %>%
#   select(File_Name, grep("CYTO_t_.*_CONSENSUS", names(.))) %>%
#   left_join(  joint$metadata[Disease_Status == "ND" & 
#                                Sample_Type_Flag == 1, 
#                              .(Patient, File_Name)], ., by = "File_Name")
# 
# tmp <- nd.tumor.files %>%
#   gather(variable, value, -c(Patient, File_Name)) %>%
#   mutate(type = gsub("CYTO_t_(.*)_CONSENSUS", "\\1", variable),
#          type = gsub("^14_|_14$", "", type),
#          type = ifelse(value == 1, as.numeric(type), NA)) %>%
#   group_by(Patient) %>%
#   summarize(call = Simplify(type) )
#   NOTE: filtering to nd.tumor samples didn't remove any non-unique 
#   Translocation_Consensus calls. All of the problems stem from MMRF samples that
#   I don't have MANTA calls from...can we get these?

######################
# Import NMF signatures to append to metadata table
nmf <- GetS3Table(file.path(s3, "ClinicalData/OriginalData/Joint/2017-03-08_NMF_mutation_signature.txt")) %>% 
  mutate(
    File_Name = case_when(
      grepl("^_E", .$FullName) ~ gsub(".*_([A-Za-z].*)", "\\1", .$FullName),
      grepl("^H", .$FullName)  ~ gsub("HUMAN_37_pulldown_", "", .$FullName),
      TRUE ~ .$FullName),
    NMF_Signature_Cluster = NMF2) %>%
  select(File_Name, NMF_Signature_Cluster)

# remove Disease_Type and add INV columns for other tables
joint$metadata <- joint$metadata %>%  #select(-c(Disease_Type)) %>%
  mutate( 
    INV_Has.Blood          = as.numeric(File_Name %in% joint$blood[['File_Name']]),
    INV_Has.BI             = as.numeric(File_Name %in% joint$biallelicinactivation[['File_Name']]),
    INV_Has.Clinical       = as.numeric(Patient   %in% joint$clinical[['Patient']]),
    INV_Has.CNV            = as.numeric(File_Name %in% joint$cnv[['File_Name']]),
    INV_Has.RNASeq         = as.numeric(File_Name %in% joint$rnaseq[['File_Name']]),
    INV_Has.SNV            = as.numeric(File_Name %in% joint$snv[['File_Name']]),
    # only count translocations that have a unique final consensus called
    INV_Has.Translocations = as.numeric(File_Name %in% filter(joint$translocations, (CYTO_Translocation_Consensus %in% c("None", "4", "6", "11", "12", "16", "20")) )[['File_Name']]  )  )  %>%
  left_join(nmf, by = "File_Name") %>% as.data.table

# Add Patient identifiers and sort columns
map <- joint$metadata[,.(Patient, File_Name)]
setkey(map, File_Name)
out <- lapply(joint, function(dt){
  if( !is.data.table(dt) ){dt <- as.data.table(dt)}
  
  # remove existing patient columns from tables (except clinical table)
  if( "File_Name" %in% names(dt) & "Patient" %in% names(dt) ){ dt[,Patient:=NULL] }
  
  if( "File_Name" %in% names(dt) ){
    setkey(dt, File_Name)
    map[dt]
  }else {
    dt}
})

# move source files to archive before writing new versions
system('aws s3 mv  s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/JointData/   s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/JointData/2017-04-17_pre_curation_updates/ --recursive --exclude "*" --include "curated*" --exclude "archive*" --sse')

NULL <- lapply(names(out), function(n){
  name <- paste("curated", n, "2017-04-17.txt", sep = "_")
  PutS3Table(out[[n]], file.path(s3, "ClinicalData/ProcessedData/JointData", name))
  
})
