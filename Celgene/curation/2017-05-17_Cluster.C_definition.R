# Systematically generate Cluster.C
# compare with UAMS-defined cluster.800

# UAMS Cluster.C
# > Start with 1313 WES samples
# > Keep only samples with copy number data (the ?CopyNumber.Pass? column), which is 1106 samples
# > We found that patients aged 75 or older perform poorly, so removed them: 916 samples
# > Required ISS stage data: 831 samples
# > Survival data required: 800 samples

# Code added to curation_scripts::run_master_inventory() function
# Cluster.C    = (INV_Has.WES & 
#                   INV_Has.nd.cnv &  
#                   INV_Under75 &
#                   INV_Has.iss &
#                   INV_Has.pfsos  )
#                   

source("curation_scripts.R")
inv <- run_master_inventory()

# print the new cluster aggregated counts
inv$per.study.counts %>%
  filter(startsWith(Category, "Cluster") )

# get a list of the Cluster.C patients
cluster.c <- inv$per.patient.counts %>%
  filter( Cluster.C == 1 )

cluster.800 <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData",
                        "Cluster800/2017-04-07_TrainTest_from_ChrisWardell.txt")) %>%
  filter(TRAINTEST != "0") 

# compare
venn::venn(list("C" = cluster.c$Patient, "800" = cluster.800$Patient), cexil = 1.3, cexsn = 1)

# run the cluster framework to generate Cluster.C
joint.meta <- GetS3Table(file.path(s3, "ClinicalData/ProcessedData/JointData",
                                   "curated.metadata.2017-05-16.txt"))
only.c   <- cluster.c$Patient[!cluster.c$Patient %in% cluster.800$Patient]
only.800 <- cluster.800$Patient[!cluster.800$Patient %in% cluster.c$Patient]

# use the jointData version since it includes excluded files
tmp <- joint.meta %>%
  filter(Patient %in% only.800)

# Conclusions
# 1153 was excluded by MMRF
# 1300 has no ISS score
# 1332 doesn't have valid cnv info
# all others are from PCL patients
