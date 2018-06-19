library(toolboxR)
library(tidyverse)
library(s3r)
s3r::s3_set(bucket = "celgene-src-bucket",profile = 'redda-analytics',sse = T )


## -----------------------------------------------------
## Set4-5-6 and Set-8
## WGS and RNA-Seq
## celgene-src-bucket/DA0000206/
## celgene-src-bucket/DA0000253/
## celgene-src-bucket/DA0000254/

### set 4-5-6 RNA-Seq
set456_rna <- auto_read("~/rancho/celgene/prismm/data/set4-5-6/Celgene sets 4-6 RNA seq metrics_1.9.18.xlsx") %>%
  transmute(vendor_id       = PDO.Sample,
            celgene_id      = as.character(Collaborator.Participant.ID),
            filename        =  paste0(Collaborator.Sample.ID, ".bam"),
            is_normal       = if_else(Sample.Type == "Tumor", "No", "Yes"),
            cell_type       = if_else(Sample.Type == "Tumor", "CD138+", "PBMC"),
            
            experiment_type = "RNA-Seq",
            library_prep    = "Illumina TruSeq RNA",
            rna_selection   = "Long-insert strand-specific poly-A",
            nt_extraction   = "Qiagen AllPrep",
            stranded        = "FORWARD",
            paired_end      = "Yes"
  )

### set 4-5-6 WGS #######################
set456_wgs_n <- auto_read("~/rancho/celgene/prismm/data/set4-5-6/Celgene Sets 4-6 WGS Normals_Seq Metrics_12.6.17.xlsx") %>%
  transmute(vendor_id    = PDO.Sample,
            celgene_id      = as.character(Collaborator.Participant.ID),
            filename        =  paste0(Collaborator.Sample.ID, ".cram"),
            is_normal       = "Yes",
            cell_type       = "PBMC")

set456_wgs_t <- auto_read("~/rancho/celgene/prismm/data/set4-5-6/Celgene SF Sets 456 WGS Tumors_Seq Metrics Delivery_2.21.18.xlsx") %>%
  transmute(vendor_id    = PDO.Sample,
            celgene_id      = as.character(Collaborator.Participant.ID),
            filename        =  paste0(Collaborator.Sample.ID, ".cram"),
            is_normal       = "No",
            cell_type       = "CD138+")

set456_wgs  <- bind_rows(set456_wgs_n, set456_wgs_t) %>%
  mutate(experiment_type = "WGS",
         library_prep    = "Broad Solution Hybrid Selection capture",
         nt_extraction   = "Qiagen AllPrep",
         stranded        = "NONE",
         paired_end      = "Yes")

### set 8 WGS #######################
set8_wgsT <- auto_read("~/rancho/celgene/prismm/data/set8/Celgene Set 8_WGS TUMORS_seq metrics delivery_1.12.18.xlsx")%>%
  transmute(vendor_id    = PDO.Sample,
            celgene_id      = as.character(Collaborator.Participant.ID),
            experiment_type = "WGS",
            filename        =  paste0(Collaborator.Sample.ID, ".cram"),
            is_normal       = "No",
            cell_type       = "CD138+",
            experiment      = "CC-4047-MM-014-B",
            tissue          = "Bone Marrow")

set8_wgsN <- auto_read("~/rancho/celgene/prismm/data/set8/Celgene Set 8 WGS NORMALS_Seq metrics delivery_1.12.18.xlsx") %>%
  transmute(vendor_id  = PDO.Sample,
            celgene_id      = as.character(Collaborator.Participant.ID),
            experiment_type = "WGS",
            filename   =  paste0(Collaborator.Sample.ID, ".cram"),
            is_normal       = "Yes",
            cell_type       = "PBMC",
            experiment      = "CC-4047-MM-014-B",
            tissue          = "PBMC")

set8_wgs  <- bind_rows(set8_wgsT, set8_wgsN) %>%
  mutate(experiment_type = "WGS",
         library_prep    = "Broad Solution Hybrid Selection capture",
         nt_extraction   = "Qiagen AllPrep",
         stranded        = "NONE",
         paired_end      = "Yes")

## mapping tissue type by lookup table
rna_tissue_map <- auto_read("~/rancho/celgene/prismm/data/SampleList Celgene SF RNA QC_sets 456 for RNAseq final list 10_23_2017.xls") %>%
  transmute(vendor_id = Sample.ID,
            tissue    = Tissue.Site)

dna_tissue_map <- auto_read("~/rancho/celgene/prismm/data/SampleList Celgene SF DNA QC_sets 456_EF.xls") %>%
  transmute(vendor_id = Sample.ID,
            tissue    = Tissue.Site)

tissue_map <- bind_rows(rna_tissue_map, dna_tissue_map)

## splitting set4-5-6 into individual experiments 
study_map <- auto_read("~/rancho/celgene/prismm/data/study_mapping.txt") %>%
  transmute(celgene_id = as.character(collaborator_participant_id),
            experiment    = study) %>%
  unique() %>%
  filter( !is.na(celgene_id))

### join everything together
location_map <- auto_read("~/rancho/celgene/prismm/data/set4-5-6/s3_map.txt")

df     <- bind_rows(set456_rna, set456_wgs)%>%
  left_join(study_map, by = "celgene_id") %>%
  left_join(tissue_map, by = "vendor_id") %>%
  bind_rows(set8_wgs) %>%
  
  left_join(location_map, by = c("experiment_type", "experiment")) %>%
  mutate( vendor        = "Broad Institute",
          vendor_project_name = "PRISMM",
          celgene_project_desc = paste0("Hematology,PRISMM,",experiment),
          reference_genome ="Homo sapiens",
          condition = "MM" )

### add any missing columns and sort their order
all_columns <- scan("~/rancho/celgene/data.registration.column.names.txt", as.character())
new_columns <- all_columns[!(all_columns %in% names(df))]
df[,new_columns] <- NA
df <- df[,all_columns] %>%
  arrange(celgene_project_desc, experiment_type, celgene_id)

### QC


# filter to remove any patients that have unpaired WGS tumor/normal samples
df %>%
  filter(experiment_type == "WGS") %>%
  group_by(celgene_id) %>%
  mutate(paired = all(c("Yes", "No") %in% is_normal)) %>%
  filter(!paired) %>%
  select(celgene_id, vendor_id, DA_project_id, experiment_type, experiment, cell_type, is_normal)

# Groups:   celgene_id [4]
#   celgene_id vendor_id DA_project_id       experiment cell_type is_normal
#        <chr>     <chr>         <chr>            <chr>     <chr>     <chr>
# 1      31001  SM-GE5XZ     DA0000253   CC-4047-MM-008    CD138+        No
# 2      31002  SM-G942H     DA0000253   CC-4047-MM-008    CD138+        No
# 3    1131018  SM-GLQ5K     DA0000206 CC-4047-MM-014-B      PBMC       Yes
# 4    1151004  SM-GLQ5J     DA0000206 CC-4047-MM-014-B      PBMC       Yes

# count samples per study
df %>%  
  filter(celgene_id != "CelgeneRNAcontrol") %>%
  group_by(experiment, DA_project_id, experiment_type, cell_type) %>%
  summarise(n = length(unique(celgene_id)))

# all filenames and vendor_id values are unique
df[duplicated(df$vendor_id),]
df[duplicated(df$filename),]
# just RNA control samples are dups, those are OK


### export individual sample manifests for each subset, e.g. DA0000206 RNA-Seq 
sets <- df %>%
  select(experiment_type, DA_project_id) %>% unique()

manifest_o <- function(set, da){
  df %>% 
    filter(experiment_type == set) %>%
    filter(DA_project_id   == da) 
}

null <- apply(sets, 1, function(foo){
  da  <- foo[['DA_project_id']]
  set <- foo[['experiment_type']]
  f   <- manifest_o(set, da) 
  auto_write(f, file.path("~/rancho/celgene/prismm/data/set4-5-6", paste0(da, "_", set, "_sample_manifest.tsv")))
  })


#### check out which files are redundant

# get some lists of actual files on s3
s3_206_wgs <- s3_ls("DA0000206/WGS/Processed", pattern = "cram$")
s3_253_wgs <- s3_ls("DA0000253/WGS/Processed", pattern = "cram$")
s3_254_wgs <- s3_ls("DA0000254/WGS/Processed", pattern = "cram$")
s3_206_rna <- s3_ls("DA0000206/RNA-Seq/Processed", pattern = "bam$")
s3_253_rna <- s3_ls("DA0000253/RNA-Seq/Processed", pattern = "bam$")
s3_254_rna <- s3_ls("DA0000254/RNA-Seq/Processed", pattern = "bam$")

s3_set456_wgs_t <- s3_ls("s3://redda-datatransfer/CRO_DA0000288_Broad_Institute_V2/set04_05_06_mm014_mm008_mm013_wgs60", pattern = "cram$")


filename <- unique(c(s3_206_wgs,s3_253_wgs,s3_254_wgs,s3_206_rna,s3_253_rna,s3_254_rna))

all_files <- as.data.frame(filename, stringsAsFactors = F) %>%
  full_join(df, by = "filename")

out <- all_files %>%
  mutate(
    `s3_DA0000206_WGS` = (filename %in% s3_206_wgs),
    `s3_DA0000253_WGS` = (filename %in% s3_253_wgs),
    `s3_DA0000254_WGS` = (filename %in% s3_254_wgs),
    `s3_DA0000206_RNA-Seq` = (filename %in% s3_206_rna),
    `s3_DA0000253_RNA-Seq` = (filename %in% s3_253_rna),
    `s3_DA0000254_RNA-Seq` = (filename %in% s3_254_rna) )


actions <- out %>% 
  select(filename, DA_project_id, experiment_type, s3_DA0000206_WGS:`s3_DA0000254_RNA-Seq`) %>%
  gather(location, status ,-filename, -DA_project_id, -experiment_type) %>%
  mutate(
    desired_path = file.path("celgene-src-bucket",DA_project_id, experiment_type, "Processed", filename ),
    current_path = gsub("^([^_]+)_([^_]+)_([^_]+)$", "\\2\\/\\3", location),
    current_path = file.path("celgene-src-bucket",current_path, "Processed", filename ),
    remove       = current_path != desired_path
    ) %>% select(-location)

auto_write(actions, "~/rancho/celgene/prismm/data/set4-5-6/manifest_with_duplicated_s3_locations.txt")


# confirm that all files are in their proper place
actions %>%
  group_by(filename) %>%
  summarise(good= any(remove == FALSE)) %>%
  ungroup() %>%
  summarise( all_good = all(good))


# and just a simple list of what should go where
locations <- df %>% select(filename, DA_project_id, experiment_type)
auto_write(locations, "~/rancho/celgene/prismm/data/set4-5-6/filenames_with_destination_location.txt")
