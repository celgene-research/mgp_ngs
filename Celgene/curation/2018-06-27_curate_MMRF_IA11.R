## drozelle@ranchobiosciences.com
## MMRF ia11 metadata, clinical, blood table curation

# change log from ia10 curation
# D_Gender source changed from `DEMOG_GENDER` to the coded field D_PT_gender
# 


library(s3r)
library(tidyverse)
library(toolboxR)

s3_set(bucket = "celgene.rnd.combio.mmgp.external", 
       sse = T, 
       cwd = "ClinicalData/OriginalData/MMRF_IA11a/clinical_data_tables/CoMMpass_IA11_FlatFiles")

# per-patient ----
patient <- s3_get_with("MMRF_CoMMpass_IA11_PER_PATIENT.csv", FUN = auto_read) %>%
  transmute(Patient  = PUBLIC_ID,
            D_Gender = recode(D_PT_gender, "Male", "Female"),
            D_Race   = recode(D_PT_race, "WHITE", "BLACKORAFRICAN", "AMERICANINDIAN", "ASIAN", "NATIVEHAWAIIAN", "OTHER"),
            D_Age    = D_PT_age,
            D_ISS    = D_PT_iss,
            D_Cause_of_Death             =  D_PT_CAUSEOFDEATH,
            D_Reason_for_Discontinuation =  D_PT_PRIMARYREASON,
            D_Discontinued               =  D_PT_discont,
            D_Complete                   =  recode(D_PT_complete, "2" = 0)  ) 

# per-visit ----
visit   <- s3_get_with("MMRF_CoMMpass_IA11_PER_PATIENT_VISIT.csv", FUN = auto_read) %>%
  # we only want visit information where a sample was collected
  filter(SPECTRUM_SEQ != "") %>%
  # some entries are duplicated when CMMC adds a comment, not necessary for our study
  filter( !duplicated(SPECTRUM_SEQ)) %>%
  
  # calculate per-patient values from visit table
  group_by(PUBLIC_ID) %>%
  mutate(
    D_Response_Assessment = max(AT_RESPONSEASSES, na.rm = T),
    D_Last_Visit          = max(VISITDY, na.rm = T),
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
    
    CYTO_Has_Conventional_Cytogenetics           = as.numeric( D_CM_cm == 1 ),
    CYTO_Has_Conventional_Metaphase_Cytogenetics = as.numeric( D_CM_WASCONVENTION == 1 ),
    CYTO_Has_Cytogenetics_FISH_Performed         = as.numeric( D_TRI_CF_WASCYTOGENICS == 1 ),
    CYTO_Has_cIg_staining_with_FISH              = as.numeric( D_TRI_CF_WASCLGFISHORP == 1 ),
    CYTO_Has_FISH                                = as.numeric( D_TRI_cf == 1 ),
    
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

# survival ----
surv <- s3_get_with("MMRF_CoMMpass_IA11_STAND_ALONE_SURVIVAL.csv", FUN = auto_read) %>%
  transmute(Patient      = public_id,
            D_OS         = ttcos,
            D_OS_FLAG    = censos,
            D_PFS        = ttcpfs,
            D_PFS_FLAG   = censpfs,
            D_PD         = ttfpd,
            D_PD_FLAG    = pdflag)

# medical history ----
medhist <- s3_get_with("MMRF_CoMMpass_IA11_STAND_ALONE_MEDHX.csv", FUN = auto_read) %>%
  transmute(Patient      = public_id,
            D_Medical_History = medx )

# medical history ----
famhist <- s3_get_with("MMRF_CoMMpass_IA11_STAND_ALONE_FAMHX.csv", FUN = auto_read) %>%
  transmute(Patient      = public_id,
            D_Family_Cancer_History =if_else( FAMHX_ISTHEREAFAMIL %in% c("Yes", "No"), 
                                              FAMHX_ISTHEREAFAMIL, "") )

# treatment response ----
treat <- s3_get_with("MMRF_CoMMpass_IA11_STAND_ALONE_TRTRESP.csv", FUN = auto_read) %>%
  filter(line == 1) %>%
  group_by(public_id) %>%
  mutate(bmtx_day = min(bmtx_day, na.rm = T)) %>%
  mutate(bmtx_seq = max(bmtx_seq, na.rm = T)) %>%
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
            TRT_1_bmtx_n      = if_else( is.na(bmtx_seq), as.integer(0), bmtx_seq ),      
            TRT_1_bmtx_day    = bmtx_day     ) %>%
  
  # split drug tratments into individual binary flag columns
  mutate(drugs = gsub("[\\(\\)\\.]", "", tolower(TRT_1_thershnm)) ) %>% 
  mutate(drugs = strsplit(drugs, split = "; |-") ) %>% 
  unnest(drugs) %>%
  unique() %>%
  group_by(drugs) %>%
  mutate(n    = n(),
         drug = if_else( n < 5, "other", drugs ),
         drug = paste0("TRT_1_", drug),
         val = 1) %>%
  ungroup() %>%
  select(-drugs, -n) %>%
  unique() %>%
  spread(drug, val, fill=0) %>%
  mutate(TRT_1_IMID = if_else(TRT_1_thal | TRT_1_len | TRT_1_pom, 1, 0))

# seqqc ----
seqqc   <- auto_read("../../../data/CoMMpass_IA11_FlatFiles/MMRF_CoMMpass_IA11_Seq_QC_Summary.xlsx", na = "?") %>%
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

if( all(seqqc$Disease_Status %in% c("ND", "R")) )warning("Check Disease_Status mapping, some not matched") 
if( all(seqqc$Sequencing_Type %in% c("WES", "WGS", "RNA-Seq")) )warning("Check Sequencing_Type mapping, some not matched") 

# ClinicalData/OriginalData/Joint/2017-03-08_NMF_mutation_signature.txt
# *File_Name
# NMF_Signature_Cluster
# 
# ClinicalData/ProcessedData/Curated_Data_Sources/mutational.burden.2017-07-07.txt
# *File_Name
# SNV_total_ns_variants_n
# SNV_ns_mutated_genes_n
# SNV_dbNSFP_Polyphen2_HDIV_pred_deleterious_variants_n
# SNV_dbNSFP_Polyphen2_HVAR_pred_deleterious_variants_n
# SNV_dbNSFP_Polyphen2_HDIV_pred_deleterious_genes_n
# SNV_dbNSFP_Polyphen2_HVAR_pred_deleterious_genes_n
