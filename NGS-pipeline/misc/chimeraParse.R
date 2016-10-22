#!/usr/bin/Rscript

.libPaths(
  c("/celgene/software/R_lib/")
)

suppressMessages( library("optparse", verbose=FALSE,quietly=TRUE) )
option_list <- list(
  make_option(c("-v", "--version"), action="store_true",
              dest="version", default=FALSE, help="Input file"),
  make_option(c("-i", "--input"), action="store",type="character",
              dest="input", help="Input file"),
  make_option(c("-a", "--annotation"), action="store",type="character",
              dest="annotation", help="Annotation file in gff format"),
  make_option(c("-r", "--rdata"), action="store",type="character",
              dest="rdata", help="Rdata file with data frames produced from the analysis"),
  make_option(c("-o", "--output"), action="store",type="character",
              dest="output", help="Tab delimited output file")
)
opt <- parse_args(OptionParser(option_list=option_list))

if(opt$version==TRUE){
 
  cat("Chimera parse version 0.1a\n")
  quit()
}

input=opt$input
annotation.file=opt$annotation
rdata.file=opt$rdata
output.file=opt$output

if(is.null(input) | is.null(annotation.file) | is.null(output.file)| is.null(rdata.file) ){
  stop("Please provide the necessary input arguments"
  )
}

suppressMessages( library("chimera", verbose=FALSE,quietly=TRUE) )


outfile=paste0(input,".RData")

f1=importFusionData('star',input,org="hg38", min.support=10)

tm1=f1
tm2=filterList(tm1, type="spanning.reads", query=2)
tm3=filterList(tm2, type="read.through")

res=cbind( fusionGenes=fusionName(tm3), spanningReads=supportingReads(tm3,"spanning"), encompassingReads=supportingReads(tm3,"encompassing"))




# we observed that the IgH is not annotated in the dataset that chimear uses and thus it does not annotate it
# "/mnt/celgene.rnd.combio.mmgp.external/data/Genomes/Homo_sapiens/GRCh38.p2/Annotation/gencode.v24/gencode.annotation.gtf"
annotation.gff=import.gff(annotation.file)
annotation.gff=keepSeqlevels(annotation.gff, as.character(seq(1,22) ) )
newStyle = mapSeqlevels(seqlevels(annotation.gff),"UCSC")
annotation.gff= renameSeqlevels(annotation.gff, newStyle)
annotation.gff=annotation.gff[which(mcols(annotation.gff)$type=="gene"),]


pattern="chr\\d+:\\d+-\\d+"

for(i in 1:nrow(res) ){
  # get the chr:XXX-YYY regions

  rm=unlist(regmatches(res[i,1], gregexpr( pattern,res[i,1])))
  if(length(rm)==0){ next}
  for(j in 1:length(rm)){
    RM=rm[j]
    ss=unlist(strsplit(RM,split = "[-:]" ) )
    gr=GRanges(seqnames=ss[1], ranges=IRanges(start=as.numeric(ss[2]),end=as.numeric(ss[3])))
    ov=findOverlaps( query= annotation.gff, subject=gr)
    if(length(queryHits(ov))==0){ 
      rep=RM
    }else{
      rep=paste( mcols(annotation.gff[ queryHits(ov),])$gene_name, collapse="//")
    }
    res[i,1]=sub( pattern=RM,replacement = rep,x=res[i,1])
  }
  
}
res=as.data.frame(res)
res[,1]=as.character(res[,1])
res[,2]=as.numeric(as.character(res[,2]))
res[,3]=as.numeric(as.character(res[,3]))

save(file = rdata.file, list=c("input","f1","res", "annotation.gff") )
write.table( res, file=output.file, quote=FALSE,sep="\t",row.names=FALSE, col.names=TRUE)