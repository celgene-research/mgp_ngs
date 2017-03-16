## drozelle@ranchobiosciences.com
## MMRF file curation

#
# 2017-03-14 update to release IA10
# 

source("curation_scripts.R")

study    <- "MMRF"
d        <- format(Sys.Date(), "%Y-%m-%d")
s3       <- "s3://celgene.rnd.combio.mmgp.external"
ia10.in  <- "ClinicalData/OriginalData/MMRF_IA10c"
ia10.out <- "ClinicalData/ProcessedData/MMRF_IA10c"
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

# fix case issues
inv$File_Name            <- gsub("POS", "pos", inv$File_Name)
inv$File_Name            <- gsub("WHOLE",    "Whole",    inv$File_Name)

inv[['Sample_Name']]     <- gsub("^.*(MMRF.*[BMP]+)_.*", "\\1",  inv$File_Name)
inv[['Sample_Sequence']] <- gsub("^.*(MMRF.*)_[BMP]+_.*", "\\1",  inv$File_Name)

inv[['Sample_Type']]     <- ifelse(grepl("CD138",inv$File_Name), "NotNormal", "Normal")
inv[['Sample_Type_Flag']]<- ifelse(grepl("CD138",inv$File_Name), "1", "0")
inv[['Tissue_Type']]     <- ifelse(grepl("BM",inv$File_Name), "BM", "PB")

# Harmonize Cell_Type to CD138; CD3; PBMC types 
inv[['Cell_Type']]       <- gsub(".{12}[PBM]+_([A-Za-z0-9]+)_[CT]\\d.*","\\1",inv$File_Name)
inv$Cell_Type            <- gsub("WBC|Whole", "PBMC", inv$Cell_Type)

curated.inv <- inv
PutS3Table(inv, file.path(s3, ia10.out, name))

### IA10_Seq_QC_Summary -------------------------
# apply higher level sample  variables using IA9 Seq QC table
name <- "MMRF_CoMMpass_IA10_Seq_QC_Summary.xlsx"
df   <- GetS3Table(file.path(s3, ia10.in, "README_FILES", name)) %>%

  df%>%  transmute(File_Name = `QC Link SampleName`,
            Sample_Name = gsub("^(MMRF.*[BMP]+)_.*", "\\1", File_Name),
            Visit_Name       =)

df[["Visit_Name"]]      <- df$`Visits::Reason_For_Collection`
df[["Disease_Status"]]  <- recode(df$`Visits::Reason_For_Collection`, 
                                  "Baseline"            = "ND", 
                                  "Confirm Progression" = "R", 
                                  "Confirm Response"    = "R",
                                  "Other"               = "NA",
                                  "Unknown"             = "NA" )
df$Disease_Status <- gsub("NA", NA, df$Disease_Status)

df[['Sample_Sequence']] <- gsub("^(MMRF.*)_[BMP]+_.*", "\\1",  df$File_Name)
df[['Sequencing_Type']] <- gsub("(.*)-.*", "\\1", df$MMRF_Release_Status)


# remove exclude_specify for retained samples
df[['Excluded_Flag']]    <-ifelse(grepl("^Exclude|RNA-No|LI-Neither|Exome-Neither",
                                        df$MMRF_Release_Status),1,0)
df[['Excluded_Specify']]    <-df$MMRF_Release_Status

# remove exclude_specify for retained samples and sequencing type from excluded
df[df$Excluded_Flag == 0,"Excluded_Specify"] <- NA
df[df$Sequencing_Type == "Exclude", "Sequencing_Type"] <- NA
df$Sequencing_Type <- plyr::revalue(df$Sequencing_Type, c(RNA="RNA-Seq", 
                                                          LI="WGS", 
                                                          Exome="WES"))
df <- select(df, File_Name:ncol(df))

curated.seqqc <- df
name <- paste("curated", name, sep = "_")
name <- gsub("xlsx", "txt", name)
path <- file.path(local,name)
write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)

### PER_PATIENT_VISIT -------------------------
# curate per_visit entries with samples taken for the sample-level table
name <- "PER_PATIENT_VISIT.csv"
pervisit <- read.csv(file.path(local,name), stringsAsFactors = F, 
                     na.strings = c("Not Done", "")) %>%
  filter(SPECTRUM_SEQ != "") %>%
  arrange(SPECTRUM_SEQ)

pervisit <- local_collapse_dt(pervisit, "SPECTRUM_SEQ")

df <- data.frame(Patient = pervisit$PUBLIC_ID,
                 stringsAsFactors = F)

df[["Study"]]                  <- study
df[["Sample_Sequence"]]        <- pervisit$SPECTRUM_SEQ
df[["Visit_Name"]]             <- pervisit$VJ_INTERVAL
df[["Disease_Status"]]         <- ifelse(grepl("Baseline", pervisit$VJ_INTERVAL, ignore.case = T),"ND", "R")
df[["Disease_Status_Notes"]]   <- pervisit$CMMC_VISIT_NAME
df[["Sample_Study_Day"]]       <- pervisit$BA_DAYOFASSESSM

# # QC to verify ND derived from Baseline and R from all others (month/year)
# df <- mutate(df, grp = paste( gsub(".*([0-9]{1})$", "\\1", Short_Sample_Name),
#                         Visit_Name,
#                         Disease_Status,
#                         sep = "-"))
# table((df$grp))

# add a pervisit flag for previous bone marrow transplants
pervisit[['BMT_PrevBoneMarrowTransplant']] <- unlist(apply(pervisit, MARGIN = 1, function(x){
  # find patient transplant date
  day <- pervisit[pervisit$PUBLIC_ID == x[['PUBLIC_ID']],"BMT_DAYOFTRANSPL"]
  
  # if they have a valid day, capture the first one
  if(any(!is.na(as.numeric(day)))){
    t <- min(day, na.rm = T )
  }else{
    t <- NA
  }
  # mark samples taken after the transplant study day as =1
  ifelse(!is.na(t) & (as.numeric(x[['VISITDY']]) >= t), 1, 0)
}))
df[['D_PrevBoneMarrowTransplant']] <- pervisit$BMT_PrevBoneMarrowTransplant

# cytogenetic fields
df[["CYTO_Has_Conventional_Cytogenetics"]]           <- ifelse(pervisit$D_CM_cm == 1, 1,0)
df[["CYTO_Has_Conventional_Metaphase_Cytogenetics"]] <- ifelse(pervisit$D_CM_WASCONVENTION == 1, 1,0)
df[["CYTO_Has_Cytogenetics_FISH_Performed"]]         <- ifelse(pervisit$D_TRI_CF_WASCYTOGENICS == 1, 1,0)
df[["CYTO_Has_cIg_staining_with_FISH"]]              <- ifelse(pervisit$D_TRI_CF_WASCLGFISHORP == 1, 1,0)

df[["CYTO_Has_FISH"]]          <- ifelse(pervisit$D_TRI_cf == 1, 1,0)
df[['CYTO_1qplus_FISH']]    <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR13 =="Yes" ,1,0)
df[['CYTO_del(1p)_FISH']]    <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR12 =="Yes" ,1,0)
df[['CYTO_t(4;14)_FISH']]    <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR3 == "Yes" ,1,0)
df[['CYTO_t(6;14)_FISH']]    <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR4 == "Yes" ,1,0)
df[['CYTO_t(11;14)_FISH']]   <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR6 == "Yes" ,1,0)
df[['CYTO_t(12;14)_FISH']]   <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR7 == "Yes" ,1,0)
df[['CYTO_t(14;16)_FISH']]   <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR8 == "Yes" ,1,0)
df[['CYTO_t(14;20)_FISH']]   <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR9 == "Yes" ,1,0)
df[['CYTO_amp(1q)_FISH']]    <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR13 == "Yes" ,1,0)
df[['CYTO_del(13q)_FISH']]   <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR == "Yes" ,1,0)
d17  <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR2 == "Yes" ,TRUE,FALSE)
d17p <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR11 == "Yes" ,TRUE,FALSE)
df[['CYTO_del(17;17p)_FISH']]    <-   ifelse(d17 | d17p, 1,0)
df[['CYTO_Hyperdiploid_FISH']]  <- ifelse( pervisit$Hyperdiploid == "Yes" ,1,0)
df[['CYTO_MYC_FISH']]    <- ifelse( pervisit$D_TRI_CF_ABNORMALITYPR5 == "Yes" ,1,0)

# blood chemistry fields
df[['CBC_Absolute_Neutrophil']] <- pervisit$D_LAB_cbc_abs_neut
df[['CBC_Platelet']]            <- pervisit$D_LAB_cbc_platelet
df[['CBC_WBC']]                 <- pervisit$D_LAB_cbc_wbc
df[['DIAG_Hemoglobin']]         <- pervisit$D_LAB_cbc_hemoglobin
df[['DIAG_Albumin']]            <- pervisit$D_LAB_chem_albumin
df[['DIAG_Calcium']]            <- pervisit$D_LAB_chem_calcium
df[['DIAG_Creatinine']]         <- pervisit$D_LAB_chem_creatinine
df[['DIAG_LDH']]                <- pervisit$D_LAB_chem_ldh
df[['DIAG_Beta2Microglobulin']] <- pervisit$D_LAB_serum_beta2_microglobulin
df[['CHEM_BUN']]                <- pervisit$D_LAB_chem_bun
df[['CHEM_Glucose']]            <- pervisit$D_LAB_chem_glucose
df[['CHEM_Total_Protein']]      <- pervisit$D_LAB_chem_totprot
df[['CHEM_CRP']]                <- pervisit$D_LAB_serum_c_reactive_protein
df[['IG_IgL_Kappa']]            <- pervisit$D_LAB_serum_kappa
df[['IG_M_Protein']]            <- pervisit$D_LAB_serum_m_protein
df[['IG_IgA']]                  <- pervisit$D_LAB_serum_iga
df[['IG_IgG']]                  <- pervisit$D_LAB_serum_igg
df[['IG_IgL_Lambda']]           <- pervisit$D_LAB_serum_lambda
df[['IG_IgM']]                  <- pervisit$D_LAB_serum_igm
df[['IG_IgE']]                  <- pervisit$D_LAB_serum_ige

curated.pervisit <- df

z_score <- function(x){
  pop.mean <- mean(x, na.rm = T)
  pop.sd   <- sd(x, na.rm = T)
  (x - pop.mean) / pop.sd }

# check blood values for extreme outliers
tmp <- curated.pervisit %>%
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

df <- toolboxR::append_df(df, tmp, id = "Sample_Sequence",  mode = "replace")

# We want to bind this visit data to a File_Name so that it can be incorporated
# into the integrated per-file table
# Make a mapping table from inv from BM sample type if present, else PB 
file.table <- unique(rbind(inv[,c("Sample_Sequence", "File_Name", "Sequencing_Type")],
                           curated.seqqc[curated.seqqc$Excluded_Flag == 0,c("Sample_Sequence", "File_Name", "Sequencing_Type")]))

filename.lookup <- file.table %>% 
  mutate(type      = gsub(".*_([BMP]+).*","\\1", File_Name)) %>%
  mutate(seq_order = recode( Sequencing_Type, WES="a", WGS="b", "srr-wgs"="b", "RNA-Seq"="c"  )) %>%
  group_by(Sample_Sequence) %>%
  arrange(type, seq_order) %>%   # prefer binding BM, WES file to sample where present
  slice(1) %>%
  select(Sample_Sequence, File_Name)

# verify that all Sample_Sequences have a corresponding Sample_Name before merge
# tmp <- df$Sample_Sequence[!(df$Sample_Sequence %in% filename.lookup$Sample_Sequence)]
# any(tmp %in% inv.wgs$Sample_Sequence)
#NOTE: we're throwing out 366 visit entries because we don't have any files associated with them

df <- merge(df, filename.lookup, by = "Sample_Sequence", all.x = T)
name <- paste("curated", name, sep = "_")
name <- gsub("csv", "txt", name)
path <- file.path(local,name)
write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)

###---
# we also want some of this pervisit information appended to every per-file row
# so we need to bind those columns to an unfiltered per-file table and save separately
df <- merge(file.table, select(df, 1:D_PrevBoneMarrowTransplant), by = "Sample_Sequence")
path <- file.path(local,"curated_MMRF_perfile_status.txt")
write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)


### PER_PATIENT -------------------------
# curate PER_PATIENT entries, requires some standalone tables for calculations
name <- "PER_PATIENT.csv"
perpatient <- read.csv(file.path(local,name), stringsAsFactors = F)

survival <- read.csv(file.path(local,"STAND_ALONE_SURVIVAL.csv"), stringsAsFactors = F)
medhx <- read.csv(file.path(local,"STAND_ALONE_MEDHX.csv"), stringsAsFactors = F)
famhx <- read.csv(file.path(local,"STAND_ALONE_FAMHX.csv"), stringsAsFactors = F)
respo <- read.csv(file.path(local,"STAND_ALONE_TRTRESP.csv"), stringsAsFactors = F)
treat <- read.csv(file.path(local,"STAND_ALONE_TREATMENT_REGIMEN.csv"), stringsAsFactors = F)


# collapse multiple columns of race info into a single delimited string
tmp <- perpatient[,c("D_PT_race", "DEMOG_AMERICANINDIA", "DEMOG_ASIAN", "DEMOG_BLACKORAFRICA", "DEMOG_WHITE", "DEMOG_OTHER")]
decoded_matrix <- data.frame(
  gsub("Checked", "AMERICANINDIAN", tmp$DEMOG_AMERICANINDIA),
  gsub("Checked", "ASIAN", tmp$DEMOG_ASIAN),
  gsub("Checked", "BLACKORAFRICAN", tmp$DEMOG_BLACKORAFRICA),
  gsub("Checked", "WHITE", tmp$DEMOG_WHITE),
  gsub("Checked", "OTHER", tmp$DEMOG_OTHER)
)
perpatient[['RACE']] <- apply(decoded_matrix, MARGIN = 1, function(x){
  x <- x[x != ""]
  paste(x, collapse = "; ")
})
rm(decoded_matrix, tmp)


df <- data.frame(Patient = perpatient$PUBLIC_ID, stringsAsFactors = F)
df[["D_Gender"]]                <- perpatient$DEMOG_GENDER
df[["D_Race"]]                  <- perpatient$RACE
df[["D_Age"]]                   <- perpatient$D_PT_age
df[["D_ISS"]]                   <- perpatient$D_PT_iss

# Calculate Overall Survival time. This is the reported ttos for deceased patients or 
#  time to last contact for those who are still living. Last contact is the max value from
#  PER_PATIENT.D_PT_lstalive, PER_PATIENT.lvisit, or mmrf.survival.oscdy fields. 
#  NA for any negative values. We need a lookup table to make these calculations.
# Previously we subtracted IC day, but have since removed this adjustment.

lookup_by_publicid <- lookup.values("public_id")
df[['D_OS']]       <- unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "ttcos"))
df[['D_OS_FLAG']]  <- unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "censos"))
df[['D_PFS']]      <- unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "ttcpfs"))
df[['D_PFS_FLAG']] <- unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "censpfs"))
df[['D_PD']]       <- unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "ttfpd"))
df[['D_PD_FLAG']]  <- unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "pdflag"))

df[["D_Cause_of_Death"]]             <-  perpatient$D_PT_CAUSEOFDEATH
df[["D_Reason_for_Discontinuation"]] <-  perpatient$D_PT_PRIMARYREASON
df[["D_Discontinued"]]               <-  perpatient$D_PT_discont
df[["D_Complete"]]                   <-  recode(perpatient$D_PT_complete, "2" = 0)

# filter response table using line =1 (first line treatment only), trtbresp=1 (Treatment best response) then find that response
best_response_table <- respo[respo$trtbresp == 1 & respo$line == 1 ,]
df[["D_Best_Response_Code"]] <-  unlist(lapply(df$Patient, lookup_by_publicid, dat = best_response_table, field = "bestrespcd"))
df[["D_Best_Response"]]      <-  unlist(lapply(df$Patient, lookup_by_publicid, dat = best_response_table, field = "bestresp"))

name <- paste("curated", name, sep = "_")
name <- gsub("csv", "txt", name)
path <- file.path(local,name)
write.table(df, path, row.names = F, col.names = T, sep = "\t", quote = F)


# put curated files back as ProcessedData on S3
processed <- file.path(s3,"ClinicalData/ProcessedData",paste0(study,"_IA9"))
system(  paste('aws s3 cp', local, processed, '--recursive --exclude "*" --include "curated*" --sse', sep = " "))

