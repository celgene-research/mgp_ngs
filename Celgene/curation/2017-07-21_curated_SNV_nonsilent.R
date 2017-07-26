source("curation_scripts.R")
snv <- s3_get_with("ClinicalData/OriginalData/Joint",
                   "20170213.snvsindels.filtered.metadata.ndmmonly.slim.txt",
                   FUN = fread)

silent.classes <- c("3'UTR", "5'Flank", "5'UTR","IGR", 
                    "Intron","lincRNA", "RNA", "Silent")
snv_nonsilent <- snv[!(Variant_Classification %in% silent.classes)]

#Genes theat are filtered out when remove silend classes
silent.genes <- unique(snv$Hugo_Symbol[!snv$Hugo_Symbol%in%snv_nonsilent$Hugo_Symbol])

# select filename and gene name columns, add a "call" column as binary indicator 
#  (Does this gene have any mutations? 0=No; 1=Yes)
DT_nonsilent <- snv[!(Variant_Classification %in% silent.classes),.(File_Name = tumorname, Hugo_Symbol), .(call = rep(1, length(Hugo_Symbol))) ]
#Add 0 call for silent genes
DT_silent <- snv[(Hugo_Symbol %in% silent.genes),.(File_Name = tumorname, Hugo_Symbol), .(call = rep(0, length(Hugo_Symbol))) ]
# spread table long to wide so we have a file ~ gene binary matrix
DT <- dcast(rbind(DT_nonsilent, DT_silent), File_Name ~ Hugo_Symbol, value.var = "call", fun = function(x){ ifelse(sum(x)>=1,1,0) })

# rename columns, remove extraneous underscore characters from gene names
names(DT)    <- gsub("_+", "\\.", names(DT))
names(DT)    <- paste("SNV", names(DT), "BinaryConsensus", sep = "_")
names(DT)[1] <- "File_Name"

# clean File_Name as for CNVs above
DT$File_Name <- gsub("^_E.*?_([^E].*)$", "\\1", DT$File_Name)
DT$File_Name <- gsub("HUMAN_37_pulldown_", "", DT$File_Name)

#load snv matrix
snv_matrix <- s3_get_with("ClinicalData/ProcessedData/JointData",
                          "curated.snvnonsilent.2017-07-24.txt",
                          FUN = fread)


#Check that file names are the same
# all(DT$File_Name%in%snv_matrix$File_Name)
# [1] TRUE
# all(snv_matrix$File_Name%in%DT$File_Name)
# [1] TRUE

#Add patient column
DT <- left_join(snv_matrix[,1:2], DT, by="File_Name")

#Check that column names are the same
# all(names(DT)%in%names(snv_matrix))
# [1] TRUE
# all(names(snv_matrix)%in%names(DT))
# [1] TRUE

#Check sum of snv_nonsilet is less than sum snv
#sum(DT[,3:length(DT)])
#[1] 106630
#sum(snv_matrix[,3:length(snv_matrix)])
#[1] 485852

#Check that patients are in the same order
# all(DT$Patient==snv_matrix$Patient)
# [1] TRUE

#Check sum per patient non silent is less then sum per patient snv
# all((rowSums(DT[,3:length(DT)]) - rowSums(snv_matrix[,3:length(snv_matrix)]))<0)
# [1] TRUE

# confirm File_Name are in the correct format, and all exist in the metadata table
# s3_ls("ClinicalData/ProcessedData/JointData/")

# metadata <- s3_get_with("ClinicalData/ProcessedData/JointData",
#                         "curated.metadata.2017-07-07.txt",
#                         FUN = fread)
# all(DT$File_Name%in%metadata$File_Name)
# [1] TRUE

s3_put_table(DT, "ClinicalData/ProcessedData/JointData/curated.snvnonsilent.2017-07-25.txt")


table_flow()
run_master_inventory()
#[1] "counts.by.individual ; new version written"
#[1] "counts.by.study ; new version written"
results <- qc_master_tables() #0 obs


# Update "Cluster" tables
inv <- s3_get_table("/ClinicalData/ProcessedData/Reports/counts.by.individual.2017-07-25.txt")

patients.A2 <- inv %>% filter(Cluster.A2 == 1) %>% select(Patient)
patients.B  <- inv %>% filter(Cluster.B== 1) %>% select(Patient)
patients.C  <- inv %>% filter(Cluster.C == 1) %>% select(Patient)
patients.C2 <- inv %>% filter(Cluster.C2 == 1) %>% select(Patient)

#### Update cluster A2 tables
cluster.A2 <- sapply(s3_ls("/ClinicalData/ProcessedData/ND_Tumor_MM", pattern = "^per.patient", full.names = T), function(table){
  s3_get_with(table,
              FUN = fread) %>%
    filter(Patient %in% patients.A2$Patient)
})

cluster.A2 <- cluster.A2[-10]

table.names <- sapply(basename(names(cluster.A2)), function(name){
  paste(strsplit(name, "\\.")[[1]][3], "subset", sep = ".")
})

sapply(1:length(cluster.A2), function(x){
  write_new_version(df = cluster.A2[[x]],
                    name = table.names[x],
                    dir = "/ClinicalData/ProcessedData/Cluster.A2/")
  #For new tables
  prev.path <- s3_ls("/ClinicalData/ProcessedData/Cluster.A2/", pattern = paste0("^",table.names[x],"\\.")) 
  if( length(prev.path) == 0){
    print("Adding new table:")
    s3_put_table(cluster.A2[[x]], paste0("/ClinicalData/ProcessedData/Cluster.A2/", paste(table.names[x], Sys.Date(), "txt", sep = ".")))
  }
})

#Update patient list
write_new_version(df = unname(as.vector(patients.A2)),
                  name = "patient.list",
                  dir = "/ClinicalData/ProcessedData/Cluster.A2/")

#### Update cluster B tables
cluster.B <- sapply(s3_ls("/ClinicalData/ProcessedData/ND_Tumor_MM", pattern = "^per.patient", full.names = T), function(table){
  s3_get_with(table,
              FUN = fread) %>%
    filter(Patient %in% patients.B$Patient)
})

cluster.B <- cluster.B[-10]

table.names <- sapply(basename(names(cluster.B)), function(name){
  paste(strsplit(name, "\\.")[[1]][3], "subset", sep = ".")
})

sapply(1:length(cluster.B), function(x){
  write_new_version(df = cluster.B[[x]],
                    name = table.names[x],
                    dir = "/ClinicalData/ProcessedData/Cluster.B/")
  #For new tables
  prev.path <- s3_ls("/ClinicalData/ProcessedData/Cluster.B/", pattern = paste0("^",table.names[x],"\\.")) 
  if( length(prev.path) == 0){
    print("Adding new table:")
    s3_put_table(cluster.B[[x]], paste0("/ClinicalData/ProcessedData/Cluster.B/",paste(table.names[x], Sys.Date(), "txt", sep = ".")))
  }
})

#Update patient list
write_new_version(df = unname(as.vector(patients.B)),
                  name = "patient.list",
                  dir = "/ClinicalData/ProcessedData/Cluster.B/")

#### Update cluster C tables
cluster.C <- sapply(s3_ls("/ClinicalData/ProcessedData/ND_Tumor_MM", pattern = "^per.patient", full.names = T), function(table){
  s3_get_with(table,
              FUN = fread) %>%
    filter(Patient %in% patients.C$Patient)
})

cluster.C <- cluster.C[-10]

table.names <- sapply(basename(names(cluster.C)), function(name){
  paste(strsplit(name, "\\.")[[1]][3], "subset", sep = ".")
})

sapply(1:length(cluster.C), function(x){
  write_new_version(df = cluster.C[[x]],
                    name = table.names[x],
                    dir = "/ClinicalData/ProcessedData/Cluster.C/")
  #For new tables
  prev.path <- s3_ls("/ClinicalData/ProcessedData/Cluster.C/", pattern = paste0("^",table.names[x],"\\.")) 
  if( length(prev.path) == 0){
    print("Adding new table:")
    s3_put_table(cluster.C[[x]], paste0("/ClinicalData/ProcessedData/Cluster.C/",paste(table.names[x], Sys.Date(), "txt", sep = ".")))
  }
})

#Update patient list
write_new_version(df = unname(as.vector(patients.C)),
                  name = "patient.list",
                  dir = "/ClinicalData/ProcessedData/Cluster.C/")

#### Update cluster C2 tables
cluster.C2 <- sapply(s3_ls("/ClinicalData/ProcessedData/ND_Tumor_MM", pattern = "^per.patient", full.names = T), function(table){
  s3_get_with(table,
              FUN = fread) %>%
    filter(Patient %in% patients.C2$Patient)
})

cluster.C2 <- cluster.C2[-10]

table.names <- sapply(basename(names(cluster.C2)), function(name){
  paste(strsplit(name, "\\.")[[1]][3], "subset", sep = ".")
})

sapply(1:length(cluster.C2), function(x){
  write_new_version(df = cluster.C2[[x]],
                    name = table.names[x],
                    dir = "/ClinicalData/ProcessedData/Cluster.C2/")
  #For new tables
  prev.path <- s3_ls("/ClinicalData/ProcessedData/Cluster.C2/", pattern = paste0("^",table.names[x],"\\.")) 
  if( length(prev.path) == 0){
    print("Adding new table:")
    s3_put_table(cluster.C2[[x]], paste0("/ClinicalData/ProcessedData/Cluster.C2/",paste(table.names[x], Sys.Date(), "txt", sep = ".")))
  }
})

#Update patient list
write_new_version(df = unname(as.vector(patients.C2)),
                  name = "patient.list",
                  dir = "/ClinicalData/ProcessedData/Cluster.C2/")


#########################QC
# master_snv <- s3_get_with("ClinicalData/ProcessedData/Cluster.C2",
#                    "snv.subset.2017-05-17.txt",
#                    FUN = fread)
# 
# master_nonsilent <- s3_get_with("ClinicalData/ProcessedData/Cluster.C2",
#                                 "snvnonsilent.subset.2017-07-25.txt",
#                                 FUN = fread)
# 
# all(names(master_snv)%in%names(master_nonsilent))
# #TRUE
# 
# 
# all(master_snv$File_Name%in%master_nonsilent$File_Name)
# all(master_snv$Patient==master_nonsilent$Patient)
# 
# #Check sum of snv_nonsilet is less than sum snv
# sum(master_snv[,3:length(master_snv)])
# 
# sum(master_nonsilent[,3:length(master_nonsilent)])
# 
# 
# #Check sum per patient non silent is less then sum per patient snv
#  all((rowSums(master_nonsilent[,3:length(master_nonsilent)]) - rowSums(master_snv[,3:length(master_snv)]))<0)
# # [1] TRUE
