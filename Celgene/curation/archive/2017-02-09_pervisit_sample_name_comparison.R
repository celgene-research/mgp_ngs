# do any pervisit spectrum seq numbers NOT have a corresponding BM CD138 sample

# we need to determine what sample_tissue name applies to each per.visit row which is
#  only identfied by a "spectrum_seq" short sample_name

library(dplyr)
library(tidyr)
curated.pervisit.1 <- curated.pervisit %>% transmute(Sample_Name   = Sample_Name,
                                                     pv.Patient    = Patient,
                                                     pv.Visit_Name = Visit_Name,
                                                     pv.Disease_Status_Notes = Disease_Status_Notes,
                                                     pv.CYTO_Has_Conventional_Cytogenetics = CYTO_Has_Conventional_Cytogenetics,
                                                     `pv.CYTO_t(4;14)_FISH` = `CYTO_t(4;14)_FISH`,
                                                     pv.CBC_WBC = CBC_WBC)

curated.inv.1   <- curated.inv %>% transmute(Sample_Name = gsub("_[BMP]+", "", Sample_Name),
                                             inv.Tissue_Type = Tissue_Type,
                                             inv.Cell_Type = Cell_Type,
                                             inv.File_Name = File_Name
                                             ) 


curated.seqqc.1   <- curated.seqqc %>% transmute(Sample_Name = `Visits::Study Visit ID`, 
                                              seqqc.File_Name = `QC Link SampleName`, 
                                              seqqc.Visit = `Visits::Reason_For_Collection`,
                                              seqqc.Seq_Type = Sequencing_Type ) 


by.sample.name <- merge(curated.pervisit.1, curated.inv.1, by = "Sample_Name", all.x = TRUE )
by.sample.name <- merge(by.sample.name, curated.seqqc.1, by = "Sample_Name", all.x = TRUE )

df <- toolboxR::CollapseDF(by.sample.name, column.names = "Sample_Name")
df[df == "NA"] <- NA

tmp1 <- df %>% filter( !grepl("BM", inv.Cell_Type ) & !is.na(inv.Cell_Type))
tmp2 <- df %>% filter( !grepl("BM", seqqc.File_Name ) & !is.na(seqqc.File_Name))

# Cases
# Split concatenated File_Name field into multiple rows, add additional columns to make selection easier
df2 <- df %>%
  mutate(seqqc.File_Name = strsplit(seqqc.File_Name, "; ")) %>%
  unnest(seqqc.File_Name) %>%
  mutate(cell.from.seqqc.file = gsub(".*_([BMP]+)_.*","\\1",seqqc.File_Name),
         visit.cell           = paste(pv.Visit_Name,cell.from.seqqc.file, sep ="-"),
         sequence             = gsub(".*_([0-9]+)$","\\1", Sample_Name)        )



patient.groups  <-  group_by(df2, pv.Patient) 
sample.groups   <-  group_by(df2, Sample_Name) 


# Commonly the same sample sequence number is given to paired BM and PB samples taken during the same visit
# for example the sequence number "_1" is applied to both BM_CD138 and PB_WBC samples. 

# List files from Sample_Names with multiple cell types? 778 patients have non-unique sample names applied to BM and PB samples
filter(sample.groups, length(unique(cell.from.seqqc.file)[!is.na(unique(cell.from.seqqc.file))]) > 1) %>% 
  select(Sample_Name, pv.Visit_Name, seqqc.File_Name, pv.Patient) %>%
  group_by(pv.Patient)


# Oppositely, 28 patients have distinguishing sample names between paired BM and PB samples 
# taken during the same visit. It is unclear whether cytogenetics were performed on both, 
# or the same results were just reported for both?
group_by(df, pv.Patient, pv.Visit_Name) %>%
  filter( length(unique(Sample_Name)) >1 ) %>%
  select(Sample_Name, pv.Visit_Name, seqqc.File_Name) %>%
  group_by(pv.Patient)

# Aside: why are some PB samples selected for CD3?

# While the IA9 Seqqc table has data for 971 patients
patient.groups

# we only have sequencing data for 825 patients
filter(patient.groups, any(!is.na(seqqc.File_Name))  )

# leaving 146 patients that don't have any files e.g. MMRF_1007, MMRF_1011
filter(patient.groups, all(is.na(seqqc.File_Name))  )

# of these 825 patients, 812 have a Baseline-BM sample,
filter(patient.groups, ("Baseline-BM" %in% visit.cell))

# Instead, these 13 have only Relapse samples. e.g. MMRF_1020 only has _3 Relapse/Progression samples
filter(patient.groups, !("Baseline-BM" %in% visit.cell), any(!is.na(seqqc.File_Name)))

# no patients have a Baseline-PB sample without a Baseline-BM sample (this is good)
filter(patient.groups, ("Baseline-PM" %in% visit.cell), !("Baseline-BM" %in% visit.cell) )

