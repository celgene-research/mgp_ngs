## 
## Dan Rozelle
## drozelle@ranchobiosciences.com
## 2019-01-24
## 
## MMRF ia13 metadata, clinical, blood table curation
## 


# change log 
# ia11 curation
# D_Gender source changed from `DEMOG_GENDER` to the coded field D_PT_gender
# 
# removed in ia13
# D_CM_WASCONVENTION	Was conventional cytogenics (metaphase) performed?
# D_CM_cm	Was conventional cytogenics performed (1=yes, 2=no)
# curated these instead
# D_TRI_CF_WASCYTOGENICS	Was Cytogenics / FISH performed?
# D_TRI_cf	Was Cytogenics/FISH performed

library(s3r)
library(tidyverse)
library(toolboxR)
source('curation_scripts.R')

Curated_Data_Sources <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/Curated_Data_Sources"

s3_set(bucket = "celgene.rnd.combio.mmgp.external", 
       sse = T,
       cwd = "ClinicalData/OriginalData/MMRF_IA13/CoMMpass_IA13_FlatFiles")

system('aws s3 sync s3://celgene.rnd.combio.mmgp.external/ClinicalData/OriginalData/MMRF_IA13/CoMMpass_IA13_FlatFile_Dictionaries ~/Desktop/ia13_dict')
system('aws s3 sync s3://celgene.rnd.combio.mmgp.external/ClinicalData/OriginalData/MMRF_IA11/clinical_data_tables/CoMMpass_IA11_FlatFile_Dictionaries ~/Desktop/ia11_dict')

# per-patient ----
patient <- s3_get_with("MMRF_CoMMpass_IA13_PER_PATIENT.csv", FUN = auto_read) %>%
  transmute(Patient  = PUBLIC_ID,
            D_Gender = recode(D_PT_gender, "Male", "Female"),
            D_Race   = recode(D_PT_race, "WHITE", "BLACKORAFRICAN", "AMERICANINDIAN", "ASIAN", "NATIVEHAWAIIAN", "OTHER"),
            D_Age    = D_PT_age,
            D_ISS    = D_PT_iss,
            D_Cause_of_Death             =  D_PT_CAUSEOFDEATH,
            D_Reason_for_Discontinuation =  D_PT_PRIMARYREASON,
            D_Discontinued               =  D_PT_discont,
            D_Complete                   =  recode(D_PT_complete, "2" = 0)  ) 

s3_ls(Curated_Data_Sources)
# s3_put_table(patient, Curated_Data_Sources, 'MMRF_IA13/curated_MMRF_PER_PATIENT.txt')

# per-visit ----
visit   <- s3_get_with("MMRF_CoMMpass_IA13_PER_PATIENT_VISIT.csv", FUN = auto_read) %>%
  # we only want visit information where a sample was collected
  filter(SPECTRUM_SEQ != "") %>%
  # some entries are duplicated when CMMC adds a comment, not necessary for our study
  filter( !duplicated(SPECTRUM_SEQ)) %>%
  
  # calculate per-patient values from visit table
  group_by(PUBLIC_ID) %>%
  mutate(
    D_Response_Assessment = max(AT_RESPONSEASSES),
    D_Last_Visit          = max(VISITDY),
    bmt                   = if_else( suppressWarnings(VISITDY > min(BMT_DAYOFTRANSPL, na.rm = T)), 1,0,0)) %>%
  ungroup() %>%
  
  transmute(
    Patient                 = PUBLIC_ID,
    Sample_Sequence         = SPECTRUM_SEQ,
    # visit_time will be appended to visit_name captured from seqqc (e.g. "Confirm Progression; Month 3")
    Visit_Time              = VJ_INTERVAL,
    Disease_Status          = ifelse(grepl("Baseline",  VJ_INTERVAL, ignore.case = T),"ND", "R"),
    Sample_Study_Day        = BA_DAYOFASSESSM,
    
    D_Response_Assessment   = D_Response_Assessment,
    D_Last_Visit            = D_Last_Visit,
    D_PrevBoneMarrowTransplant  = bmt,
    
    # fields for *has cytogenetics/fish* no longer captured
    # These were removed from MMRF and we can just make these calls from available data

    CYTO_Hyperdiploid_FISH  = as.numeric(  Hyperdiploid == "Yes" ),
    CYTO_MYC_FISH           = as.numeric(  D_TRI_CF_ABNORMALITYPR5 == "Yes" ),
    CYTO_1qplus_FISH        = as.numeric( D_TRI_CF_ABNORMALITYPR13 == "Yes" ),
    `CYTO_del(1p)_FISH`       = as.numeric( D_TRI_CF_ABNORMALITYPR12 == "Yes" ),
    `CYTO_t(4;14)_FISH`       = as.numeric( D_TRI_CF_ABNORMALITYPR3  == "Yes" ),
    `CYTO_t(6;14)_FISH`       = as.numeric( D_TRI_CF_ABNORMALITYPR4  == "Yes" ),
    `CYTO_t(11;14)_FISH`      = as.numeric( D_TRI_CF_ABNORMALITYPR6  == "Yes" ),
    `CYTO_t(12;14)_FISH`      = as.numeric( D_TRI_CF_ABNORMALITYPR7  == "Yes" ),
    `CYTO_t(14;16)_FISH`      = as.numeric( D_TRI_CF_ABNORMALITYPR8  == "Yes" ),
    `CYTO_t(14;20)_FISH`      = as.numeric( D_TRI_CF_ABNORMALITYPR9  == "Yes" ),
    `CYTO_amp(1q)_FISH`       = as.numeric( D_TRI_CF_ABNORMALITYPR13 == "Yes" ),
    `CYTO_del(13q)_FISH`      = as.numeric( D_TRI_CF_ABNORMALITYPR   == "Yes" ),
    `CYTO_del(17;17p)_FISH`   = as.numeric( D_TRI_CF_ABNORMALITYPR2   == "Yes" |
                                              D_TRI_CF_ABNORMALITYPR11   == "Yes"),
    CBC_Absolute_Neutrophil = D_LAB_cbc_abs_neut,
    CBC_Platelet            = D_LAB_cbc_platelet,
    CBC_WBC                 = D_LAB_cbc_wbc,
    DIAG_Hemoglobin         = D_LAB_cbc_hemoglobin,
    DIAG_Albumin            = D_LAB_chem_albumin,
    DIAG_Calcium            = D_LAB_chem_calcium,
    DIAG_Creatinine         = D_LAB_chem_creatinine,
    DIAG_LDH                = D_LAB_chem_ldh,
    DIAG_Beta2Microglobulin = D_LAB_serum_beta2_microglobulin,
    CHEM_BUN                = D_LAB_chem_bun,
    CHEM_Glucose            = D_LAB_chem_glucose,
    CHEM_Total_Protein      = D_LAB_chem_totprot,
    CHEM_CRP                = D_LAB_serum_c_reactive_protein,
    IG_IgL_Kappa            = D_LAB_serum_kappa,
    IG_M_Protein            = D_LAB_serum_m_protein,
    IG_IgA                  = D_LAB_serum_iga,
    IG_IgG                  = D_LAB_serum_igg,
    IG_IgL_Lambda           = D_LAB_serum_lambda,
    IG_IgM                  = D_LAB_serum_igm,
    IG_IgE                  = D_LAB_serum_ige ) %>% 
  arrange(Sample_Sequence)

if( !all(visit$Disease_Status %in% c("ND", "R")) )warning("Check Disease_Status mapping, some not matched") 
hist(visit$Sample_Study_Day, breaks = 1000, xlim = c(-100,100))

# confirm that last visit is >= sample day trend
ggplot(visit, aes(x=Sample_Study_Day, y = D_Last_Visit)) + 
  geom_point() +
  geom_abline(slope = 1)

# s3_put_table(visit, Curated_Data_Sources, 'MMRF_IA13/curated_MMRF_PER_PATIENT_VISIT.txt')

# make a per-patient version to join with METADATA table
visit_p <- visit %>%
  select(Patient, D_Response_Assessment, D_Last_Visit) %>%
  unique()
 
# make another subset to join with METADATA table
visit_m <- visit %>%
  select(Sample_Sequence, Visit_Time, Sample_Study_Day, Disease_Status, D_PrevBoneMarrowTransplant) %>%
  unique() 

# make another subset to join with BLOOD table
visit_b <- visit %>%
  select(Patient, Sample_Sequence, CBC_Absolute_Neutrophil:IG_IgE)
  
# survival ----
surv <- s3_get_with("MMRF_CoMMpass_IA13_STAND_ALONE_SURVIVAL.csv", FUN = auto_read) %>%
  transmute(Patient      = public_id,
            D_OS         = ttcos,
            D_OS_FLAG    = censos,
            D_PFS        = ttcpfs,
            D_PFS_FLAG   = censpfs,
            D_PD         = ttfpd,
            D_PD_FLAG    = pdflag)

# s3_put_table(surv, Curated_Data_Sources, 'MMRF_IA13/curated_MMRF_SURVIVAL.txt')

# medical history ----
medhist <- s3_get_with("MMRF_CoMMpass_IA13_STAND_ALONE_MEDHX.csv", FUN = auto_read) %>%
  mutate(Patient = public_id) %>%
  group_by(Patient) %>%
  summarise(D_Medical_History = Simplify(medx))

# s3_put_table(medhist, Curated_Data_Sources, 'MMRF_IA13/curated_MMRF_MEDHX.txt')

# family history ----
famhist <- s3_get_with("MMRF_CoMMpass_IA13_STAND_ALONE_FAMHX.csv", FUN = auto_read) %>%
  mutate(Patient      = public_id) %>%
  group_by(Patient) %>%
  summarize( D_Family_Cancer_History = case_when(
    "Yes" %in% FAMHX_ISTHEREAFAMIL ~ "Yes",
    "No" %in% FAMHX_ISTHEREAFAMIL ~ "No",
    TRUE ~ NA_character_ ) ) 

# s3_put_table(famhist, Curated_Data_Sources, 'MMRF_IA13/curated_MMRF_FAMHX.txt')

# treatment response ----
treat <- s3_get_with("MMRF_CoMMpass_IA13_STAND_ALONE_TRTRESP.csv", FUN = auto_read) %>%
  filter(line == 1) %>%
  group_by(public_id) %>%
  mutate(bmtx_day = min(bmtx_day)) %>%
  mutate(bmtx_seq = max(bmtx_seq)) %>%
  ungroup() %>%
  filter(therbresp == 1 ) %>%
  # clean up therapy naming
  mutate(thername  = gsub(" +\\+ +", "; ", thername) ) %>%
  mutate(thername  = gsub("\\/", "-", thername) ) %>%
  mutate(thershnm  = gsub(" +\\+ +", "; ", thershnm) ) %>%
  transmute(Patient           = public_id,
            TRT_1_trtgroup    = trtgroup,        
            TRT_1_therstdy    = therstdy,        
            TRT_1_therendy    = therendy,        
            TRT_1_thername    = thername,        
            TRT_1_thershnm    = thershnm,        
            TRT_1_therclass   = therclass,         
            TRT_1_bmtx_rec    = bmtx_rec,        
            TRT_1_bmtx_type   = bmtx_type,         
            TRT_1_bmtx_n      = if_else( is.na(bmtx_seq), as.numeric(0), bmtx_seq ),      
            TRT_1_bmtx_day    = bmtx_day,
            D_Best_Response_Code = bestrespcd,
            D_Best_Response      = bestresp  ) %>%
  
  # split drug tratments into individual binary flag columns
  mutate(drugs = gsub("[\\(\\)\\.]", "", tolower(TRT_1_thershnm)) ) %>% 
  mutate(drugs = strsplit(drugs, split = "; |-") ) %>% 
  unnest(drugs) %>%
  unique() %>%
  group_by(drugs) %>%
  mutate(n    = n(),
         drug = if_else( n < 3, "other", drugs ),
         drug = paste0("TRT_1_", drug),
         val = 1) %>%
  ungroup() %>%
  select(-drugs, -n) %>%
  unique() %>%
  spread(drug, val, fill=0) %>%
  mutate(TRT_1_IMID = if_else(TRT_1_thal | TRT_1_len | TRT_1_pom, 1, 0))

# s3_put_table(treat, Curated_Data_Sources, 'MMRF_IA13/curated_MMRF_TRTRESP.txt')

# seqqc ----
s3_cd('s3://celgene.rnd.combio.mmgp.external/ClinicalData/OriginalData')
seqqc   <- s3_get_with("MMRF_IA13/MMRF_IA13/MMRF_CoMMpass_IA13_Seq_QC_Summary.xlsx", 
                       FUN = auto_read, fun.args = list(na = c("", "?"))) %>%
  transmute(File_Name = QC.Link.SampleName,
            Sample_Name      = gsub("^(MMRF.*[BMP]+)_.*", "\\1", File_Name),
            Patient          = Patients..KBase_Patient_ID,
            Visit_Name       = Visits..Reason_For_Collection,
            
            Sample_Sequence  = gsub("^(MMRF.*)_[BMP]+_.*", "\\1",  File_Name),
            Sequencing_Type  = case_when(
              grepl("^RNA", .$MMRF_Release_Status)   ~ "RNA-Seq",
              grepl("^Exome", .$MMRF_Release_Status) ~ "WES",
              grepl("^LI", .$MMRF_Release_Status)    ~ "WGS",
              TRUE ~ as.character(NA)),
            Excluded_Flag    = as.numeric(grepl("^Exclude|RNA-No|LI-Neither|Exome-Neither",
                                                .$MMRF_Release_Status)),
            Excluded_Specify = MMRF_Release_Status) %>%
  arrange(Sample_Name)


if( !all(filter(seqqc, Excluded_Flag==0)$Sequencing_Type %in% c("WES", "WGS", "RNA-Seq")) ){
  warning("Check Sequencing_Type mapping, some not matched") }

# s3_put_table(seqqc, Curated_Data_Sources, 'MMRF_IA13/curated_MMRF_Seq_QC_Summary.txt')


# NMF_mutation_signature ----
nmf   <- s3_get_with("Joint/2017-03-08_NMF_mutation_signature.txt", 
                       FUN = auto_read) %>%
  rename(File_Name = FullName,
         NMF_Signature_Cluster= NMF2)

# at the time of curation we hadn't added any new sequencing files yet, so we can just use the last version
inv <- s3_get_table(Curated_Data_Sources, 'MMRF_IA11/curated_mmrf-file-inventory.txt') %>% 
  mutate(Patient = gsub("(MMRF_\\d{4})_.*","\\1",File_Name))

# Joint tables to produce JointData versions
s3_cd('s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/JointData')

# clinical table ----
s3_ls()
# get the current full table
prev.clinical <- s3_get_table("curated.clinical.2018-07-10.txt") 

# join together all the new MMRF data
clinical.mmrf <- patient %>%
  left_join(visit_p) %>%
  left_join(surv) %>%
  left_join(medhist) %>%
  left_join(famhist) %>%
  left_join(treat) 

# check out which columns we're missing
names(prev.clinical)[!(names(prev.clinical) %in% names(clinical.mmrf) )]
# # we don't have any examples of some drug treatment samples
# "TRT_1_bend"        "TRT_1_vin"         "TRT_1_other_names" 
# or any of the *Date* fields since we only have study day versions
# "D_Diagnosis_Date"  "D_Relapse_Date"    "D_Death_Date"      "D_Last_Visit_Date"

# we need to just replace the MMRF portion of each table
clinical <- update_values(clinical.mmrf, prev.clinical, Patient)
# what patients are new
clinical[!clinical$Patient %in% prev.clinical$Patient, "Patient"]
# 31 new subjects, MMRF_2813 and higher

# write_new_version(clinical, name = "curated.clinical", dir = 's3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/JointData')

# metadata table ----
meta.mmrf <- inv %>%
  left_join(seqqc) %>%
  left_join(visit_m) %>%
  # visit_time from visit_m appended to visit_name from seqqc 
  # (e.g. "Confirm Progression; Month 3")
  mutate( Visit_Name = map2_chr(Visit_Name, Visit_Time, function(x,y){Simplify(c(x,y))})) %>%
  left_join(nmf) %>% 
  # correct case for this strange one
  mutate(File_Name = gsub("MMRF_1130_1_PB_Whole_C1_TSWGL_k03552", "MMRF_1130_1_PB_Whole_C1_TSWGL_K03552",File_Name))

s3_ls()
# compare with the previous version
prev.meta <- s3_get_table("curated.metadata.2018-07-20.txt") 
names(prev.meta)[!(names(prev.meta) %in% names(meta.mmrf) )]

# was a single DFCI sample with Cell_Type="CD138", corrected to "CD138pos"
prev.meta['Cell_Type'] <- gsub("^CD138$", "CD138pos", prev.meta$Cell_Type)

# list what celltype-tissue type combos are observed in each disease
prev.meta %>% group_by(Patient, Disease_Type) %>% 
  unite("combo", c('Cell_Type', 'Tissue_Type') ) %>% 
  summarise(combos = Simplify(combo)) %>% 
  group_by(Disease_Type, combos) %>%
  count() %>% 
  spread(Disease_Type,n)

# flag any patients that have/had a CD138pos PB sample
meta <- update_values(meta.mmrf, prev.meta, File_Name)

# check for required columns
any(is.na(meta$Patient))
table(meta$Study, useNA = 'always')
table(meta$Study_Phase,meta$Study, useNA = 'always') 
# we don't have IA13 defined, but that is because we didn't get a PackageBuildValidator file
# we should be able to add this later
table(meta$Sample_Type,meta$Sample_Type_Flag, useNA = 'always')
any(is.na(meta$File_Name))
table(meta$Sequencing_Type, meta$Excluded_Flag, useNA = 'always')
# some samples don't have SeqType, but they're all excluded
#              0    1 <NA>
#   RNA-Seq  868   40  388
#   WES     2066   46 1100
#   WGS     1930   64    4
#   <NA>       0  160    0

table(meta$Disease_Status, useNA = 'always')
table(meta$Tissue_Type, useNA = 'always')
table(meta$Cell_Type, useNA = 'always')
table(meta$Disease_Type, useNA = 'always')

# check for duplicate rows
any(is.na(meta$File_Name))
any(duplicated(tolower(meta$File_Name)))

# show me any patients that have duplicate types of samples
foo <- meta %>% 
  group_by(Study,Patient,Tissue_Type,Cell_Type,Sequencing_Type,Sample_Type)  %>% 
  select(File_Name, Excluded_Flag, Study,Patient,Tissue_Type,Cell_Type,Sequencing_Type,Sample_Type)  %>% 
  arrange(Study,Patient,Tissue_Type,Cell_Type,Sequencing_Type,Sample_Type)  %>% 
  mutate(n=n()) %>% 
  filter(n>1)
# these show longitudinal samples

# write_new_version(meta, name = "curated.metadata", dir = 's3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/JointData')

# blood table ----
# blood is a File_Name based table with Patient column
blood.mmrf <- seqqc %>%
  select(File_Name, Sample_Sequence) %>%
  left_join(visit_b) %>%
  select(-Sample_Sequence)

s3_ls()
prev.blood <- s3_get_table("curated.blood.2018-07-20.txt") 
names(prev.blood)[!(names(prev.blood) %in% names(blood.mmrf) )]
blood <- update_values(blood.mmrf, prev.blood, File_Name)

# write_new_version(blood, name = "curated.blood", dir = 's3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/JointData')

# process table flow to incorporate new IA11 clinical data into Master/NDMM/Cluster tables
table_flow()



