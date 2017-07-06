
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

# write the table to an individual dated table, so we have the original source data saved in one place
# call it "mutational.burden.2017-07-06.txt"
# save here:
# s3_ls("ClinicalData/ProcessedData/Curated_Data_Sources")

# Bind this as new columns onto the metadata table found in JointData
# meta <- s3_ls("ClinicalData/ProcessedData/JointData/")
# left_join(meta, out)
# write_new_version() # please look at this function before running, it's in curation_scripts.R

# Propogate these JointData tables down through other tables
# Remember: JointData -> (remove excluded files) -> Master -> (filter for NewDiagnosis-Tumor-MM files/patients only) -> (collapse per-file rows to per-patient) -> ND_Tumor_MM -> (filter selected patients) -> ClusterA2/B/C/C2
# 

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
  
  # filter these from per.patient ND_Tumor tables
  s3_ls("/ClinicalData/ProcessedData/ND_Tumor_MM", pattern = "^per.patient", full.names = T)
  # to here
  s3_ls("/ClinicalData/ProcessedData/Cluster.A2") 
   
  