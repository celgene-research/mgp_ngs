source("curation_scripts.R")


clinical <- s3_get_with("ClinicalData/ProcessedData/JointData/curated.clinical.2017-05-31.txt", FUN = fread) 


clinical$D_ISS[clinical$Patient == "MMRF_1300"] <- 1

write_new_version(df = clinical,
                  name = "curated.clinical",
                  dir = "ClinicalData/ProcessedData/JointData/")

table_flow()
run_master_inventory()
#[1] "counts.by.individual ; new version written"
#[1] "counts.by.study ; new version written"
results <- qc_master_tables() #0 obs


inv <- s3_get_table("/ClinicalData/ProcessedData/Reports/counts.by.individual.2017-08-08.txt")


update_clusters <- function(cluster){
  print(paste("Updating ", cluster))
  patients <- inv %>% filter(get(cluster) == 1) %>% select(Patient)
  
  tables <- sapply(s3_ls("/ClinicalData/ProcessedData/ND_Tumor_MM", pattern = "^per.patient", full.names = T), function(table){
    s3_get_table(table) %>%
      filter(Patient %in% patients$Patient)
  })
    
    tables <- tables[-10]
    
    table.names <- sapply(basename(names(tables)), function(name){
      paste(strsplit(name, "\\.")[[1]][3], "subset", sep = ".")
      
    })
    sapply(1:length(tables), function(x){
        write_new_version(df = tables[[x]],
                          name = table.names[x],
                          dir = paste0("/ClinicalData/ProcessedData/", cluster))
      })
      
    #Update patient list
    write_new_version(df = unname(as.vector(patients)),
                        name = "patient.list",
                        dir = paste0("/ClinicalData/ProcessedData/", cluster)
    )
   
}

update_clusters("Cluster.A2")
update_clusters("Cluster.B")
update_clusters("Cluster.C")
update_clusters("Cluster.C2")
update_clusters("Cluster.D")
update_clusters("Cluster.E")