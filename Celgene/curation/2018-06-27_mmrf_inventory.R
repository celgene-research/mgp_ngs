library(s3r)

s3_set(bucket = "celgene.rnd.combio.mmgp.external")
s3_ls("SeqData/WES/OriginalData/MMRF", recursive = T, pattern = "bam$")
s3_ls("SeqData/RNA-Seq/OriginalData/MMRF", recursive = T, pattern = "bam$")
s3_ls("SeqData/WGS/OriginalData/MMRF", recursive = T, pattern = "bam$")

### code to write raw a inventory is only run periodically
### NOTE: this is not filtered/deduplicated in any way
# wes <- system('aws s3 ls s3://celgene.rnd.combio.mmgp.external/SeqData/WES/OriginalData/MMRF/ --recursive | grep bam$', intern = T)
# rna <- system('aws s3 ls s3://celgene.rnd.combio.mmgp.external/SeqData/RNA-Seq/OriginalData/MMRF/ --recursive | grep bam$', intern = T)
# wgs <- system('aws s3 ls s3://celgene.rnd.combio.mmgp.external/SeqData/WGS/OriginalData/MMRF/ --recursive | grep -e bam$ -e gz$', intern = T)
# inv <- c(wes, rna, wgs)
# inv <- gsub(".*SeqData", "SeqData", inv)
# inv <- data.frame(File_Path = inv, stringsAsFactors = FALSE)
# PutS3Table(inv, file.path(s3, ia10.in, "mmrf.file.inventory.txt"))






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
