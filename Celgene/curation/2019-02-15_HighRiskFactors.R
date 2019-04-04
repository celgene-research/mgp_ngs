library(toolboxR)
library(tidyverse)
library(s3r)

# data sources:
# amp1q: CNV_CKS1B_ControlFreec
#        controlfreec call for cks1b as opposed to the consensus field 
#        (which integrates the FISH and controlfreec call)
#        
# tp53:  CYTO_del_17_17p_CONSENSUS & SNV_TP53_BinaryConsensus
#        bi-allelic inactivation call is del17p deletion + TP53 mutation, 
#        CNV_TP53_ControlFreec alone is just the deletion
#          
# t414: CYTO_t_4_14_CONSENSUS
#       Previously just using Manta, but will defer to CONSENSUS column 
#       as this would be more reliable for the future.
#       
# CNV_GENE_ControlFreec 
# 0=deletion; 1=loss; 2=normal; -2=loh; 3=gain; 4=amplification


s3_set(bucket = "celgene.rnd.combio.mmgp.external", 
       sse = T,
       cwd = "ClinicalData/ProcessedData/ND_Tumor_MM/")
s3_ls()

df   <- auto_read("~/Desktop/HR_mgp_patients.csv") %>% 
  rename(Patient = patient)

clin <- s3_get_table("per.patient.clinical.nd.tumor.2019-02-02.txt") %>% 
  select(Patient,D_Age, D_ISS, D_PFS, D_PFS_FLAG, D_OS, D_OS_FLAG, 
         D_Best_Response_Code, D_Best_Response,
         starts_with("TRT"))

meta <- s3_get_table("per.patient.metadata.nd.tumor.2019-02-02.txt") %>%
  select(Patient, Study)

trsl <- s3_get_table("per.patient.translocations.nd.tumor.2019-02-02.txt") %>% 
  select(Patient, File_Name, CYTO_t_4_14_CONSENSUS, CYTO_t_4_14_MANTA, CYTO_del_17_17p_CONSENSUS)

cnv  <- s3_get_table("per.patient.cnv.nd.tumor.2019-02-02.txt") %>% 
  select(Patient, File_Name,CNV_CKS1B_ControlFreec) %>% 
  select(-File_Name)

snv  <- s3_get_table("per.patient.snv.nd.tumor.2019-02-02.txt") %>% 
  select(Patient, SNV_TP53_BinaryConsensus)

# any(duplicated(snv$Patient))
# [1] FALSE
# 
# grep("tp53", x = names(snv), ignore.case = T, value = T)
# SNV_TP53_BinaryConsensus
# 
out <- clin %>% 
  left_join(meta, by = "Patient") %>% 
  left_join(trsl, by = "Patient") %>% 
  left_join(snv,  by = "Patient") %>% 
  left_join(cnv,  by = "Patient") %>% 
  left_join(df ,  by = "Patient") %>%
  mutate(cks1b_gain_DAN = as.integer(CNV_CKS1B_ControlFreec >= 3),
         bi_tp53_DAN    = as.integer(CYTO_del_17_17p_CONSENSUS & SNV_TP53_BinaryConsensus),
         t414_DAN       = CYTO_t_4_14_CONSENSUS)

table(select(out,cks1b_gain_DAN,cks1b_gain), useNA = 'always')
#                  cks1b_gain
# cks1b_gain_DAN   0   1 <NA>
#           0    558   0  204
#           1      0 226   90
#           <NA>   0   0  822
# Conclusion: good to go

foo <- select(out,Patient,CYTO_del_17_17p_CONSENSUS,SNV_TP53_BinaryConsensus,bi_tp53_DAN,bi_tp53)
venn::venn(list(Dan  = foo[foo$bi_tp53_DAN==1 & !is.na(foo$bi_tp53_DAN),"Patient"],
                Fadi = foo[foo$bi_tp53==1 & !is.na(foo$bi_tp53),"Patient"]))
# Dan - Intersect - Fadi
# 11  -    8      - 22

# Dan's bi_tp53 patients
# > foo[foo$bi_tp53_DAN==1 & !is.na(foo$bi_tp53_DAN),"Patient"]
# [1] "MMRF_1169" "MMRF_1364" "MMRF_1668" "MMRF_1774" "MMRF_1814" "MMRF_1816" "MMRF_1839" "MMRF_1841"
# [9] "MMRF_2083" "MMRF_2238" "MMRF_2251" "MMRF_2272" "MMRF_2608" "MMRF_2611" "PD5853"    "PD5855"   
# [17] "PD5861"    "PD5862"    "PD5889"   
# 
# Fadi's bi_tp53 patients
# > foo[foo$bi_tp53==1 & !is.na(foo$bi_tp53),"Patient"]
# [1] "MMRF_1424" "MMRF_1491" "MMRF_1533" "MMRF_1596" "MMRF_1641" "MMRF_1774" "MMRF_1816" "MMRF_1831"
# [9] "MMRF_1841" "MMRF_1890" "MMRF_1915" "MMRF_1981" "MMRF_2015" "MMRF_2083" "MMRF_2238" "MMRF_2251"
# [17] "MMRF_2272" "MMRF_2373" "MMRF_2535" "MMRF_2574" "MMRF_2611" "UAMS_0133" "UAMS_0221" "UAMS_0273"
# [25] "UAMS_0390" "UAMS_0429" "UAMS_0518" "UAMS_1058" "UAMS_1166" "UAMS_1187"

intersect(x = foo[foo$bi_tp53_DAN==1 & !is.na(foo$bi_tp53_DAN),"Patient"],
          y = foo[foo$bi_tp53==1 & !is.na(foo$bi_tp53),"Patient"])
# "MMRF_1774" "MMRF_1816" "MMRF_1841" "MMRF_2083" "MMRF_2238" "MMRF_2251" "MMRF_2272" "MMRF_2611"

table(select(out,bi_tp53_DAN,bi_tp53), useNA = 'always')


table(select(out,CYTO_t_4_14_MANTA,t414), useNA = 'always')
#                     t414
# CYTO_t_4_14_MANTA   0   1 <NA>
#              0    202   0  137
#              1      0 108   53
#           <NA> 474   0  926
# # Their calls were originally from Manta only

table(select(out,t414_DAN,t414), useNA = 'always')
# we are now using consensus calls, which
# reclassify some
#            t414
# t414_DAN   0   1 <NA>
#     0    648   0  781
#     1     26 108   76
#     2      0   0   25
#     <NA>   2   0  234



done <- select(out,
               Patient,Study, 
               cks1b_gain_DAN,bi_tp53_DAN,t414_DAN,
               D_Age, D_ISS, D_PFS, D_PFS_FLAG, D_OS, D_OS_FLAG, 
               D_Best_Response_Code, D_Best_Response,
               starts_with("TRT")) %>% 
  dplyr::rename(cks1b_gain = cks1b_gain_DAN,
                bi_tp53    = bi_tp53_DAN,
                t414       = t414_DAN)

auto_write(done, "~/thindrives/Downloads/HR_clinical_summary.tsv")
