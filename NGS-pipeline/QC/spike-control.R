#!/usr/bin/env Rscript

# TODO: Add comment
# 
# Author: kmavrommatis
###############################################################################

library("optparse", verbose=FALSE,quietly=TRUE)
option_list <- list(
		make_option(c("-b", "--bamfile"), action="store",type="character",
				dest="bam.file", help="BAM file of alignment to ERCC standards"),
		make_option(c("-o", "--outpdf"), action="store",type="character",
				dest="pdf.file", help="Chart output file "),
		make_option(c("-t", "--outtable"), action="store", type="character",
				dest="tbl.file", help="Text output file"),
		make_option(c("-m", "--mix"), action="store", type="integer", default=1,
				dest="ERCCmix", help="ERCC Mix [default=1]"),
		make_option(c("-s", "--sample"), action="store", type="integer",default=0,
				dest="sample", help="Sample it for this file (single value- not a list)")
#		,		
#		make_option(c("-s", "--sample"), action="store", type="integer", default=0,
#				help="sample id in the samples database",
#				metavar="number")
)
opt <- parse_args(OptionParser(option_list=option_list))

bam.file=NULL
tbl.file=NULL
pdf.file=NULL
analysis.task=NULL
bam.file=opt$bam.file
pdf.file=opt$pdf.file
tbl.file=opt$tbl.file
ERCCmix=opt$ERCCmix
analysis.task=38
sample= opt$sample
#sample=opt$sample
if(is.null(bam.file)){
	stop(sprintf("Please provide an input bam file\n"))
}
if(is.null(analysis.task)){
	stop(sprintf("Please provide an analysis task id\n"))
}
if(is.null(pdf.file)){
	pdf.file=paste(sep="",bam.file,".pdf")
}
if(is.null(tbl.file)){
	tbl.file=paste(sep="",bam.file,".tbl")
}
if(ERCCmix <1 & ERCCmix >3){
	stop(sprintf("ERCC mix can be either 1 or 2. Your selection %d is invalid\n",opt$ERCCmix))
}
#if(is.null(sample)){
#	stop(sprintf("Please provide the sample id for this sample\n"))
#}
if(bam.file == pdf.file | bam.file==tbl.file){
	stop(sprintf("Input and output files cannot be the same \n"))	
}




library("rtracklayer", verbose=FALSE,quietly=TRUE)
library("Rsamtools", verbose=FALSE,quietly=TRUE)
library("GenomicAlignments", verbose=FALSE,quietly=TRUE)
library("RCurl")
library("XMLRPC")


getSamples<-function(sample_id, useful=FALSE, debug=FALSE){
	
	server_url=getServer();
	cat(sprintf("Server address: %s\n", server_url ))
	
	
	dbFiles1=xml.rpc(server_url, 'sampleInfo.getSampleByID',sample_id)
	dbFiles2=xml.rpc(server_url, 'sampleInfo.getSampleBamQCByID', sample_id)
	
	return(c(dbFiles1,dbFiles2))
}

getSampleId = function(bam.file, is_absolute=FALSE){
	
	if(is_absolute==FALSE){
		bam.file=tools:::file_path_as_absolute( bam.file );
	}
	server_url=getServer();
	cat(sprintf("bam file :%s\nServer address: %s\n", bam.file,server_url ))
	
	sample=0;
	sample=xml.rpc(server_url, 'metadataInfo.getSampleIDByFilename',bam.file)
	if( is.null(sample) || length(sample) == 0 ){sample=0}
	return(sample);
}


getServer=function(){
	port=8082;
	ngs_server_port=Sys.getenv("NGS_SERVER_PORT")
	if(!is.na(ngs_server_port) & !is.null(ngs_server_port) & ngs_server_port != "" ){ 
		port= ngs_server_port;
	}
	ip="localhost";
	ngs_server_ip=Sys.getenv("NGS_SERVER_IP")
	if(!is.na(ngs_server_ip) & !is.null(ngs_server_ip) & ngs_server_ip != ""){ 
		ip=ngs_server_ip;
	}
	server_url = paste(sep="","http://",ip,":",port,"/RPC2")
	return(server_url);
}

updateServer=function(sample,  correlation, min.spike.concentration, spike_reads){
	server_url=getServer();
	cat(sprintf("bam file :%s\nServer address: %s\n", bam.file,server_url ))
	
	data=c( 'spike_correlation',correlation,
			'spike_min_concentration',min.spike.concentration,
			'spike_reads',spike_reads)
	xml.rpc(server_url, 'sampleQC.updateReadQC',data, sample)
	
	
}

thisFile <- function() {
	cmdArgs <- commandArgs(trailingOnly = FALSE)
	needle <- "--file="
	match <- grep(needle, cmdArgs)
	fullname=NULL;
	if (length(match) > 0) {
		# Rscript
		fullname=sub(needle, "", cmdArgs[match])
	} else {
		# 'source'd via R console
		fullname=normalizePath(sys.frames()[[1]]$ofile)
	}
	return( dirname(fullname) )
}

script.directory=thisFile();
spike.dir=thisFile();
info1=paste(spike.dir,"ercclib", "cms_095046.txt",sep="/")
info2=paste(spike.dir,"ercclib", "cms_095047.txt",sep="/")
# get the sample_id from the file by querying the NGS server
if(is.null(sample) ){
	cat(sprintf("Querying the NGS server to get the sample_id fro file %s\n",bam.file))
	sample=getSampleId(bam.file)
}

cat(sprintf("Processing %s\nfrom sample %d using spike-in mix %d\nOutput in %s\n",bam.file,sample,ERCCmix,pdf.file))


spike.info=read.table( info1, sep="\t", header=T)
spike.info2=read.table( info2, sep="\t", header=T)

slen=nchar(as.character( spike.info2$Sequence) )
spike.info2=cbind( spike.info2, slen)

merge(spike.info, spike.info2, by.x='ERCC.ID', by.y='ERCC_ID')->spike.merged



#dbFiles=getSamples( sample)

read.counts=data.frame();
	
cat(sprintf("Processing file %s\n" ,bam.file))
# load the bam file from the disk
aln.bam=readGAlignments( file=bam.file, 
		format="BAM")
rpkms=rep(0, nrow(spike.merged));
for(j in 1:nrow(spike.merged)){
	spike.name=as.character(spike.merged$ERCC.ID[j])		
	records=aln.bam[ seqnames(aln.bam)==spike.name]
	nrecords=length(records)

	read.counts[j,1]=nrecords
}


#colnames(read.counts)=dbFiles$celgene_id
colnames(read.counts)=bam.file
if(ERCCmix ==1 ){ column= "concentration.in.Mix.1..attomoles.ul."}
if(ERCCmix ==2 ){ column= "concentration.in.Mix.2..attomoles.ul."}
ymax=max(log(spike.merged[,column]))
ymin=min(log(spike.merged[,column]))

#pdf.file=file.path(bam.dir,"spike.pdf")

pdf(pdf.file)
#for(s in 1:nrow(dbFiles)){
par(new=F)
plot.data=as.data.frame(
		cbind( read.counts[, 1], 
				spike.merged[,c(column,"ERCC.ID")] ,
				read.counts[, 1]/
						spike.merged$slen#/(as.numeric(dbFiles$pf_reads_aligned[3])/1000000)
		)
)
totalERCCreads=sum( plot.data$observed)

colnames(plot.data)=c("observed","spiked","ERCCid","rpkm")
plot.data.filtered=plot.data[ which(plot.data$observed>5),]
plot.data.removed =plot.data[ which(plot.data$observed<=5),]

plot( log(plot.data.filtered$rpkm), log(plot.data.filtered$spiked),
		ylim=c(ymin,ymax),
		xlim=c(-12,5),
		col='black',
		pch=3,
		xlab="",ylab="")
par(new=T)
plot( log(plot.data.removed$rpkm), log(plot.data.removed$spiked),
		ylim=c(ymin,ymax),
		xlim=c(-12,5),
		col='red',
		pch=3,
		xlab="",ylab="")

mod=lm(log(plot.data.filtered$rpkm)~ 
		log(plot.data.filtered$spiked))

title(ylab="Control concentration (attomoles/ul)",
		xlab="Observed concentration log(RPKM)",
		cex.lab=1.3,
		main=sprintf("%s\nR squared %.3f",bam.file,summary(mod)$adj.r.squared)
)
dev.off()
correlation=summary(mod)$adj.r.squared
min.spike.concentration=min(plot.data.filtered$spiked)
		


# write the results in the tbl file
write.table("#Spike-ins more than 5 reads\n",tbl.file,append=F, quote=F,row.names=F,col.names=F)
write.table("ERCCid\tRPKM\tERCC concentration\n",tbl.file,append=T, quote=F,row.names=F,col.names=F)
write.table(plot.data.filtered[, c('ERCCid','rpkm','spiked')],tbl.file,append=T, quote=F,sep="\t",row.names=F,col.names=F)
write.table("#Spike-ins less than 5 reads\n",tbl.file,append=T, quote=F,row.names=F,col.names=F)
write.table("ERCCid\tRPKM\tERCC concentration\n",tbl.file,append=T, quote=F,row.names=F,col.names=F)
write.table(plot.data.removed[, c('ERCCid','rpkm','spiked')],tbl.file,append=T, quote=F,sep="\t",row.names=F,col.names=F)
write.table(
		sprintf("#QUALITY METRICS\ncorrelation\t%.6f\nmin concentration\t%.6f\n",
				correlation,
				min.spike.concentration),
		tbl.file,append=T, quote=F,row.names=F,col.names=F)


	
#}

cat(sprintf("Results in files %s and %s\n", pdf.file, tbl.file))



#inform the database on these values
cat(sprintf("Updating database: sample/correlation/min concentration=%d / %.3f /%.3f\n",
				sample,
				correlation,
				min.spike.concentration))
if(sample >0){
updateServer(
		sample,
		correlation,
		min.spike.concentration,
		totalERCCreads
)
}else{
	print("Unable to find sample id for the input file. Database has not been updated")
}


