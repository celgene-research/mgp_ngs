# results of this troubleshooting were incorporated into <curate_MMRF_IA9.R> 
#  script to capture MMRF WGS files in S3. 

s3 <- "s3://celgene.rnd.combio.mmgp.external"

local      <- "/tmp/curation"
if(!dir.exists(local)){
  dir.create(local)
} else {
  system(paste0("rm -r ", local))
  dir.create(local)
}

wgs.mmrf <- system(paste('aws s3 ls', 
             's3://celgene.rnd.combio.mmgp.external/SeqData/WGS/OriginalData/MMRF/',
             '--recursive |',
             'grep "1.fastq.gz$" | sed "s/.*SeqData/SeqData/"',
             sep = " "), intern = T)

name <- "data.import.WGS.Kostas.IA3-IA7.xls"
system(paste("aws s3 cp",
             file.path(s3, "SeqData/WGS/OriginalData/MMRF", name),
             file.path(local, name),
             sep = " "))
kostas.import <- read.delim(file.path(local, name))
kostas.import[['srr.prefix']] <- gsub(".*(SRR\\d+).*", "\\1", kostas.import$filename)

sra <- read.delim("~/thindrives/mgp/data/SraRunTable_SRP047533.txt")
wgs.mmrf <- system(paste("aws s3 ls",
                         file.path(s3, "SeqData/WGS/OriginalData/MMRF/IA8/"),
                         "--recursive",
                         sep = " "), intern = T)

files <- data.frame(SRR = gsub(".*SeqData.*(SRR\\d+)_\\d.*", "\\1", wgs.mmrf.ia8.fastq),
                    basename = gsub(".*SeqData.*(SRR\\d+_\\d.*)", "\\1", wgs.mmrf.ia8.fastq),
                    filepath = gsub(".*(SeqData.*SRR\\d+_\\d.*)", "\\1", wgs.mmrf.ia8.fastq),
                    stringsAsFactors = F)

df <- files[duplicated(files$SRR),"SRR"]

lookup <- sra[sra$Run_s %in% df, c("submitted_subject_id_s", "Run_s", "Sample_Name_s")]


