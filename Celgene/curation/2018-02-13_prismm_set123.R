## -----------------------------------------------------
## MM-010 WGS DA0000201
bm <- auto_read("~/rancho/celgene/prismm/data/set1/186bm/data.import_PRISMM.cram.1_2017.10.25.xlsx", skip = 7)
pb <- auto_read("~/rancho/celgene/prismm/data/set1/173pbmc/data.import_PRISMM.cram.2_2017.10.25.xlsx", skip = 7)

# how many tumor samples have paired normal from the same subject
bm <- bm %>%
  ungroup() %>%
  mutate(paired_normal = celgene_id %in% pb$celgene_id)
sum(bm$paired_normal)
# 186 bm samples with paired normal

all(bm$paired_normal)
# TRUE all bm samples are paired with a normal control

length(unique(bm$celgene_id))
# 166 unique subjects


## -----------------------------------------------------
## IFM-2009 WGS for DA0000435
## celgene-src-bucket/DA0000435/WGS/Processed
##
  
normal <- auto_read("~/rancho/celgene/prismm/data/set2-3/DA0000435_wgs30_samples.csv")
normal %>% group_by(celgene_id)
# 92 samples for 92 subjects

tumor  <- auto_read("~/rancho/celgene/prismm/data/set2-3/DA0000435_wgs60_samples.csv")
tumor %>% group_by(celgene_id)
# 111 samples for 90 subjects

# how many tumor samples have paired normal from the same subject
tumor <- tumor %>%
  ungroup() %>%
  mutate(paired_normal = celgene_id %in% normal$celgene_id)
all(tumor$paired_normal)
# TRUE

### which samples are missing from the original request?
incoming_samples <-auto_read("~/rancho/celgene/prismm/data/Celgene DNA master list_2.9.18.xls") %>%
filter(Site =="Celgene SF_DFCI")

venn::venn(list(`DNA master`     = incoming_samples$Sample.ID,  
                `Tumor` = tumor$vendor_id, 
                `Normal`= normal$vendor_id), cexil = 1)

tmp <- incoming_samples %>%
  filter(Sample.ID %in% tumor$vendor_id) 
table(tmp$Site)




tumor_metrics  <- auto_read("~/rancho/celgene/prismm/data/set2-3/Celgene DFCI sets 2-3 Tumors_Seq Metrics_Dec2017.xlsx")
venn::venn(list(tumor= tumor$celgene_id, tumor_metrics=tumor_metrics$Collaborator.Participant.ID), cexil = 1)

incoming_sample<- auto_read("~/rancho/celgene/prismm/data/set2-3/IncomingSampleIDs.txt")
venn::venn(list(tumor= tumor$celgene_id,
                normal=normal$celgene_id,
                tumor_metrics=tumor_metrics$Collaborator.Participant.ID,
                incoming = incoming_sample$Sample), cexil = 1)

# check against the actual file list
files <- auto_read("~/rancho/celgene/prismm/data/set2-3/2018-02-13_file_list.txt", header = F)

# confirm that all expected files are in the bucket
venn::venn(list(tumor= tumor$filename, normal=normal$filename, files=files$V1), cexil = 1)

tumor %>% group_by(celgene_id)
venn::venn(list(tumor= tumor$celgene_id, normal=normal$celgene_id), cexil = 1)

