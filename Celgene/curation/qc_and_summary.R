
# This is a manual patch for filling in missing data for rows that are for all intents
# the same. (e.g., if D_PrevBoneMarrowTransplant is called for one File_Name, it should be the same for all other
# File_Name rows of the same Sample_Name)
# by specifies the grouping to consider equal
# columns is a list of columns to perform this operation on.
# FillCommonRows <- function(df, by = "Sample_Name", columns){
# 
#   ddply(df, .(Sample_Name), summarize, unique(D_PrevBoneMarrowTransplant))
#   
#   
# }


# df <- per.file
# by = "Sample_Name"
# columns <- c("D_PrevBoneMarrowTransplant", "Sample_Study_Day" )





# columns required for df: c("Sample_Name", "File_Path", "Excluded_Flag")
remove_invalid_samples <- function(df){
  
  # Only keep rows where we have a File_Name
  if( "File_Path" %in% names(df) ){ df <- filter(df, !is.na(File_Path)) }
  
  # Warn if any don't have a Sample_Name
  if( any(is.na(df$Sample_Name)) ){
    warning(paste(sum(is.na(df$Sample_Name)),  
                  "rows do not have a valid Sample_Name",
                  sep = " "))  }
  
  # Get the table of excluded patients
  ex <- GetS3Table(file.path("s3://celgene.rnd.combio.mmgp.external",
                             "ClinicalData/ProcessedData/JointData",
                             "Excluded_Samples.txt"))
  
  excluded.files <- df %>% 
    filter(Sample_Name %in% ex$Sample_Name |
           Excluded_Flag == "1" )%>%
    select(Sample_Name, File_Name, Sequencing_Type) %>%
    arrange(File_Name)
  
  excluded.files <- merge(excluded.files, ex, by = "Sample_Name", all.x = T)
  
  # generate disease.type column based on file types
  df <- df %>% group_by(Patient) %>%
    mutate(tissue_cell = paste(tolower(Tissue_Type), tolower(Cell_Type), sep="-")) %>%
    mutate(Disease_Type = ifelse("pb-cd138pos" %in% tissue_cell, "PCL", "MM"))%>%
    select(-tissue_cell) %>%
    ungroup()
  
  # remove PCL files by enabling this region
  remove.pcl.files <- FALSE
  if(remove.pcl.files){ 
    
    pcl.files <- df %>%
      subset(Disease_Type == "PCL")%>%
      select(Sample_Name, File_Name, Sequencing_Type) %>%
      mutate(Note = "patient has Plasma Cell Leukemia (PB with CD138 cells)") %>%
      arrange(File_Name)
    
    excluded.files <- rbind(excluded.files, pcl.files)
    }
  
  # Push table of removed files to S3 and throw warning
  if( nrow(excluded.files) > 0 ){
    warning(paste(nrow(excluded.files),  
                  "files were removed that have been excluded",
                  sep = " "))
    PutS3Table(excluded.files, "s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/Integrated/Excluded_Samples.txt")
  }
  
  # Remove excluded files from table and return
  df <- df %>% filter(!(File_Name %in% excluded.files$File_Name))
  as.data.frame(df)
}

remove_sensitive_columns <- function(df, dict){
  sensitive_columns <- dict[dict$sensitive == "1","names"]
  df[,!(names(df) %in% sensitive_columns)]
}

remove_unsequenced_patients <- function(p,f){
  unsequenced_patients <- unique(p$Patient)[!unique(p$Patient) %in% unique(f$Patient)]
  warning(paste(length(unsequenced_patients), "patients did not have sequence data and were removed", sep = " "))
  
  # write.object("unsequenced_patients", env = environment())
  p[!p$Patient %in% unsequenced_patients,]
}





summarize_clinical_parameters <- function(df_perpatient){
  df <- df_perpatient
  df[df==""] <- NA
  df[['coded_gender']] <- ifelse(df$D_Gender == "Male",1,0) #0=Female; 1=Male
  summary_fields <- c("coded_gender","D_Age", "D_OS", "D_PFS", "D_OS_FLAG", "D_PFS_FLAG")
  
  df <- aggregate.data.frame(df[, names(df) %in% summary_fields ], by = list(df$Study), function(x){
    round(mean(as.numeric(x), na.rm = T),2)
  })
  
  #rename and reorder
  names(df) <- c("Study", "Mean_Age", "Mean_OS_days", "Proportion_Deceased", "Mean_PFS_days", "Proportion_Progressed", "Proportion_Gender_male")
  df<- df[, c("Study", "Mean_Age", "Proportion_Gender_male", "Mean_OS_days", "Proportion_Deceased", "Mean_PFS_days", "Proportion_Progressed")]  
  
  write_to_s3integrated(df, "report_summary_statistics.txt")
  
  df
  
}
