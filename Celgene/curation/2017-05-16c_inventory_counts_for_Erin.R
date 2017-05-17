source("curation_scripts.R")
per.person <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Reports",
                                   "counts.by.individual.2017-05-16.txt"))

names(per.person)

agg <- per.person %>% 
  group_by(Study) %>%
  select(INV_Has.ND, INV_Has.R, INV_Has.WES, INV_Has.WGS, INV_Has.RNASeq) %>%
  summarise_if(is.numeric, sum)



# based on file types
venn::venn(per.person %>% 
             transmute(`New Diagnosis` = INV_Has.ND, 
                       Relapse         = INV_Has.R, 
                       WES             = INV_Has.WES, 
                       WGS             = INV_Has.WGS, 
                       `RNA-Seq`       = INV_Has.RNASeq), 
           cexil = 1)

# based on analysis results, for ND samples only
plot_venn <- function(df){
venn::venn(df %>% 
             transmute(
               `PFS and OS`      = INV_Has.pfsos,
               `SNVs called`     = INV_Has.nd.snv, 
               `RNA-Seq Counts`  = INV_Has.nd.rna, 
               `CNVs called`     = INV_Has.nd.cnv, 
               `Translocations` = INV_Has.nd.Translocations) ,
           cexil = 1, zcolor = "style"
           )
}

pdf(file.path(local, paste("datatype.venn", "MGP", d, "pdf", sep = ".")))
plot_venn(per.person)
dev.off()

lapply(unique(per.person$Study), function(study){
  pdf(file.path(local, paste("datatype.venn", study, d, "pdf", sep = ".")))
  df <- per.person %>% filter(Study == study)
  plot_venn(df)
  title(study)
  dev.off()
})

system(paste('aws s3 cp',
             paste0(local, "/"),
             file.path(s3, "ClinicalData/ProcessedData/Reports/"),
                       "--recursive --sse"))


# check out why so many with no data types (100)
tmp <- per.person %>% 
  transmute(
    `PFS and OS`      = INV_Has.pfsos,
    `SNVs called`     = INV_Has.nd.snv, 
    `RNA-Seq Counts`  = INV_Has.nd.rna, 
    `CNVs called`     = INV_Has.nd.cnv, 
    `Translocations` = INV_Has.nd.Translocations)


no.results <- apply(tmp,1,function(x){sum(x) == 0})
empty      <- per.person[no.results,]

joint.meta <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/JointData",
                                   "curated.metadata.2017-05-16.txt"))
master     <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/Master",
                                   "curated.metadata.2017-05-16.txt"))

empty <- master %>% filter(Patient %in% empty$Patient) 

rna.curated  <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/JointData",
                            "curated.rnaseq.2017-04-17.txt"))
rna.orig   <- GetS3Table(file.path(s3, "ClinicalData/OriginalData/Joint",
                                   "RNAseq_MMRF_DFCI_Normalized_BatchCorrected_2017-03-30.txt"))
orignal.rnaseq.filenames <- names(rna.orig)

table(empty$File_Name %in% orignal.rnaseq.filenames)


