library(utils)
getFile <- function(path.on.s3) {
  system(paste('aws s3 cp',path.on.s3,file.path('/tmp',basename(path.on.s3))))
  return(file.path('/tmp',basename(path.on.s3)))
}

putFile <- function(file,path.on.s3) {
  system(paste('aws s3 cp --sse AES256',file,paste(path.on.s3,basename(file),sep='/')))
}

# fetch today's timestamped version
d <- format(Sys.Date(), "%Y-%m-%d")

tmp.path.per.file <- getFile(paste0('s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/Integrated/INTEGRATED-PER-FILE_',d,'.txt'))
tmp.path.per.sample <- getFile(paste0('s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/Integrated/INTEGRATED-PER-SAMPLE_',d,'.txt'))
per.file <- read.delim(file=tmp.path.per.file,header=T,as.is=T,check.names=F,sep='\t',colClasses=c('character'))
per.sample <- read.delim(file=tmp.path.per.sample,header=T,as.is=T,check.names=F,sep='\t',colClasses=c('character'))
unlink(tmp.path.per.file)
unlink(tmp.path.per.sample)

merged <- merge(x=per.file,y=per.sample,by='Sample_Name',all=T)
if(dim(merged)[1] != dim(per.file)[1]) {
  warning('dimentions do not match between the merged table and file table...')
}
write.table(merged,file=paste0('/tmp/INTEGRATED-PER-FILE_PER-SAMPLE_',d,'.txt'),row.names = F,sep='\t')
putFile(file=paste0('/tmp/INTEGRATED-PER-FILE_PER-SAMPLE_',d,'.txt'),'s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/Integrated')
unlink(paste0('/tmp/INTEGRATED-PER-FILE_PER-SAMPLE_',d,'.txt'))
