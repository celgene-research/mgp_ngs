library(utils)
getFile <- function(path.on.s3) {
  system(paste('aws s3 cp',path.on.s3,file.path('/tmp',basename(path.on.s3))))
  return(file.path('/tmp',basename(path.on.s3)))
}

putFile <- function(file,path.on.s3) {
  system(paste('aws s3 cp',file,paste(path.on.s3,basename(file),sep='/')))
}

tmp.path.per.file <- getFile('s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/Integrated/INTEGRATED-PER-FILE_2016-10-27.txt')
tmp.path.per.sample <- getFile('s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/Integrated/INTEGRATED-PER-SAMPLE_2016-10-27.txt')
per.file <- read.delim(file=tmp.path.per.file,header=T,as.is=T,check.names=F,sep='\t',colClasses=c('character'))
per.sample <- read.delim(file=tmp.path.per.sample,header=T,as.is=T,check.names=F,sep='\t',colClasses=c('character'))
unlink(tmp.path.per.file)
unlink(tmp.path.per.sample)

merged <- merge(x=per.file,y=per.sample,by='Sample_Name',all=T)
if(dim(merged)[1] != dim(per.file)[1]) {
  warning('dimentions do not match between the merged table and file table...')
}
write.table(merged,file='/tmp/INTEGRATED-PER-FILE_PER-SAMPLE_2016-10-27.txt',row.names = F,sep='\t')
putFile(file='/tmp/INTEGRATED-PER-FILE_PER-SAMPLE_2016-10-27.txt','s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/Integrated')
unlink('/tmp/INTEGRATED-PER-FILE_PER-SAMPLE_2016-10-27.txt')