
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
                                                         "SNV_dbNSFP_Polyphen2_HVAR_pred_deleterious_genes_n")]


s3_ls("ClinicalData/ProcessedData/JointData/")
s3r::s3_put_table( "ClinicalData/ProcessedData/JointData/curated")