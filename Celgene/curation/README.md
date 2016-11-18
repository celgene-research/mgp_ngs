### Approach to curation follows the following process:

1. Individual <data.txt> spreadsheets are curated to <curated_data.txt> and moved to /ClinicalData/ProcessedData/Study/. In these curated files new columns are added using the format specified in <mgp_dictionary.xlsx> and values are coerced into ontologically accurate values. These files are not filtered or organized per-se, but provides a normalized reference for where curated value columns are derived.
    - curate_DFCI.R
    - curate_MMRF_IA9.R
    - curate_UAMS.R
2. Results from aggregated genomic and expression analyses (SNV, CNV, RNA-Seq counts etc) are curated in a similar manner and copied to /ClinicalData/ProcessedData/JointData/
    - curate_JointData.R
3. <mgp_clinical_aggregation.R> is used to leverage our append_df() function, which loads curated columns (those matching a dictionary column) from each table into the main integrated table. This script also calls various inventory calling, consensus, differential aggregation and QC scripts on the aggregated dataset. Notably, the table_merge.R script joins the aggregated PER-FILE clinical/cytogenetic data to the various molecular summary tables that have been curated by curate_JointData.R 
    - mgp_clinical_aggregation.R
    - qc_and_summary.R
    - table_merge.R
4. Summary scripts to generate specific counts and aggregated summary values.


drozelle@ranchobiosciences.com
2016-11-18
