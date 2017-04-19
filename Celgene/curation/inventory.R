#
# 2017-04-18 Dan Rozelle
# 
# The inventory script uses /Master clinical, metadata, and molecular tables 
# which have been filtered to remove excluded samples and patients. It write both
# patient-level inventory matices and study-level count aggregates to a dated 
# ClinicalData/ProcessedData/Reports file.
# 

source("curation_scripts.R")
PRINTING = FALSE
copy.s3.to.local(file.path(s3, "ClinicalData/ProcessedData/Master"),
                 aws.args = '--recursive --exclude "*" --include "curated_*" --exclude "archive*"')
f <- list.files(local, full.names = T)
dts <- lapply(f, fread)
names(dts) <- gsub("curated_([a-z]+).*", "\\1", tolower(basename(f)))
names(dts)

nd <- dts$metadata[Disease_Status == "ND" & Sample_Type_Flag == "1" & Disease_Type == "MM" ,File_Name]
  
# generate lookup tables for each parameter
has.demog <- dts$clinical[do.call("|", list(!is.na(D_Gender),   !is.na(Disease_Type))) ,.(Patient)]
has.pfsos <- dts$clinical[do.call("|", list(!is.na(D_PFS), !is.na(D_OS))) ,.(Patient)]
has.iss   <- dts$clinical[!is.na(D_ISS) , .(Patient)]
under75   <- dts$clinical[!is.na(D_Age)  & D_Age < 75, .(Patient)]
has.blood <- dts$blood[File_Name %in% nd][do.call("|", list(!is.na(DIAG_Beta2Microglobulin),      !is.na(DIAG_Albumin))) ,.(Patient)]

has.nd.bi    <- dts$biallelicinactivation[File_Name %in% nd][do.call("|", list(!is.na(BI_TP53_Flag), !is.na(BI_NRAS_Flag))) ,.(Patient)]
has.nd.cnv   <- dts$cnv[File_Name %in% nd][do.call("|", list(!is.na(CNV_TP53_ControlFreec), !is.na(CNV_NRAS_ControlFreec))) ,.(Patient)]
has.nd.rna   <- dts$rnaseq[File_Name %in% nd][do.call("|", list(!is.na(RNA_ENSG00000141510.16), !is.na(RNA_ENSG00000213281.4))) ,.(Patient)]
has.nd.snv   <- dts$snv[File_Name %in% nd][do.call("|", list(!is.na(SNV_TP53_BinaryConsensus), !is.na(SNV_NRAS_BinaryConsensus))) ,.(Patient)]
has.nd.trsl  <- dts$translocations[File_Name %in% nd][CYTO_Translocation_Consensus %in% c("None", "4", "6", "11", "12", "16", "20")  ,.(Patient)]

# generate a new patient-level inventory table
inv <- dts$metadata %>% 
  group_by(Study, Patient) %>%
  summarise( 
    INV_Has.ND         = any(Disease_Status == "ND"),
    INV_Has.R          = any(Disease_Status == "R"),
    INV_Has.TumorSample     = any(Sample_Type_Flag == "1"),
    INV_Has.NormalSample    = any(Sample_Type_Flag == "0"),
    INV_Has.ND.TumorSample  = any(paste0(Disease_Status,Sample_Type_Flag) == "ND1"),
    INV_Has.WES        = any(Sequencing_Type == "WES"),
    INV_Has.WGS        = any(Sequencing_Type == "WGS"),
    INV_Has.RNASeq     = any(Sequencing_Type == "RNA-Seq"),
    INV_Has.ND.WES     = any(paste0(Disease_Status,Sequencing_Type) == "NDWES"),
    INV_Has.ND.WGS     = any(paste0(Disease_Status,Sequencing_Type) == "NDWGS"),
    INV_Has.ND.RNASeq  = any(paste0(Disease_Status,Sequencing_Type) == "NDRNA-Seq"),
    INV_Has.R.WES      = any(paste0(Disease_Status,Sequencing_Type) == "RWES"),
    INV_Has.R.WGS      = any(paste0(Disease_Status,Sequencing_Type) == "RWGS"),
    INV_Has.R.RNASeq   = any(paste0(Disease_Status,Sequencing_Type) == "RRNA-Seq"),
    
    INV_Has.Tumor.ND.WES    = any(paste0(Sample_Type_Flag, Disease_Status,Sequencing_Type) == "1NDWES"),
    INV_Has.Tumor.ND.WGS    = any(paste0(Sample_Type_Flag, Disease_Status,Sequencing_Type) == "1NDWGS"),
    INV_Has.Tumor.ND.RNASeq = any(paste0(Sample_Type_Flag, Disease_Status,Sequencing_Type) == "1NDRNA-Seq"),
    INV_Has.Tumor.R.WES    = any(paste0(Sample_Type_Flag, Disease_Status,Sequencing_Type)  == "1RWGS"),
    INV_Has.Tumor.R.WGS    = any(paste0(Sample_Type_Flag, Disease_Status,Sequencing_Type)  == "1RWES"),
    INV_Has.Tumor.R.RNASeq = any(paste0(Sample_Type_Flag, Disease_Status,Sequencing_Type)  == "1RRNA-Seq"),
    
    INV_Has.demog          = any(Patient %in% has.demog$Patient ),
    INV_Has.pfsos          = any(Patient %in% has.pfsos$Patient ),
    INV_Has.iss            = any(Patient %in% has.iss$Patient   ),
    INV_Under75            = any(Patient %in% under75$Patient   ),
    
    INV_Has.blood          = any(Patient %in% has.blood$Patient ),
    INV_Has.nd.bi             = any(Patient %in% has.nd.bi$Patient    ),
    
    INV_Has.nd.cnv            = any(Patient %in% has.nd.cnv$Patient   ),
    INV_Has.nd.rna            = any(Patient %in% has.nd.rna$Patient   ),
    INV_Has.nd.snv            = any(Patient %in% has.nd.snv$Patient   ),
    INV_Has.nd.Translocations = any(Patient %in%  has.nd.trsl$Patient ),
    
    Cluster.A2    = (INV_Has.ND.TumorSample & 
                       INV_Has.pfsos &
                       INV_Has.nd.cnv & 
                       INV_Has.nd.rna &
                       INV_Has.nd.snv & 
                       INV_Has.nd.Translocations ),
    Cluster.B     = (Cluster.A2 &
                       INV_Has.iss &
                       INV_Under75 & 
                       INV_Has.blood)  )%>%
  mutate_if(is.logical, as.numeric)

n <- paste0(d, "_patient_inventory_counts.txt" )
if(PRINTING) PutS3Table(inv, file.path(s3, "ClinicalData/ProcessedData/Reports", n))

# Study-level matrix
per.study.counts <- inv %>% group_by(Study) %>% summarise_if(is.numeric, sum)

df <- as.data.frame(t(per.study.counts), stringsAsFactors = F)
names(df) <- df[1,]
df <- df[2:nrow(df),]
df["Total"] <- apply(df, MARGIN = 1, function(x){sum(as.integer(x))})
df[['Category']] <- row.names(df)

n <- paste0(d, "_study_inventory_counts.txt" )
if(PRINTING) PutS3Table(df, file.path(s3, "ClinicalData/ProcessedData/Reports", n), row.names = F, quote = F)


# generate a venn diagram

list(ND=inv)

library(venn)
venn::venn()
venn(5, ilab=TRUE, zcolor = "style")

# an equivalent command
venn("100 + 110 + 101 + 111")

# another equivalent command
venn(c("100", "110", "101", "111"))


# adding the labels for the intersections
venn("1--", ilabels = TRUE)

# using different parameters for the borders
venn(4, lty = 5, col = "navyblue")

# using ellipses
venn(4, lty = 5, col = "navyblue", ellipse = TRUE)

# a 5 sets Venn diagram
venn(5)

# a 5 sets Venn diagram using ellipses
venn(5, ellipse = TRUE)

# a 5 sets Venn diagram with intersection labels
venn(5, ilabels = TRUE)

# and a predefined color style
venn(5, ilabels = TRUE, zcolor = "style")

# a union of two sets
venn("1---- + ----1")

# with different colors
venn("1---- + ----1", zcolor = c("red", "blue"))

# same colors for the borders
venn("1---- + ----1", zcolor = c("red", "blue"), col = c("red", "blue"))

# 6 sets diagram
venn(6)

# 7 sets "Adelaide"
venn(7)


# artistic version
venn(c("1000000", "0100000", "0010000", "0001000",
       "0000100", "0000010", "0000001", "1111111"))

# when x is a list
set.seed(12345)
x <- list(First = 1:20, Second = 10:30, Third = sample(25:50, 15))
venn(x, snames = T)

# when x is a dataframe
set.seed(12345)
x <- as.data.frame(matrix(sample(0:1, 150, replace=TRUE), ncol=5))
venn(x)


# using disjunctive normal form notation
venn("A + Bc", snames = "A,B,C,D")

# the union of two sets, example from above
venn("A + E", snames = "A,B,C,D,E", zcol = c("red", "blue"))

# if the expression is a valid R statment, it works even without quotes
venn(A + bc + DE, snames = "A,B,C,D,E", zcol = c("red", "palegreen", "blue"))
