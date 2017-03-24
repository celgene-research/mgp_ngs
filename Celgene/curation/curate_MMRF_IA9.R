## drozelle@ranchobiosciences.com
## MMRF file curation

# This script was first updated for use on IA10, but then after several changes
# were made during this process I thought it'd be usefult to have an identically
# formatted IA9 version, so I went back through and revised backwards to use
# IA9 sources and export to IA9 S3 buckets.

source("curation_scripts.R")

study    <- "MMRF"
d        <- format(Sys.Date(), "%Y-%m-%d")
s3       <- "s3://celgene.rnd.combio.mmgp.external"
ia10.in  <- "ClinicalData/OriginalData/MMRF_IA10c"
ia10.out <- "ClinicalData/ProcessedData/MMRF_IA10c"

ia9.in  <- "ClinicalData/OriginalData/MMRF_IA9"
ia9.out <- "ClinicalData/ProcessedData/MMRF_IA9"

local    <- CleanLocalScratch()



### code to write raw a inventory is only run periodically
### NOTE: this is not filtered/deduplicated in any way
# wes <- system('aws s3 ls s3://celgene.rnd.combio.mmgp.external/SeqData/WES/OriginalData/MMRF/ --recursive | grep bam$', intern = T)
# rna <- system('aws s3 ls s3://celgene.rnd.combio.mmgp.external/SeqData/RNA-Seq/OriginalData/MMRF/ --recursive | grep bam$', intern = T)
# wgs <- system('aws s3 ls s3://celgene.rnd.combio.mmgp.external/SeqData/WGS/OriginalData/MMRF/ --recursive | grep -e bam$ -e gz$', intern = T)
# inv <- c(wes, rna, wgs)
# inv <- gsub(".*SeqData", "SeqData", inv)
# inv <- data.frame(File_Path = inv, stringsAsFactors = FALSE)
# PutS3Table(inv, file.path(s3, ia10.in, "mmrf.file.inventory.txt"))

### file_inventory -------------------------

# generate 
name        <- "mmrf.file.inventory.txt"
inv         <- GetS3Table(file.path(s3, ia10.in, name)) 

# NOTE: for some reason the vendor_id values supplied here are not properly zero-padded
# as in the Seqqc table. Edit all File_Names to end a 5-digit K00000 or L00000.
#   from:
#     MMRF_1327_1_PB_Whole_C1_TSWGL_K3755
#   to:
#     MMRF_1327_1_PB_Whole_C1_TSWGL_K03755
srr.mapping <- GetS3Table(file.path(s3, ia10.in, "data.import.WGS.Kostas.IA3-IA7.txt")) %>%
  mutate(prefix              = gsub("^(.*_[KL])(\\d+)$", "\\1" ,toupper(vendor_id)),
         padded.suffix       = as.numeric(gsub("^(.*_[KL])(\\d+)$", "\\2" ,toupper(vendor_id)))) %>%
  transmute(File_Name        = paste0(prefix, sprintf("%05d", padded.suffix)),
            File_Name_Actual = paste0(gsub("^.*(SRR.*?)_2.*$","\\1",filename), "_1.fastq.gz"))


# Correct Sample_Name to include Cell_Type designation
inv <- inv %>%
  mutate(File_Name_Actual = basename(inv$File_Path)) %>%
  # remove duplicate SRR read files
  filter( !grepl("_2.fastq.gz", File_Name_Actual, fixed = T)) %>%
  full_join(srr.mapping, by = "File_Name_Actual") %>%
  mutate_cond(is.na(File_Name), 
              File_Name = gsub("^(MMRF.*?)\\..*", "\\1",  File_Name_Actual))
###
### remove new IA10 files
inv <- filter(inv, !grepl("IA10", File_Path))
###
# fix case issues
inv$File_Name            <- gsub("POS", "pos", inv$File_Name)
inv$File_Name            <- gsub("WHOLE",    "Whole",    inv$File_Name)

inv[['Study']]           <- study

# mutate_cond(measure == 'exit', qty.exit = qty, cf = 0, delta.watts = 13)
inv[['Study_Phase']] <- NA
inv[grepl("^MMRF", inv$File_Name_Actual),"Study_Phase"] <- gsub(".*MMRF\\/([IA0-9]+)\\/MMRF.*", "\\1", inv[grepl("^MMRF", inv$File_Name_Actual),]$File_Path)
inv[['Patient']]         <- gsub("^(MMRF_\\d+)_\\d+_.*", "\\1",  inv$File_Name)
inv[['Sample_Sequence']] <- gsub("^(MMRF.*)_[BMP]+_.*", "\\1", inv$File_Name)
inv[['Sample_Name']]     <- gsub("^(MMRF.*[BMP]+)_.*", "\\1",  inv$File_Name)

inv[['Sample_Type']]     <- ifelse(grepl("CD138",inv$File_Name), "NotNormal", "Normal")
inv[['Sample_Type_Flag']]<- ifelse(grepl("CD138",inv$File_Name), "1", "0")
inv[['Tissue_Type']]     <- ifelse(grepl("BM",inv$File_Name), "BM", "PB")

# Harmonize Cell_Type to CD138; CD3; PBMC types 
inv[['Cell_Type']]       <- gsub(".{12}[PBM]+_([A-Za-z0-9]+)_[CT]\\d.*","\\1",inv$File_Name)
inv$Cell_Type            <- gsub("WBC|Whole", "PBMC", inv$Cell_Type)

curated.inv <- inv
name <- paste("curated", name, sep = "_")
PutS3Table(inv, file.path(s3, ia9.out, name))

### IA10_Seq_QC_Summary -------------------------
# apply higher level sample  variables using IA9 Seq QC table
name <- "MMRF_CoMMpass_IA9_Seq_QC_Summary.xlsx"
df   <- GetS3Table(file.path(s3, ia9.in, name)) %>%
  transmute(Study = study,
            File_Name = `QC Link SampleName`,
            Sample_Name      = gsub("^(MMRF.*[BMP]+)_.*", "\\1", File_Name),
            Patient          = `Patients::KBase_Patient_ID`,
            Visit_Name       = `Visits::Reason_For_Collection`,
            Disease_Status   = recode(Visit_Name, 
                                      "Baseline"            = "ND", 
                                      "Confirm Progression" = "R", 
                                      "Confirm Response"    = "R",
                                      "Restaging"           = "R",
                                      "Pre Transplant"      = "R",
                                      "Post Transplant"     = "R",
                                      "Other"               = "NA",
                                      "Unknown"             = "NA" ),
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

if( all(df$Disease_Status %in% c("ND", "R")) )warning("Check Disease_Status mapping, some not matched") 
if( all(df$Sequencing_Type %in% c("WES", "WGS", "RNA-Seq")) )warning("Check Sequencing_Type mapping, some not matched") 

# remove exclude_specify for retained samples and sequencing type from excluded
df[df$Excluded_Flag == 0,"Excluded_Specify"] <- NA

curated.seqqc <- df
name <- paste("curated", name, sep = "_")
name <- gsub("xlsx", "txt", name)
PutS3Table(df, file.path(s3, ia9.out, name))

### PER_PATIENT_VISIT -------------------------
# curate per_visit entries with samples taken for the sample-level table
name      <- "PER_PATIENT_VISIT.csv"
curated.per.visit <- GetS3Table(file.path(s3, ia9.in, name)) %>%
  filter(SPECTRUM_SEQ != "") %>%
  local_collapse_dt("SPECTRUM_SEQ") %>%
  
  group_by(PUBLIC_ID) %>%
  mutate( bmt = if_else( suppressWarnings(VISITDY > min(BMT_DAYOFTRANSPL, na.rm = T)), 1,0,0)) %>%
  ungroup() %>%
  
  transmute(
    Study                   = study,
    Patient                 = PUBLIC_ID,
    Sample_Sequence         = SPECTRUM_SEQ,
    Visit_Name              = VJ_INTERVAL,
    Disease_Status          = ifelse(grepl("Baseline",  VJ_INTERVAL, ignore.case = T),"ND", "R"),
    Disease_Status_Notes    = CMMC_VISIT_NAME,
    Sample_Study_Day        = BA_DAYOFASSESSM,
    
    D_PrevBoneMarrowTransplant                  = bmt,
    
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
    IG_IgE                  = D_LAB_serum_ige
  ) %>% arrange(Sample_Sequence)

z_score <- function(x){
  pop.mean <- mean(x, na.rm = T)
  pop.sd   <- sd(x, na.rm = T)
  (x - pop.mean) / pop.sd }

# check blood values for extreme outliers
tmp <- curated.per.visit %>%
  select(Sample_Sequence, CBC_Absolute_Neutrophil:IG_IgE) %>%
  mutate_at(vars(CBC_Absolute_Neutrophil:IG_IgE), as.numeric) %>%
  gather(key, value, -Sample_Sequence) %>%
  group_by(key) %>%
  mutate(z = z_score(value)) %>%
  ungroup()

# ggplot(tmp, aes(z)) + geom_freqpoly(binwidth = 2 ) + scale_y_log10() 
# 10 looks like a pretty conservative z-score cutoff, this removes 17 values
tmp %>% filter(abs(z)>10)

# go ahead and NA those values and reshape back to original table
tmp <- tmp %>% 
  mutate(value = ifelse(abs(z)>10,NA,value) ) %>%
  select(-z) %>%
  spread(key, value)

curated.per.visit <- toolboxR::append_df(curated.per.visit, tmp, id = "Sample_Sequence",  mode = "replace")

# We want to bind this visit data to a File_Name so that it can be incorporated
# into the integrated per-file table
# Make a mapping table from inv from BM sample type if present, else PB 
curated.seqqc <- curated.seqqc %>% 
  mutate(Tissue_Type = gsub(".*_([BMP]{2})_.*", "\\1", File_Name)) %>% 
  select(Sample_Sequence, File_Name, Tissue_Type, Sequencing_Type)

curated.per.visit <- curated.inv %>%
  mutate(Sequencing_Type = gsub("SeqData\\/(.*)\\/OriginalData.*","\\1", File_Path)) %>%
  select(Sample_Sequence, File_Name, Tissue_Type, Sequencing_Type) %>%
  rbind(curated.seqqc) %>%
  unique() %>%
  mutate(seq_order = recode( Sequencing_Type, WES="a", WGS="b", "srr-wgs"="b", "RNA-Seq"="c"  )) %>%
  group_by(Sample_Sequence) %>%
  arrange(Sample_Sequence, Tissue_Type, seq_order) %>%
  slice(1) %>%
  select(Sample_Sequence, File_Name) %>%
  right_join(curated.per.visit, by = "Sample_Sequence") 

name <- paste("curated", study,name, sep = "_")
name <- gsub("csv", "txt", name)
PutS3Table(curated.per.visit, file.path(s3, ia9.out, name))

### PER_PATIENT -------------------------
# curate PER_PATIENT entries, requires some standalone tables for calculations
name      <- "PER_PATIENT.csv"
per.patient <- GetS3Table(file.path(s3, ia9.in, name))
survival    <- GetS3Table(file.path(s3, ia9.in, "STAND_ALONE_SURVIVAL.csv"))
respo       <- GetS3Table(file.path(s3, ia9.in, "STAND_ALONE_TRTRESP.csv"))

df <- per.patient %>%
  transmute(Patient  = PUBLIC_ID,
            Study    = study,
            D_Gender = DEMOG_GENDER,
            D_Race = recode(D_PT_race, "WHITE", "BLACKORAFRICAN", "AMERICANINDIAN", "ASIAN", "", "OTHER"),
            D_Age    = D_PT_age,
            D_ISS    = D_PT_iss  ) 

lookup_by_publicid <- lookup.values("public_id")
df[['D_OS']]       <- unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "ttcos"))
df[['D_OS_FLAG']]  <- unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "censos"))
df[['D_PFS']]      <- unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "ttcpfs"))
df[['D_PFS_FLAG']] <- unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "censpfs"))
df[['D_PD']]       <- unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "ttfpd"))
df[['D_PD_FLAG']]  <- unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "pdflag"))

df[["D_Cause_of_Death"]]             <-  per.patient$D_PT_CAUSEOFDEATH
df[["D_Reason_for_Discontinuation"]] <-  per.patient$D_PT_PRIMARYREASON
df[["D_Discontinued"]]               <-  per.patient$D_PT_discont
df[["D_Complete"]]                   <-  recode(per.patient$D_PT_complete, "2" = 0)

# filter response table using line =1 (first line treatment only), trtbresp=1 (Treatment best response) then find that response
best_response_table <- respo[respo$trtbresp == 1 & respo$line == 1 ,]
df[["D_Best_Response_Code"]] <-  unlist(lapply(df$Patient, lookup_by_publicid, dat = best_response_table, field = "bestrespcd"))
df[["D_Best_Response"]]      <-  unlist(lapply(df$Patient, lookup_by_publicid, dat = best_response_table, field = "bestresp"))

name <- paste("curated", study,name, sep = "_")
name <- gsub("csv", "txt", name)
PutS3Table(df, file.path(s3, ia9.out, name))
