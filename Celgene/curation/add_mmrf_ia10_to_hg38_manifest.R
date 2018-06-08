library(toolboxR)
library(tidyverse)

# we don't want IA11 for MGP/PRISMM so capture this to exclude
wes_ia11 <-auto_read("~/rancho/celgene/prismm/data/MGP/ia11.txt")%>%
  mutate(sample_name = sample_from_file(basename(filename)))

# start with the MGP jointdata/metadata table by filtering for MMRF/WES
df <- auto_read("~/rancho/celgene/prismm/data/MGP/mmrf_wes.xlsx")  %>%
  mutate(sample_name = sample_from_file(vendor_id)) %>%
  filter(!sample_name %in% wes_ia11$sample_name ) %>%
  select(filename, sample_name, vendor_project_name) %>%
  mutate(filename    = basename(filename)) %>%
  arrange(sample_name) %>%

  # trim off batch barcodes and file extension
  mutate(vendor_id = gsub("(.*)_[TC][0-9]{1,2}_.*", "\\1", filename)) %>%
  separate(vendor_id, into = c("DA_project_id", "celgene_id", "sample_no", "tissue", "cell_type"), remove = F) %>%
  mutate(vendor                        = "TGen",
         experiment                    = paste("MMGP", vendor_project_name, sep = "_"),
         celgene_project_desc          = "MM Genomic profile",
         display_name                  = vendor_id,
         display_name_short            = gsub("(MMRF_[0-9]+_[0-9]+)_.*$", "\\1", sample_name),
         cell_line                     = NA,
         tissue                        = recode(tissue, PB = "peripheral blood", BM = "bone marrow"),
         condition                   = NA,
         condition1	=NA,
         quality_metric=NA,
         quality_metric1=NA,
         xenograft                   = "no",
         # table(paste(df$cell_type,df$tissue, sep = "-"))
         # BM-CD138pos PB-CD138pos   PB-CD3pos      PB-WBC    PB-Whole
         #         999          17          65         209         638
         # tumor       tumor         normal         normal    normal
         is_normal                   = case_when(
           cell_type == "CD138pos"  ~ "No",
           TRUE ~ "Yes"),
         time_treatment              = NA,
         response_desc               = NA,
         response_desc1              = NA,
         response                    = NA,
         response1                   = NA,
         compound                    = NA,
         compound1                   = NA,
         dose                        = NA,
         dose1                       = NA,
         biological_replicates_group = NA,
         technical_replicates_group  = NA,
         experiment_type             = "DNA-Seq exome sequencing (WES)",
         technology                  = "Illumina HiSeq 2000",
         library_prep                = "KAPA HyperPrep",
         exome_bait_set              = "SureSelect_Human_All_exon_v5+UTRs_75Mb_Agilent ",
         rna_selection               = NA,
         nt_extraction                    = NA,
         antibody_target             = NA,
         reference_genome            = "Homo sapiens",
         host_genome                 = NA,
         stranded                    = "None",
         paired_end                  = "Yes"          ) %>%
  select(vendor, vendor_id, vendor_project_name, celgene_id, DA_project_id, celgene_project_desc,
         experiment, display_name, display_name_short, cell_type, cell_line, tissue, condition,
         condition1, quality_metric, quality_metric1, xenograft, is_normal, time_treatment,
         response_desc, response_desc1, response, response1, compound, compound1, dose, dose1,
         biological_replicates_group, technical_replicates_group, experiment_type, technology,
         library_prep, exome_bait_set, rna_selection, nt_extraction, antibody_target,
         reference_genome, host_genome, stranded, paired_end, filename) %>%
  # only keep paired T/N samples for WES processing
  group_by(celgene_id) %>%
  filter( all(c("Yes", "No") %in% is_normal) )

auto_write(df, "~/rancho/celgene/prismm/data/MGP/WES.MMRF.Dan.20180514.txt")

# table(paste(df$cell_type,df$tissue, sep = "-"))
# BM-CD138pos PB-CD138pos   PB-CD3pos      PB-WBC    PB-Whole
#         999          17          65         209         638
# tumor       tumor         normal         normal    normal

# look at what sampling scheme PCL patients used.
# pcl <- tmp %>%
#   group_by(celgene_id) %>%
#   mutate( sample_type= gsub(".*_([BP].*)", "\\1", display_name)) %>%
#   filter( any( sample_type == "PB_CD138pos")) %>%
#   select(celgene_id, sample_no, sample_type) %>%
#   group_by(celgene_id, sample_no) %>%
#   summarize(sample_types = Simplify(sample_type)) %>%
#   ungroup() %>%
#   spread(sample_no, sample_types)
# auto_write(pcl, "~/rancho/celgene/prismm/data/MGP/pcl_sample_scheme.txt")