library(utils)

read.dir <- function(dirpath,label) {
  read.ratio <- function(X) {
    tab <- read.delim(file=X,header=T,as.is=T,check.names=F,colClasses=c('character'))
    tab[['DATASET']] <- rep(label,nrow(tab));
    tab[['SAMPLE']] <- rep(basename(X),nrow(tab))
    tab
  }
  directories <- dir(path = dirpath,pattern='*.strvar',full.names = T)
  files <- dir(path = directories,pattern='*.gz_ratio.txt',full.names=T)
  lapply(files,read.ratio)
}

dfci <- read.dir(dirpath = '/mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/DFCI/controlFreec.human_1469503404',label = 'DFCI')
mmrf <- read.dir(dirpath = '/mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/MMRF/controlFreec.human_1469724160',label = 'MMRF')
uams <- read.dir(dirpath = '/mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/UAMS/controlFreec.human_1469503981',label = 'UAMS')

out <- do.call(rbind,list(dfci,mmrf,uams))
write.csv(out,file='/mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/controlFreeq_combined_dfci_mmrf_uams.csv',row.names=F)
