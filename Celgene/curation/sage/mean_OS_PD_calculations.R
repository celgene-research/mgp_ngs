# calcualte mean OS and PD at 12/18/24/36 mo

source("curation_scripts.R")
local      <- "/tmp/curation"
if(!dir.exists(local)){
  dir.create(local)
} else {
  system(paste0("rm -r ", local))
  dir.create(local)
}
system(paste( "aws s3 cp",
              file.path("s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/Integrated/PER-PATIENT_nd_tumor_clinical.txt"),
              file.path(local, "PER-PATIENT_nd_tumor_clinical.txt"),
              "--sse", sep = " "), intern = T)
perpatient.nd.tumor <- read.delim(file.path(local,"PER-PATIENT_nd_tumor_clinical.txt"), sep = "\t")

# MMRF ia8b survival data ------------------------------------------------
system(paste( "aws s3 cp",
              file.path("s3://celgene.rnd.combio.mmgp.external/ClinicalData/OriginalData/MMRF_IA8b/STAND_ALONE_SURVIVAL.csv"),
              file.path(local, "STAND_ALONE_SURVIVAL.csv"),
              "--sse", sep = " "), intern = T)
survival <- read.csv(file.path(local,"STAND_ALONE_SURVIVAL.csv"), stringsAsFactors = F)
df <- survival[,c("public_id", "ttos",  "ttfpd")]
df[['study']] <- "mmrf"


system(paste( "aws s3 cp",
              file.path("s3://celgene.rnd.combio.mmgp.external/ClinicalData/OriginalData/MMRF_IA8b/PER_PATIENT.csv"),
              file.path(local, "PER_PATIENT.csv"),
              "--sse", sep = " "), intern = T)
perpatient <- read.csv(file.path(local,"PER_PATIENT.csv"), stringsAsFactors = F)

lookup_by_PUBLIC_ID <- lookup.values("PUBLIC_ID")
df[['D_PT_CAUSEOFDEATH']] <- unlist(lapply(df$public_id, lookup_by_PUBLIC_ID, dat = perpatient, field = "D_PT_CAUSEOFDEATH"))

# if patient died from "Disease Progression" without a ttfpd value, use their ttos
df <- plyr::ddply(df, 1, function(x){
  if( !is.na( x$ttfpd) ){
    pd <- x$ttfpd
  }else if( x$D_PT_CAUSEOFDEATH == "Disease Progression" & !is.na( x$ttos )  ){
    pd <- x$ttos
  }else{
    pd <- NA}
  data.frame(x,
             ttpd.os = pd)
})

df[['ttos.m']] <- df$ttos / 365.25 * 12
df[['ttpd.m']] <- df$ttpd.os / 365.25 * 12

df[['os.flag.12mo']] <- ifelse( df$ttos.m <= 12 & !is.na(df$ttos.m) ,1,0  )
df[['os.flag.18mo']] <- ifelse( df$ttos.m <= 18 & !is.na(df$ttos.m) ,1,0  )
df[['os.flag.24mo']] <- ifelse( df$ttos.m <= 24 & !is.na(df$ttos.m) ,1,0  )
df[['os.flag.30mo']] <- ifelse( df$ttos.m <= 30 & !is.na(df$ttos.m) ,1,0  )
df[['os.flag.36mo']] <- ifelse( df$ttos.m <= 36 & !is.na(df$ttos.m) ,1,0  )

df[['pd.flag.12mo']] <- ifelse( df$ttpd.m <= 12 & !is.na(df$ttpd.m) ,1,0  )
df[['pd.flag.18mo']] <- ifelse( df$ttpd.m <= 18 & !is.na(df$ttpd.m) ,1,0  )
df[['pd.flag.24mo']] <- ifelse( df$ttpd.m <= 24 & !is.na(df$ttpd.m) ,1,0  )
df[['pd.flag.30mo']] <- ifelse( df$ttpd.m <= 30 & !is.na(df$ttpd.m) ,1,0  )
df[['pd.flag.36mo']] <- ifelse( df$ttpd.m <= 36 & !is.na(df$ttpd.m) ,1,0  )

# UAMS curated clinical data ------------------------------------------------
system(paste( "aws s3 cp",
              file.path("s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/UAMS/curated_sheet2_UAMS_UK_sample_info.txt"),
              file.path(local, "uams.txt"),
              "--sse", sep = " "), intern = T)

uams <- read.delim(file.path(local, "uams.txt"), sep = "\t", stringsAsFactors = F)
uams <- uams[,c("Patient", "PFS_months",  "OS_months")]

names(uams) <- c("public_id", "ttos.m", "ttpd.m")

uams[['study']] <- "uams"
uams[['os.flag.12mo']] <- ifelse( uams$ttos.m <= 12 & !is.na(uams$ttos.m) ,1,0  )
uams[['os.flag.18mo']] <- ifelse( uams$ttos.m <= 18 & !is.na(uams$ttos.m) ,1,0  )
uams[['os.flag.24mo']] <- ifelse( uams$ttos.m <= 24 & !is.na(uams$ttos.m) ,1,0  )
uams[['os.flag.30mo']] <- ifelse( uams$ttos.m <= 30 & !is.na(uams$ttos.m) ,1,0  )
uams[['os.flag.36mo']] <- ifelse( uams$ttos.m <= 36 & !is.na(uams$ttos.m) ,1,0  )

uams[['pd.flag.12mo']] <- ifelse( uams$ttpd.m <= 12 & !is.na(uams$ttpd.m) ,1,0  )
uams[['pd.flag.18mo']] <- ifelse( uams$ttpd.m <= 18 & !is.na(uams$ttpd.m) ,1,0  )
uams[['pd.flag.24mo']] <- ifelse( uams$ttpd.m <= 24 & !is.na(uams$ttpd.m) ,1,0  )
uams[['pd.flag.30mo']] <- ifelse( uams$ttpd.m <= 30 & !is.na(uams$ttpd.m) ,1,0  )
uams[['pd.flag.36mo']] <- ifelse( uams$ttpd.m <= 36 & !is.na(uams$ttpd.m) ,1,0  )

df <- rbind(df[,names(df) %in% names(uams) ], uams)

# only keep patients with ND tumor samples.
df <- df[(df$public_id %in% perpatient.nd.tumor$Patient),]


stats <- aggregate.data.frame(df[5:ncol(df)], by = list(df$study), mean)
stats.combo <- aggregate.data.frame(df[5:ncol(df)], by = list(rep("all", times = nrow(df))), mean)

stats <- rbind(stats, stats.combo)

stats <- reshape2::melt(stats, id = "Group.1")
names(stats)[1] <- "study"
stats[['time']]      <- gsub(".*\\.(\\d+)mo", "\\1", stats$variable)
stats[['parameter']] <- gsub("^(.{2}).*", "\\1", stats$variable)

# plotting -------------------------------------------------------------------------
library(ggplot2)

# png("~/thindrives/drozelle/Downloads/plot.png")
ggplot(stats, aes(x = as.numeric(stats$time), 
                  y = stats$value, 
                  color = as.factor(stats$parameter), 
                  shape = as.factor(stats$study)) ) +
  geom_point(size = 4)+
  geom_line()+
  #                              green      orange
  scale_colour_manual(values = c("#94C600","#FF6700"))+
  labs(title = 'Progression/Survival ratio from New Diagnosis MM patients',
       y = "Mean patient proportion",
       x = "Time (Months)",
       color = "Parameter" ,
       shape = "Study") +
  
  scale_x_continuous(limits = c(10,40),
                     breaks = seq(12,36, 12)    )+
  
  theme(
    # aspect.ratio = .4,
    text = element_text(family = "Arial",
                        size   = 12)
    ,line = element_line(size = 0.5)
    ,plot.title = element_text(size = rel(1.2),
                               face = "italic",
                               angle = 0,
                               margin = margin(20,0,15,0),
                               lineheight = 1.0)
    ,legend.title = element_text(size = rel(0.8))
    ,legend.key = element_rect(fill=NA,color = NA)
    ,legend.position = "right"  # none, left, top, right, bottom, c(.9, .5)
    ,legend.background = element_blank()
    
    ,axis.title = element_text(size = rel(0.9))
    # ,axis.title.y  = element_blank()
    ,axis.ticks = element_line(size = 0.5)
    ,axis.ticks.length = unit(5, "pt")
    ,axis.line = element_line(size = 0.5,
                              color = "black",
                              linetype = "solid")
    ,axis.line.x  = element_line()
    ,axis.line.y  = element_line()
    ,panel.background = element_rect(fill = NA)
    ,plot.margin = unit(c(0.2, 0.4, 0.8, 0.8), "cm") #top, right, bottom, left
  )
# dev.off()