
source("curation_scripts.R")
snv <- s3_get_with("ClinicalData/OriginalData/Joint",
                   "20170213.snvsindels.filtered.metadata.ndmmonly.slim.txt",
                   FUN = fread)


#  Oncotator variant annotation key
#  https://portals.broadinstitute.org/oncotator/help/
#  
silent.classes <- c("3'UTR", "5'Flank", "5'UTR","IGR", 
                    "Intron","lincRNA", "RNA", "Silent")
snv <- snv[!(Variant_Classification %in% silent.classes)] 
snv[, SNV_total_ns_variants_n := .N                         , by = metaname]
snv[, SNV_ns_mutated_genes_n  := length(unique(Hugo_Symbol)), by = metaname]

# http://genetics.bwh.harvard.edu/pph2/dokuwiki/overview
# PolyPhen-2 is an automatic tool for prediction of possible impact of an amino 
# acid substitution on the structure and function of a human protein. This 
# prediction is based on a number of features comprising the sequence, phylogenetic 
# and structural information characterizing the substitution. For a given amino 
# acid substitution in a protein, PolyPhen-2 extracts various sequence and 
# structure-based features of the substitution site and feeds them to a 
# probabilistic classifier.
# 
# Two pairs of datasets were used to train and test PolyPhen-2 prediction models. 
# The first pair, HumDiv, was compiled from all damaging alleles with known effects 
# on the molecular function causing human Mendelian diseases, present in the 
# UniProtKB database, together with differences between human proteins and their 
# closely related mammalian homologs, assumed to be non-damaging. The second pair, 
# HumVar, consisted of all human disease-causing mutations from UniProtKB, together 
# with common human nsSNPs (MAF>1%) without annotated involvement in disease, which 
# were treated as non-damaging.

# total variant counts by each classifier prediction
snv[,SNV_dbNSFP_Polyphen2_HDIV_pred_deleterious_variants_n := 
      sum(as.numeric(grepl("D", dbNSFP_Polyphen2_HDIV_pred))), 
    by = metaname]
snv[,SNV_dbNSFP_Polyphen2_HVAR_pred_deleterious_variants_n := 
      sum(as.numeric(grepl("D", dbNSFP_Polyphen2_HVAR_pred))), 
    by = metaname]

# count of classifier predicted deleterious genes
snv[grepl("D", dbNSFP_Polyphen2_HDIV_pred), 
    SNV_dbNSFP_Polyphen2_HDIV_pred_deleterious_genes_n  := length(unique(Hugo_Symbol)), 
    by = metaname]
snv[grepl("D", dbNSFP_Polyphen2_HVAR_pred), 
    SNV_dbNSFP_Polyphen2_HVAR_pred_deleterious_genes_n  := length(unique(Hugo_Symbol)), 
    by = metaname]

out <- snv[,lapply(.SD, max, na.rm = T), by = metaname, .SDcols = c("SNV_total_ns_variants_n", 
                                                         "SNV_ns_mutated_genes_n",
                                                         "SNV_dbNSFP_Polyphen2_HDIV_pred_deleterious_variants_n",
                                                         "SNV_dbNSFP_Polyphen2_HVAR_pred_deleterious_variants_n",
                                                         "SNV_dbNSFP_Polyphen2_HDIV_pred_deleterious_genes_n",
                                                         "SNV_dbNSFP_Polyphen2_HVAR_pred_deleterious_genes_n")] %>%
  rename(File_Name = metaname)

# confirm File_Name are in the correct format, and all exist in the metadata table
# s3_ls("ClinicalData/ProcessedData/JointData/")

metadata <- s3_get_with("ClinicalData/ProcessedData/JointData",
                        "curated.metadata.2017-05-16.txt",
                        FUN = fread)
all(out$File_Name%in%metadata$File_Name)


# write the table to an individual dated table, so we have the original source data saved in one place
# call it "mutational.burden.2017-07-06.txt"
# save here:
# s3_ls("ClinicalData/ProcessedData/Curated_Data_Sources")
s3_put_table(out, "ClinicalData/ProcessedData/Curated_Data_Sources/mutational.burden.2017-07-07.txt")

# Bind this as new columns onto the metadata table found in JointData
# meta <- s3_ls("ClinicalData/ProcessedData/JointData/")
meta_out <- left_join(metadata, out, by = "File_Name")
# write_new_version() # please look at this function before running, it's in curation_scripts.R
write_new_version(df = meta_out,
                  name = "curated.metadata",
                  dir = "ClinicalData/ProcessedData/JointData/")


########################################################################################################
# if you feel comfortable with how the mutational burden calculations were aggregated,
# please add to the mgp_dictionary, otherwise I can do it for you.
# dict <- get_dict()
dict <- get_dict()
# or download and manually edit
# s3_get_save("../Resources/mgp_dictionary.txt")
dict <- rbind(dict,
c("SNV_total_ns_variants_n", "metadata", NA, "numeric", "column_exists", NA, NA, "Total number of variants excluding silent classes", NA, NA, NA, NA, 0)) %>%
rbind(c("SNV_ns_mutated_genes_n", "metadata", NA, "numeric", "column_exists", NA, NA, "Total number of genes with variants excluding silet classes", NA, NA, NA, NA, 0)) %>%
rbind(c("SNV_dbNSFP_Polyphen2_HDIV_pred_deleterious_variants_n", "metadata", NA, "numeric", "column_exists", NA, NA, "Total variant counts by PolyPhen-2  HumDiv classifier prediction", NA, NA, NA, NA, 0)) %>%
rbind(c("SNV_dbNSFP_Polyphen2_HVAR_pred_deleterious_variants_n", "metadata", NA, "numeric", "column_exists", NA, NA, "Total variant counts by PolyPhen-2 HumVar classifier prediction", NA, NA, NA, NA, 0)) %>%
rbind(c("SNV_dbNSFP_Polyphen2_HDIV_pred_deleterious_genes_n", "metadata", NA, "numeric", "column_exists", NA, NA, "Count of deleterious genes predicted by PolyPhen-2  HumDiv classifier", NA, NA, NA, NA, 0)) %>%
rbind(c("SNV_dbNSFP_Polyphen2_HVAR_pred_deleterious_genes_n", "metadata", NA, "numeric", "column_exists", NA, NA, "Count of deleterious genes predicted by PolyPhen-2 HumVar classifier", NA, NA, NA, NA, 0))


write.table(dict, "mgp_dictionary.txt", row.names=F, quote=F, sep="\t")

# Propagate these JointData tables down through other tables
# Remember: JointData -> (remove excluded files) -> Master -> (filter for NewDiagnosis-Tumor-MM files/patients only) -> (collapse per-file rows to per-patient) -> ND_Tumor_MM -> (filter selected patients) -> ClusterA2/B/C/C2
# This entire process should be facilitated by running these:
#
#   table_flow()                    # filters and writes new versions each step
#   run_master_inventory()          # generates per-patient and per-study counts of all fields at /Reports
#   (results <- qc_master_tables()) # this should list any major qc issues in Master tables

table_flow() #metadata tables were updated
run_master_inventory() #no changes from previous version
results <- qc_master_tables() #0 obs


# update "Cluster" tables
# This will involve the most actual coding, but should be reasonable.
# 
# Use the flags on the "counts.by.individual" table to identify which patients are included in
# each "Cluster" subset. Filter per.patient tables from ND_Master_MM folder to include
# only those patients and write_new_version() into the corresponding folder.

  inv <- s3_get_table("/ClinicalData/ProcessedData/Reports/counts.by.individual.2017-06-14.txt")
  inv %>% select(Patient, starts_with("Cluster")) %>% sample_n(5)
  
  #Example:
  # Get patients in "A2" cluster
  inv %>% filter(Cluster.A2 == 1) %>% select(Patient) %>% head()
  patients.A2 <- inv %>% filter(Cluster.A2 == 1) %>% select(Patient)
  patients.B  <- inv %>% filter(Cluster.B== 1) %>% select(Patient)
  patients.C  <- inv %>% filter(Cluster.C == 1) %>% select(Patient)
  patients.C2 <- inv %>% filter(Cluster.C2 == 1) %>% select(Patient)
  
  # filter these from per.patient ND_Tumor tables
  s3_ls("/ClinicalData/ProcessedData/ND_Tumor_MM", pattern = "^per.patient", full.names = T)
  # to here
  s3_ls("/ClinicalData/ProcessedData/Cluster.C2/") 
  
  
  
  #### Update cluster A2 tables
  cluster.A2 <- sapply(s3_ls("/ClinicalData/ProcessedData/ND_Tumor_MM", pattern = "^per.patient", full.names = T), function(table){
    s3_get_table(table) %>%
      filter(Patient %in% patients.A2$Patient)
  })
  
  table.names <- sapply(basename(names(cluster.A2)), function(name){
    paste(strsplit(name, "\\.")[[1]][3], "subset", sep = ".")
  })
  
  sapply(1:length(cluster.A2), function(x){
    write_new_version(df = cluster.A2[[x]],
                      name = table.names[x],
                      dir = "/ClinicalData/ProcessedData/Cluster.A2/")
  })
  
  #Update patient list
  write_new_version(df = unname(as.vector(patients.A2)),
                    name = "patient.list",
                    dir = "/ClinicalData/ProcessedData/Cluster.A2/")
  
  #metadata, clinical, and translocation tables were updated
  
######Update Cluster B
  cluster.B <- sapply(s3_ls("/ClinicalData/ProcessedData/ND_Tumor_MM", pattern = "^per.patient", full.names = T), function(table){
    s3_get_table(table) %>%
      filter(Patient %in% patients.B$Patient)
  })
  
  table.names <- sapply(basename(names(cluster.B)), function(name){
    paste(strsplit(name, "\\.")[[1]][3], "subset", sep = ".")
  })
  
  sapply(1:length(cluster.B), function(x){
    write_new_version(df = cluster.B[[x]],
                      name = table.names[x],
                      dir = "/ClinicalData/ProcessedData/Cluster.B/")
  })
  
  #Update patient list
  write_new_version(df = unname(as.vector(patients.B)),
                    name = "patient.list",
                    dir = "/ClinicalData/ProcessedData/Cluster.B/")
  
  #metadata, clinical, and translocation tables were updated
  
  ######Update Cluster C
  cluster.C <- sapply(s3_ls("/ClinicalData/ProcessedData/ND_Tumor_MM", pattern = "^per.patient", full.names = T), function(table){
    s3_get_table(table) %>%
      filter(Patient %in% patients.C$Patient)
  })
  
  table.names <- sapply(basename(names(cluster.C)), function(name){
    paste(strsplit(name, "\\.")[[1]][3], "subset", sep = ".")
  })
  
  sapply(1:length(cluster.C), function(x){
    write_new_version(df = cluster.C[[x]],
                      name = table.names[x],
                      dir = "/ClinicalData/ProcessedData/Cluster.C/")
  })
  
  #Update patient list
  write_new_version(df = unname(as.vector(patients.C)),
                    name = "patient.list",
                   dir = "/ClinicalData/ProcessedData/Cluster.C/")
  
  #metadata, clinical, and translocation tables were updated
  
  ######Update Cluster C2
  cluster.C2 <- sapply(s3_ls("/ClinicalData/ProcessedData/ND_Tumor_MM", pattern = "^per.patient", full.names = T), function(table){
    s3_get_table(table) %>%
      filter(Patient %in% patients.C2$Patient)
  })
  
  table.names <- sapply(basename(names(cluster.C2)), function(name){
    paste(strsplit(name, "\\.")[[1]][3], "subset", sep = ".")
  })
  
  sapply(1:length(cluster.C2), function(x){
    write_new_version(df = cluster.C2[[x]],
                      name = table.names[x],
                      dir = "/ClinicalData/ProcessedData/Cluster.C2/")
  })
  
  #Update patient list
  write_new_version(df = unname(as.vector(patients.C2)),
                    name = "patient.list",
                    dir = "/ClinicalData/ProcessedData/Cluster.C2/")
  

  #metadata, clinical, and translocation tables were updated
 