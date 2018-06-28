library(tidyverse)
library(s3r)

s3_set(bucket = "celgene.rnd.combio.mmgp.external", 
       sse = T)

# we need an srr map for WGS files that aren't self-identified
srr_map <- s3_get_table("ClinicalData/OriginalData/MMRF_IA10c/data.import.WGS.Kostas.IA3-IA7.txt") %>%
  select(display_name, filename) %>%
  separate(filename, c("filename", "R2"), sep = ",") %>%
  mutate(File_Name = display_name,
         File_Name_Actual = basename(filename)) %>%
  select(File_Name, File_Name_Actual)

# IA lookup table
ia_map <- s3_get_table("ClinicalData/OriginalData/MMRF_IA11a/README_FILES/MMRF_CoMMpass_IA11_PackageBuildValidator.txt", 
                       fun.args = list( header = F)) %>%
  transmute(File_Name = V4, Study_Phase = V7)


# grab FileNameActual locations from s3
s3_set(bucket = "celgene.rnd.combio.mmgp.external", sse = T)
wes <- s3_ls("SeqData/WES/OriginalData/MMRF", recursive = T, full.names = T, pattern = "bam$")
rna <- s3_ls("SeqData/RNA-Seq/OriginalData/MMRF", recursive = T, full.names = T, pattern = "bam$")
wgs <- s3_ls("SeqData/WGS/OriginalData/MMRF", recursive = T, full.names = T, pattern = "bam$|1.fastq.gz$")
inv <- as.tibble(c(wes, rna, wgs))

df <- inv %>%
  mutate(File_Name_Actual = basename(value)) %>%
  
  # join File_Name for srrs, derive for remainder
  left_join(srr_map, by = "File_Name_Actual") %>%
  mutate(File_Name = if_else(is.na(File_Name), 
                             gsub("\\.[bwa]*.*bam$", "", File_Name_Actual),
                             File_Name) ,
         # Padd some File_Names to end a 5-digit K00000 or L00000
         File_Name        = gsub("(_[KkL]{1})(\\d{4})$", "\\10\\2", File_Name),
         File_Path        = gsub("s3://celgene.rnd.combio.mmgp.external/", "", value) ) %>%
  
  separate(File_Name, into = c("Study", "pat", "seq", "Tissue_Type", "Cell_Type", "typecode", "group", "lane"), remove = F) %>%
  mutate(Cell_Type = if_else(Cell_Type %in% c("WBC", "Whole"), "PBMC", Cell_Type),
         Sample_Type_Flag = as.integer(Cell_Type == "CD138pos"),
         Sample_Type      =  recode(Sample_Type_Flag, `0`="Normal", `1`="NotNormal") ) %>%

  group_by(pat) %>%
  mutate(Disease_type = paste0(Cell_Type, Tissue_Type),
         Disease_type = if_else( any(Disease_type == "CD138posPB"), "PCL", "MM")) %>%
  left_join(ia_map, by = "File_Name") %>%
  ungroup() %>%
  select(-value, -pat, -seq, -typecode, -lane, -group)

