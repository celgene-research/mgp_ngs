library(utils)

read.dir <- function(dirpath,label,output) {
  read.ratio <- function(X,output) {
    tab <- read.delim(file=X,header=T,as.is=T,check.names=F,colClasses=c('character'))
    tab[['DATASET']] <- rep(label,nrow(tab));
    tab[['SAMPLE']] <- rep(basename(X),nrow(tab))
    write.table(tab,row.names=F,append = T,col.names=F,sep=',')
  }
  directories <- dir(path = dirpath,pattern='*.strvar',full.names = T)[1]
  files <- dir(path = directories,pattern='*.gz_ratio.txt',full.names=T)
  lapply(files,read.ratio,output=output)
}

writeHeader <- function(dir,output) {
  directories <- dir(path = dirpath,pattern='*.strvar',full.names = T)
  files <- dir(path = directories,pattern='*.gz_ratio.txt',full.names=T)
  template <- files[1];
  tab <- read.delim(file=template,header=T,as.is=T,check.names=F,colClasses=c('character'))
  tab[['DATASET']] <- rep('DATASET',nrow(tab));
  tab[['SAMPLE']] <- rep('SAMPLE',nrow(tab))
  write.table(t(colnames(tab)),file='/home/ftowfic/test.csv',row.names=F,col.names =F,sep=',')
}

output <- '/mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/controlFreeq_combined_dfci_mmrf_uams.csv';
writeHeader(dirpath = '/mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/DFCI/controlFreec.human_1469503404',output)
dfci <- read.dir(dirpath = '/mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/DFCI/controlFreec.human_1469503404',label = 'DFCI',output = output)
mmrf <- read.dir(dirpath = '/mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/MMRF/controlFreec.human_1469724160',label = 'MMRF',output=output)
uams <- read.dir(dirpath = '/mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/UAMS/controlFreec.human_1469503981',label = 'UAMS',output=output)
