source("curation_scripts.R")

### joining together all the MMRF variables related to OS and PFS in order to select the most appropriate.
 
p <- GetS3Table(s3.path = file.path(s3, "ClinicalData/OriginalData/MMRF_IA9/PER_PATIENT.csv")) %>%
  select(PUBLIC_ID, D_PT_CAUSEOFDEATH, D_PT_pddy, D_PT_pdflag, D_PT_ttfpdw)
s <- GetS3Table(s3.path = file.path(s3, "ClinicalData/OriginalData/MMRF_IA9/STAND_ALONE_SURVIVAL.csv")) %>%
  select(public_id, pdflag, censpfs,  ttpfs, ttpfs1,ttpfs2, ttfpd, pfscdy, ttcpfs, ttos, censos, oscdy, ttcos, ttos, deathdy, vis6mo, vis12mo)

df <- merge(p,s, by.x = "PUBLIC_ID", by.y = "public_id")

### selections for use in integrated dataset
#   df[['D_OS']]       <- unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "ttcos"))
# df[['D_OS_FLAG']]  <- unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "censos"))
# df[['D_PFS']]      <- unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "ttcpfs"))
# df[['D_PFS_FLAG']] <- unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "censpfs"))
# df[['D_PD']]       <- unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "ttfpd"))
# df[['D_PD_FLAG']]  <- unlist(lapply(df$Patient, lookup_by_publicid, dat = survival, field = "pdflag"))