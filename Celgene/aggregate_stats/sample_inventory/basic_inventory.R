library(VennDiagram)

read.data <- function() {
  qcRNA <- read.csv(file='~/data/qcRNA.csv',colClasses=c('character'))
  qcRNA[['STUDY']] <- rep('MMRF',nrow(qcRNA))
  qcRNA[['UNIQUE.ID']] <- paste(qcRNA[['STUDY']],qcRNA[['celgene_id']],sep='_')
  qcWES <- read.csv(file='~/data/qcWES.csv',colClasses=c('character'))
  
  dfci.list <- system('aws s3 ls celgene.rnd.combio.mmgp.external/SeqData/WES/OriginalData/DFCI/',intern=T)
  dfci.list <- dfci.list[grepl(pattern = '_PD\\d+',dfci.list)]
  dfci.list <- unique(gsub(pattern = '.*(PD\\d+).*','\\1',dfci.list))
  
  mmrf.list <- c(
    system('aws s3 ls celgene.rnd.combio.mmgp.external/SeqData/WES/OriginalData/MMRF/IA3/',intern=T),
    system('aws s3 ls celgene.rnd.combio.mmgp.external/SeqData/WES/OriginalData/MMRF/IA4/',intern=T),
    system('aws s3 ls celgene.rnd.combio.mmgp.external/SeqData/WES/OriginalData/MMRF/IA5/',intern=T),
    system('aws s3 ls celgene.rnd.combio.mmgp.external/SeqData/WES/OriginalData/MMRF/IA6/',intern=T),
    system('aws s3 ls celgene.rnd.combio.mmgp.external/SeqData/WES/OriginalData/MMRF/IA7/',intern=T),
    system('aws s3 ls celgene.rnd.combio.mmgp.external/SeqData/WES/OriginalData/MMRF/IA8/',intern=T)
  )
  mmrf.list <- mmrf.list[grepl(pattern = 'MMRF_\\d+',mmrf.list)]
  mmrf.list <- unique(gsub(pattern = '.*MMRF_(\\d+).*','\\1',mmrf.list))
  
  uams.list <- c(system('aws s3 ls celgene.rnd.combio.mmgp.external/SeqData/WES/OriginalData/UAMS/',intern=T))
  uams.list <- uams.list[grepl(pattern = '\\.bam$',uams.list)]
  uams.list <- unique(gsub(pattern = '.*_(\\d+)\\.bam$','\\1',uams.list))
  
  qcWES[['STUDY']] <- rep(NA,nrow(qcWES));
  qcWES[['STUDY']][qcWES$celgene_id %in% dfci.list] <- 'DFCI'
  qcWES[['STUDY']][qcWES$vendor == 'ICR London'] <- 'UAMS'
  qcWES[['STUDY']][is.na(qcWES[['STUDY']])] <- 'MMRF'
  qcWES[['UNIQUE.ID']] <- qcWES[['celgene_id']];
  qcWES[['UNIQUE.ID']][qcWES[['STUDY']] == 'MMRF'] <- paste('MMRF',qcWES[['celgene_id']][qcWES[['STUDY']] == 'MMRF'],sep='_')
  qcWES[['UNIQUE.ID']][qcWES[['STUDY']] == 'DFCI'] <- paste(qcWES[['UNIQUE.ID']][qcWES[['STUDY']] == 'DFCI'],'a',sep='')
  
  qcWGS <- read.csv(file='~/data/qcWGS.csv',colClasses=c('character'))
  qcWGS$celgene_id <- do.call(rbind,strsplit(qcWGS$display_name,'_'))[,2]
  qcWGS[['STUDY']] <- rep('MMRF',nrow(qcWGS))
  qcWGS[['UNIQUE.ID']] <- paste(qcWGS[['STUDY']],qcWGS[['celgene_id']],sep='_')
  list(qcRNA=qcRNA,qcWES=qcWES,qcWGS=qcWGS)
}

lookup <- function(X,dat,field,value,exclude=F) {
  if(exclude) {
    return(any(dat[['UNIQUE.ID']] == X & toupper(dat[[field]]) != toupper(value)))
  }
  return(any(dat[['UNIQUE.ID']] == X & toupper(dat[[field]]) == toupper(value)))
}

lookup.value <- function(X,dat,field) {
  tryCatch({
    paste(unique(dat[[field]][dat[['UNIQUE.ID']] == X]),collapse=',')
    },error=function(e){NA})
}

data <- read.data();

patients <- unique(c(data$qcRNA$UNIQUE.ID,data$qcWES$UNIQUE.ID,data$qcWGS$UNIQUE.ID))
basic_lookups <- rbind(data$qcRNA[,c('UNIQUE.ID','STUDY','celgene_id')],data$qcWES[,c('UNIQUE.ID','STUDY','celgene_id')],data$qcWGS[,c('UNIQUE.ID','STUDY','celgene_id')])
out <- data.frame(Patient=as.character(patients),
                  celgene_id=unlist(lapply(patients,lookup.value,basic_lookups,'celgene_id')),
                  STUDY=unlist(lapply(patients,lookup.value,basic_lookups,'STUDY')),
                  Has.RNA.CD138plus=ifelse(unlist(lapply(patients,lookup,data$qcRNA,'cell_type','CD138+')),yes=1,no=0),
                  Has.WES.Normal=ifelse(unlist(lapply(patients,lookup,data$qcWES,'condition','Normal')),yes=1,no=0),
                  Has.WES.Not.Normal=ifelse(unlist(lapply(patients,lookup,data$qcWES,'condition','Normal',exclude=T)),yes=1,no=0),
                  Has.WGS.Normal=ifelse(unlist(lapply(patients,lookup,data$qcWGS,'condition','Normal')),yes=1,no=0),
                  Has.WGS.Not.Normal=ifelse(unlist(lapply(patients,lookup,data$qcWGS,'condition','Normal',exclude=T)),yes=1,no=0)
                  )

out[['Has.RNA.WES(Normal+Not.Normal)']] <- ifelse((out$Has.RNA.CD138plus+out$Has.WES.Normal+out$Has.WES.Not.Normal) > 2,yes=1,no=0)
out[['Has.RNA.WGS(Normal+Not.Normal)']] <- ifelse((out$Has.RNA.CD138plus+out$Has.WGS.Normal+out$Has.WGS.Not.Normal) > 2,yes=1,no=0)
out[['Has.RNA.WES.WGS(Normal+Not.Normal)']] <- ifelse((out$Has.RNA.CD138plus+out$Has.WES.Normal+out$Has.WES.Not.Normal+out$Has.WGS.Normal+out$Has.WGS.Not.Normal) > 4,yes=1,no=0)

# For debugging/transparency

write.csv(out,file='~/aggregated_sample_inventory.csv',row.names=F)

VennDiagram::venn.diagram(x=list(WES=out$Patient[out$Has.WES.Normal+out$Has.WES.Not.Normal > 1],
                               WGS=out$Patient[out$Has.WGS.Normal+out$Has.WGS.Not.Normal > 1],
                               RNA.seq=out$Patient[out$Has.RNA.CD138plus > 0]),
                               filename = '~/venn_aggreagate_sample_inventory.pdf')