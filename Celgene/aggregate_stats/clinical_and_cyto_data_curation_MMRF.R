# Dan Rozelle
# Sep 19, 2016

# MMRF IA8 integrated curation 
#   MMRF_patient_clinical_(date).txt
#   MMRF_patient_cytogenetic_(date).txt
#   MMRF_patient_inventory_(date).txt

d <- format(Sys.Date(), "%Y-%m-%d")
study <- "MMRF"

# generic curation functions
lookup_by_publicid <- toolboxR::lookup.values(c("PUBLIC_ID"))
lookup_by_sampleid <- toolboxR::lookup.values(c("SPECTRUM_SEQ"))
check_by_publicid <- toolboxR::check.value(c("PUBLIC_ID"))


########## import raw tables and reformat as required
# Our master patient list is generated from several sources to prevent missing data. 
# SAMPLE-level manifest of IA8b sequencing files.
mmrf.seqqc    <- read.delim(file = "../data/mmrf/IA8b_README/MMRF_CoMMpass_IA8b_Seq_QC_Summary.txt", 
                            stringsAsFactors = F)
# IA8 PER_PATIENT dataset
mmrf.PER_PATIENT <- read.csv(file = "../data/mmrf/CoMMpass_IA8_FlatFiles_v3/PER_PATIENT.csv", stringsAsFactors = F)
## Cytogenetic analysis table
mmrf.cyto     <- read.delim("../data/mmrf/CoMMpass_IA8_FlatFiles_v3/MMRF_cytodata-orig-aligned.txt", 
                            stringsAsFactors = F)

# cytogenetic analysis based on sequencing tools, aggregated and summarised by Brian Walker @ UAMS
mmrf.cyto2 <- toolboxR::autoread("../data/original_tables/All_translocation_Summaries_from_BWalker_2016-10-04.xlsx", sheet = "MMRF")
  
  
# actual S3 inventory
# system('aws s3 --profile mmgp ls s3://celgene.rnd.combio.mmgp.external/SeqData/ --recursive >../data/all_S3_SeqData')


patient_sources <- list(mmrf.seqqc$Patients..KBase_Patient_ID, mmrf.PER_PATIENT$PUBLIC_ID, mmrf.cyto$PUBLIC_ID)
p <- unique(unlist(patient_sources))
p <- p[order(p)]


# collapse multiple columns of race info into a single delimited string
tmp <- mmrf.PER_PATIENT[,c("D_PT_race", "DEMOG_AMERICANINDIA", "DEMOG_ASIAN", "DEMOG_BLACKORAFRICA", "DEMOG_WHITE", "DEMOG_OTHER")]
decoded_matrix <- data.frame(
  gsub("Checked", "AMERICANINDIAN", tmp$DEMOG_AMERICANINDIA),
  gsub("Checked", "ASIAN", tmp$DEMOG_ASIAN),
  gsub("Checked", "BLACKORAFRICAN", tmp$DEMOG_BLACKORAFRICA),
  gsub("Checked", "WHITE", tmp$DEMOG_WHITE),
  gsub("Checked", "OTHER", tmp$DEMOG_OTHER)
)
mmrf.PER_PATIENT[['RACE']] <- apply(decoded_matrix, MARGIN = 1, function(x){
  x <- x[x != ""]
  paste(x, collapse = "; ")
})
rm(decoded_matrix, tmp)
## Visit table
mmrf.visit <- read.csv(file = "../data/mmrf/CoMMpass_IA8_FlatFiles_v3/PER_PATIENT_VISIT.csv", 
                       stringsAsFactors = F, na.strings = c("Unknown"))
## Medical history table
mmrf.medhx <- read.csv(file = "../data/mmrf/CoMMpass_IA8_FlatFiles_v3/STAND_ALONE_MEDHX.csv", 
                       stringsAsFactors = F, na.strings = c("Unk"))
names(mmrf.medhx) <- gsub("public_id", "PUBLIC_ID", names(mmrf.medhx))

## Family history table
mmrf.famhx <- read.csv(file = "../data/mmrf/CoMMpass_IA8_FlatFiles_v3/STAND_ALONE_FAMHX.csv", 
                       stringsAsFactors = F, na.strings = c("Unk"))
names(mmrf.famhx) <- gsub("public_id", "PUBLIC_ID", names(mmrf.famhx))

## Survival table
mmrf.survival <- read.csv(file = "../data/mmrf/CoMMpass_IA8_FlatFiles_v3/STAND_ALONE_SURVIVAL.csv", 
                       stringsAsFactors = F, na.strings = c("Unk"))
names(mmrf.survival) <- gsub("public_id", "PUBLIC_ID", names(mmrf.survival))

## Response table
mmrf.resp <- read.csv(file = "../data/mmrf/CoMMpass_IA8_FlatFiles_v3/STAND_ALONE_TRTRESP.csv", 
                          stringsAsFactors = F, na.strings = c("Unk"))
names(mmrf.resp) <- gsub("public_id", "PUBLIC_ID", names(mmrf.resp))




###################################################
# Generate a patient-level clinical data table
#  Designated fields are defined in integrated_columns.xlsx file.
#
# While ALL paitents are retained in this table, patients that have at least 
#  2 years progression-free outcome data or a clinically relevant event 
#  (death/progression) are flagged for easy filtering.  

# Clinical columns we want to populate
meta <- XLConnect::readWorksheetFromFile("../data/integrated_columns.xlsx", sheet = 1, startRow =2)

# Generate a blank table
mmrf.clinical <- data.frame(Patient  = p,
                            Study   = "MMRF",
                   stringsAsFactors = F)
mmrf.clinical[meta[((meta$category %in% c("demographic", "treatment", "response", "blood", "flow", "misc")) & meta$active), "names"]] <- NA

# filter for patients that have a baseline visit with a sample collection
patients <- unique(mmrf.visit[mmrf.visit$VJ_INTERVAL    == "Baseline" & 
                                mmrf.visit$SPECTRUM_SEQ != "", "PUBLIC_ID"])

mmrf.clinical[["D_Gender"]] <- unlist(lapply(mmrf.clinical$Patient, lookup_by_publicid, dat = mmrf.PER_PATIENT, field = "DEMOG_GENDER"))
mmrf.clinical[["D_Race"]]   <- unlist(lapply(mmrf.clinical$Patient, lookup_by_publicid, dat = mmrf.PER_PATIENT, field = "RACE"))
mmrf.clinical[["D_Age"]]    <- unlist(lapply(mmrf.clinical$Patient, lookup_by_publicid, dat = mmrf.PER_PATIENT, field = "D_PT_age"))
mmrf.clinical[["D_Medical_History"]]    <- unlist(lapply(mmrf.clinical$Patient, lookup_by_publicid, dat = mmrf.medhx, field = "medx"))
mmrf.clinical[["D_Family_Cancer_History"]]    <- unlist(lapply(mmrf.clinical$Patient, lookup_by_publicid, dat = mmrf.famhx, field = "FAMHX_ISTHEREAFAMIL"))
mmrf.clinical[["D_ISS"]] <- unlist(lapply(mmrf.clinical$Patient, lookup_by_publicid, dat = mmrf.PER_PATIENT, field = "D_PT_iss"))


## Use the integrated_columns metadata to automatically fetch baseline values for each PER_PATIENT_VISIT value.
# Subset the table to include only values derived from the PER_PATIENT_VISIT MMRF table
visit_fields <- meta[((meta$mmrf_table == "PER_PATIENT_VISIT") & !(is.na(meta$mmrf_table))),c("names", "mmrf_column")]

# Subset the PER_PATIENT_VISIT table to only include "Baseline" visits
mmrf.visit.baseline <- mmrf.visit[mmrf.visit$VJ_INTERVAL == "Baseline",]
# 
tmp <- lapply(visit_fields$mmrf_column, function(x){
  unlist(lapply(mmrf.clinical$Patient, lookup_by_publicid, dat = mmrf.visit.baseline, field = x))
})
names(tmp) <- visit_fields$names

for(i in visit_fields$names){
  mmrf.clinical[[i]] <- tmp[[i]]
}
rm(tmp)

# Parse Medical history into boolean columns
medhx_cats <- scan("../data/other/MEDHX_conditions.of.interest.txt", what = character(), sep = "\n")
for(i in medhx_cats){
  n <- paste("Has","medhx",gsub("[\\/\\(\\)\\ ]+","_",i), sep = ".")
  mmrf.clinical[[n]] <- ifelse(grepl(i, mmrf.clinical$D_Medical_History, fixed = T),1,0)
}

# Calculate Overall Survival time. This is the reported ttos for deceased patients or 
#  time to last contact for those who are still living. Last contact is the max value from
#  PER_PATIENT.D_PT_lstalive, PER_PATIENT.lvisit, or mmrf.survival.oscdy fields. 
#  NA for any negative values. We need a lookup table to make these calculations.

df <- data.frame(Patient = mmrf.clinical$Patient,
                 stringsAsFactors = F)
df[['ttos']] <- as.integer(unlist(lapply(df$Patient, lookup_by_publicid, dat = mmrf.survival, field = "ttos")))
df[['D_PT_ic_day']] <- as.integer(unlist(lapply(df$Patient, lookup_by_publicid, dat = mmrf.PER_PATIENT, field = "D_PT_ic_day")))
df[['D_PT_lstalive']] <- as.integer(unlist(lapply(df$Patient, lookup_by_publicid, dat = mmrf.PER_PATIENT, field = "D_PT_lstalive")))
df[['D_PT_lvisitdy']] <- as.integer(unlist(lapply(df$Patient, lookup_by_publicid, dat = mmrf.PER_PATIENT, field = "D_PT_lvisitdy")))
df[['oscdy']] <- as.integer(unlist(lapply(df$Patient, lookup_by_publicid, dat = mmrf.survival, field = "oscdy")))
df[['ttfpd']] <- as.numeric(unlist(lapply(mmrf.clinical$Patient, lookup_by_publicid, dat = mmrf.survival, field = "ttfpd")))

df[['os']] <- as.integer(unlist(apply(df, MARGIN = 1, function(x){
  if(!is.na(x['ttos'])){return(x['ttos'])
  }else if(any(!(is.na(x['D_PT_lstalive'])), !(is.na(x['D_PT_lvisitdy'])), !(is.na(x['oscdy'])))){
    bar <- max(
      suppressWarnings(as.numeric(x['D_PT_lstalive'])), 
      suppressWarnings(as.numeric(x['D_PT_lvisitdy'])), 
      suppressWarnings(as.numeric(x['oscdy'])), 
      na.rm = T)
    if(bar < 0 ){return(NA)
    }else{return(bar)}
  }else{return(NA)}
})))
lookup_by_patient <- toolboxR::lookup.values("Patient")
mmrf.clinical[["D_OS"]] <- as.numeric(unlist(lapply(mmrf.clinical$Patient, lookup_by_patient, dat = df, field = "os")))
rm(df)  
# turns out "death day" is a more consistent field than the D_PT_DISCREAS flag, 
# which was missing for a few patients that had a death date. Flag the patient
#  if they are deceased; 0=no (deathdy == NA); 1=yes (deathdy != NA)		  
mmrf.clinical[["D_OS_FLAG"]] <- ifelse( is.na( unlist(lapply(mmrf.clinical$Patient, lookup_by_publicid, dat = mmrf.survival, field = "deathdy"))),0,1)

# Progression Free time: time to progression for those who progressed; (ttfpd =	Time to first PD)
#  time to last contact for those who still have not progressed (mmrf.PER_PATIENT$D_PT_lvisitdy)
progression_matrix <- data.frame(
observed.pd = as.numeric(unlist(lapply(mmrf.clinical$Patient, lookup_by_publicid, dat = mmrf.survival, field = "ttfpd"))),
last.alive  = as.numeric(unlist(lapply(mmrf.clinical$Patient, lookup_by_publicid, dat = mmrf.survival, field = "lstalive"))),
last.visit  = as.numeric(unlist(lapply(mmrf.clinical$Patient, lookup_by_publicid, dat = mmrf.survival, field = "lvisitdy")))
)

mmrf.clinical[["D_PFS"]] <- apply(progression_matrix, MARGIN = 1, function(x){
  foo <- c( x[[2]], x[[3]])
  # if there is an observed progression, report it
  if( !is.na(x[[1]]) ){
    return(x[[1]])
    
    #else if there is a last visit or last alive day, use the larger
  } else if( any(!is.na(foo)) ){
    foo <- foo[!is.na(foo)]
    m <- max(foo)
    if( m < 0 ){m <- NA}
    
    return(m)  

    } else{return(NA)}
})

# has the patient developed progressive disease (1) or not (0)
mmrf.clinical[["D_PFS_FLAG"]] <- ifelse(!is.na(  unlist(lapply(mmrf.clinical$Patient, lookup_by_publicid, dat = mmrf.survival, field = "ttfpd"))  ) ,1,0)
mmrf.clinical[["D_Cause_of_Death"]] <-  unlist(lapply(mmrf.clinical$Patient, lookup_by_publicid, dat = mmrf.PER_PATIENT, field = "D_PT_CAUSEOFDEATH"))
mmrf.clinical[["D_Reason_for_Discontinuation"]] <-  unlist(lapply(mmrf.clinical$Patient, lookup_by_publicid, dat = mmrf.PER_PATIENT, field = "D_PT_PRIMARYREASON"))
mmrf.clinical[["D_Discontinued"]] <-  unlist(lapply(mmrf.clinical$Patient, lookup_by_publicid, dat = mmrf.PER_PATIENT, field = "D_PT_discont"))
mmrf.clinical[["D_Complete"]] <-  unlist(lapply(mmrf.clinical$Patient, lookup_by_publicid, dat = mmrf.PER_PATIENT, field = "D_PT_complete"))
mmrf.clinical[["D_Best_Response_Code"]] <-  unlist(lapply(mmrf.clinical$Patient, lookup_by_publicid, dat = mmrf.resp, field = "bestrespcd"))
mmrf.clinical[["D_Best_Response"]] <-  unlist(lapply(mmrf.clinical$Patient, lookup_by_publicid, dat = mmrf.resp, field = "bestresp"))


# fix a few formatting issues
mmrf.clinical[["FLO_IgL"]] <- toupper(mmrf.clinical[["FLO_IgL"]])
mmrf.clinical[['MISC_BRAF_V600E']] <- gsub("99", NA, mmrf.clinical[['MISC_BRAF_V600E']])

write.table(mmrf.clinical, paste0("../data/curated/",study,"/",study,"_patient_clinical_", d,".txt"), row.names = F, col.names = T, sep = "\t", quote = F)

nrow(mmrf.clinical)
# 913
length(unique(mmrf.clinical$Patient))
# 913

# additional columns added to just MMRF dataset, not currently merged into integrated dataset

############ Cytogenetic curation

mmrf.cytogenetic <- data.frame(Patient = mmrf.clinical$Patient,
                                Study   = "MMRF",
                                stringsAsFactors = F)
mmrf.cytogenetic[meta[((meta$category %in% c("cytogenetic")) & meta$active), "names"]] <- NA

# cytogenetic analysis was not uniformly applied at a specific visit, 
#  so we need to search within across a patient's longitudinal visit records
visit_with_cytoanalysis <- function(id, dat){
  # filter for one patient
  tmp <- mmrf.cyto[ (mmrf.cyto$PUBLIC_ID == id) & (mmrf.cyto$VISIT >= 0), 
                   c("PUBLIC_ID", "VISIT", "VJ_INTERVAL", "D_CM_WASCONVENTION", "D_CM_KARYOTYPE")]
  # sort by visit number
  tmp <- tmp[order(tmp$VISIT),]
  # filter for "D_CM_WASCONVENTION" == "Yes" and select the top result
  tmp <- tmp[tmp$D_CM_WASCONVENTION == "Yes",]
  if(nrow(tmp) > 0) {return(tmp[1,"VJ_INTERVAL"])
  } else return(NA)
}

mmrf.cytogenetic[['Has.Cytogenetic.Data']] <- ifelse(!is.na(sapply(mmrf.cytogenetic$Patient, visit_with_cytoanalysis, mmrf.cyto)),1,0)
mmrf.cytogenetic[['Visit']] <- sapply(mmrf.cytogenetic$Patient, visit_with_cytoanalysis, mmrf.cyto)

# now that we have a "Visit" row specified to find the best cytogenetic info
#  we can use it to populate specific analysis result details
lookup_by_id_and_visit <- toolboxR::lookup.values(c("PUBLIC_ID", "VJ_INTERVAL"))
check_by_id_and_visit  <- toolboxR::check.value(c("PUBLIC_ID", "VJ_INTERVAL"))

# add description of karyotype
mmrf.cytogenetic[["Karyotype"]] <- unlist(mapply(lookup_by_id_and_visit, mmrf.cytogenetic$Patient, mmrf.cytogenetic$Visit, 
                                     MoreArgs = list(dat = mmrf.cyto, field = "D_CM_KARYOTYPE"), SIMPLIFY = F))

# check values function is acting weird, check before repeating these lines
score_cytogenetics <- function(column_name){
  ifelse(mapply(check_by_id_and_visit, mmrf.cytogenetic$Patient, mmrf.cytogenetic$Visit,
                MoreArgs = list(dat = mmrf.cyto, field = column_name, value = "Yes")), 1,0)
}


# check_by_id_and_visit("MMRF_1107", "Baseline", dat = mmrf.cyto, field = "D_TRI_CF_ABNORMALITYPR", value = "Yes")

mmrf.cytogenetic[['del(13)']] <- score_cytogenetics("D_TRI_CF_ABNORMALITYPR")
mmrf.cytogenetic[['del(17)']] <- score_cytogenetics("D_TRI_CF_ABNORMALITYPR2")
mmrf.cytogenetic[['t(4;14)']] <- score_cytogenetics("D_TRI_CF_ABNORMALITYPR3")
mmrf.cytogenetic[['t(6;14)']] <- score_cytogenetics("D_TRI_CF_ABNORMALITYPR4")
mmrf.cytogenetic[['t(8;14)']] <- score_cytogenetics("D_TRI_CF_ABNORMALITYPR5")
mmrf.cytogenetic[['t(11;14)']] <- score_cytogenetics("D_TRI_CF_ABNORMALITYPR6")
mmrf.cytogenetic[['t(12;14)']] <- score_cytogenetics("D_TRI_CF_ABNORMALITYPR7")
mmrf.cytogenetic[['t(14;16)']] <- score_cytogenetics("D_TRI_CF_ABNORMALITYPR8")
mmrf.cytogenetic[['t(14;20)']] <- score_cytogenetics("D_TRI_CF_ABNORMALITYPR9")
mmrf.cytogenetic[['del(1p)']] <- score_cytogenetics("D_TRI_CF_ABNORMALITYPR12")
mmrf.cytogenetic[['del(1q)']] <- score_cytogenetics("D_TRI_CF_ABNORMALITYPR13")


h1 <- ifelse(mapply(check_by_id_and_visit, mmrf.cytogenetic$Patient, mmrf.cytogenetic$Visit, 
                    MoreArgs = list(dat = mmrf.cyto, field = "D_CM_ANEUPLOIDYCAT", value = "Hyper")), 1,0)
h2 <- ifelse(mapply(check_by_id_and_visit, mmrf.cytogenetic$Patient, mmrf.cytogenetic$Visit, 
                    MoreArgs = list(dat = mmrf.cyto, field = "D_TRI_trisomies", value = ".+")), 1,0)
mmrf.cytogenetic[['Hyperdiploid']] <- ifelse(Reduce("|", list(h1,h2)), 1, 0)

write.table(mmrf.cytogenetic, paste0("../data/curated/",study,"/",study ,"_patient_cytogenetic_", d,".txt"), row.names = F, col.names = T, sep = "\t", quote = F)

rm(tmp, p, n, h1, h2, i, mmrf.visit.baseline, visit_fields)
