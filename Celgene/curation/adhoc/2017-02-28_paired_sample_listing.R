files.by.sample <- per.file %>% 
  filter(Study == "MMRF" & grepl("BM_CD138pos", File_Name)) %>%
  select(Sample_Name, File_Name, Sequencing_Type) %>% 
  group_by(Sample_Name, Sequencing_Type) %>%
  summarise(File_Name = toolboxR::Simplify(File_Name) ) %>%
  spread(key = Sequencing_Type, value = File_Name)

write.table(files.by.sample, "files.by.sample.txt", sep = "\t", row.names = F, quote = F)

samples.with.paired.wes.rna <- files.by.sample %>%
  filter(!is.na(`RNA-Seq`) & !is.na(WES)) %>%
  select(-WGS)
samples.with.paired.wes.rna
# Source: local data frame [671 x 3]
# Groups: Sample_Name [671]
# 
# Sample_Name                               `RNA-Seq`                                     WES
# <chr>                                   <chr>                                   <chr>
#1  MMRF_1021_1_BM MMRF_1021_1_BM_CD138pos_T2_TSMRU_L01873 MMRF_1021_1_BM_CD138pos_T2_KAS5U_L02366
# 2  MMRF_1024_2_BM MMRF_1024_2_BM_CD138pos_T2_TSMRU_K03518 MMRF_1024_2_BM_CD138pos_T2_KHS5U_L13428
# 3  MMRF_1029_1_BM MMRF_1029_1_BM_CD138pos_T1_TSMRU_L02334 MMRF_1029_1_BM_CD138pos_T2_KAS5U_L02446
# 4  MMRF_1030_1_BM MMRF_1030_1_BM_CD138pos_T1_TSMRU_L02331 MMRF_1030_1_BM_CD138pos_T2_KAS5U_L02445
# 5  MMRF_1031_1_BM MMRF_1031_1_BM_CD138pos_T2_TSMRU_K02300 MMRF_1031_1_BM_CD138pos_T2_TSE61_K02456
# 6  MMRF_1032_1_BM MMRF_1032_1_BM_CD138pos_T2_TSMRU_L00033 MMRF_1032_1_BM_CD138pos_T2_TSE61_L00053
# 7  MMRF_1033_1_BM MMRF_1033_1_BM_CD138pos_T2_TSMRU_K02302 MMRF_1033_1_BM_CD138pos_T2_TSE61_K02461
# 8  MMRF_1037_1_BM MMRF_1037_1_BM_CD138pos_T2_TSMRU_K02298 MMRF_1037_1_BM_CD138pos_T2_TSE61_K02458
# 9  MMRF_1038_1_BM MMRF_1038_1_BM_CD138pos_T2_TSMRU_K02299 MMRF_1038_1_BM_CD138pos_T2_TSE61_K02459
# # 10 MMRF_1045_1_BM MMRF_1045_1_BM_CD138pos_T2_TSMRU_L02833 MMRF_1045_1_BM_CD138pos_T1_KBS5U_L02849
# ... with 661 more rows
# write.table(samples.with.paired.wes.rna, "samples.with.paired.wes.rna.txt", sep = "\t", row.names = F, quote = F)


nrow(samples.with.paired.wes.rna)
# 671