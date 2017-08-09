source("curation_scripts.R")
s3_cd("/ClinicalData/OriginalData")
ia9_patient  <- s3_get_csv("MMRF_IA9/PER_PATIENT.csv")
ia9_visit    <- s3_get_csv("MMRF_IA9/PER_PATIENT_VISIT.csv")
ia10_patient <- s3_get_csv("MMRF_IA10c/clinical_data_tables/CoMMpass_IA10c_FlatFiles",
                           "PER_PATIENT.csv")
ia10_visit   <- s3_get_csv("MMRF_IA10c/clinical_data_tables/CoMMpass_IA10c_FlatFiles",
                           "PER_PATIENT_VISIT.csv")

ia9_patient %>%
  left_join(ia9_visit, by = "PUBLIC_ID") %>%
  filter( grepl("MMRF_1300", SPECTRUM_SEQ) ) %>% 
  select(SPECTRUM_SEQ, D_LAB_chem_albumin, D_LAB_serum_beta2_microglobulin, D_PT_iss)

ia10_patient %>%
  left_join(ia10_visit, by = "PUBLIC_ID") %>%
  filter( grepl("MMRF_1300", SPECTRUM_SEQ) ) %>% 
  select(SPECTRUM_SEQ, D_LAB_chem_albumin, D_LAB_serum_beta2_microglobulin, D_PT_iss)

# Were any other patients where this exact condition occurred (ISS was available in IA9, but not in IA10?
ia9_patient %>%
  transmute(patient = PUBLIC_ID, IA9_ISS = D_PT_iss) %>%
  left_join(transmute(ia10_patient, patient = PUBLIC_ID, IA10_ISS = D_PT_iss),
            by = "patient") %>%
  filter(IA9_ISS != IA10_ISS | is.na(IA9_ISS) | is.na(IA10_ISS)) %>%
  arrange(patient)

# MMRF_1264 and MMRF_1300 are the only patients that changed status, 28 others were NA for both releases.
ia9_patient %>%
  left_join(ia9_visit, by = "PUBLIC_ID") %>%
  filter( SPECTRUM_SEQ %in% c("MMRF_1300_1", "MMRF_1264_1") ) %>% 
  select(SPECTRUM_SEQ, D_LAB_chem_albumin, D_LAB_serum_beta2_microglobulin, D_PT_iss)

ia10_patient %>%
  left_join(ia10_visit, by = "PUBLIC_ID") %>%
  filter( SPECTRUM_SEQ %in% c("MMRF_1300_1", "MMRF_1264_1") ) %>% 
  select(SPECTRUM_SEQ, D_LAB_chem_albumin, D_LAB_serum_beta2_microglobulin, D_PT_iss)
