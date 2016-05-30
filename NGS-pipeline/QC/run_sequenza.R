#!/usr/bin/env Rscript


# run sequenza following the user guide at https://cran.r-project.org/web/packages/sequenza/vignettes/sequenza.pdf

#setup the R environment to be able to find teh packages needed
.libPaths(
  c("/celgene/software/R_lib/",Sys.getenv("sequenzalib"))
)
          

suppressMessages( library("optparse", verbose=FALSE,quietly=TRUE) )
option_list <- list(
		make_option(c("-n", "--normal"), action="store",type="character",
				dest="pileup.normal", help="BAM file of normal sample"),
		make_option(c("-t", "--tumor"), action="store",type="character",
				dest="pileup.tumor", help="BAM file of tumor "),
		make_option(c("-o", "--output"), action="store", type="character",
				dest="output", help="name of output directory"),
		make_option(c("-G", "--gcfile"), action="store", type="character",
				dest="gcfile", help="name of output directory"),
		make_option(c("-F", "--fasta"), action="store", type="character",
				dest="fastafile", help="fasta file of reference genome"),
		make_option(c("-c", "--cores"), action="store", type="integer",
				dest="cores", help="Number of cores to use ",default =1)
)
opt <- parse_args(OptionParser(option_list=option_list))


message("Normal input file is ",opt$pileup.normal)
message("Tumor input file is ", opt$pileup.tumor)
message("GC file is ", opt$gcfile)
message("fasta reference file is ",opt$fastafile)

# the inputs require
pileup.normal=NULL #"/mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/UAMS/mpileup_1463511942/_EGAR00001321912_EGAS00001001147_C25U8ACXX_1_457.pileup.gz"
pileup.tumor=NULL #"/mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/UAMS/mpileup_1463511942/_EGAR00001321913_EGAS00001001147_C25U8ACXX_1_458.pileup.gz"
output=NULL
gcfile=NULL
cores=NULL
fastafile=NULL

pileup.normal=opt$pileup.normal
pileup.tumor=opt$pileup.tumor
output=opt$output
gcfile=opt$gcfile
cores=opt$cores
fastafile=opt$fastafile
samtools=Sys.getenv('samtoolsbin')
if(is.null(pileup.normal)){
	stop(sprintf("Please provide the pileup for normal \n"))
}
if(is.null(pileup.tumor)){
	stop(sprintf("Please provide the pileup for tumor \n"))
}
if(is.null(output)){
	stop(sprintf("Please provide the output directory \n"))
}
if(is.null(cores)){
	message(sprintf("running in single threaded mode \n"))
	cores=1
}
if(is.null(gcfile)){
	stop(sprintf("Please provide the gcfile \n"))
}
if(is.null(fastafile)){
	humanGenome=paste0(Sys.getenv("humanGenomeDir"),"/genome.fa")
	message("Using defauld reference genome ", humanGenome)
	fastafile=humanGenome
		
}

if(! file.exists(fastafile)){
	stop("Cannot file fastafile ",fastafile)
}
if(! file.exists(gcfile)){
	stop("Cannot find gcfile ", gcfile)
}
if(! file.exists(samtools)){
	stop("Cannot find samtools at ",samtools)
}
suppressMessages( library("sequenza"))
suppressMessages( library("parallel"))
seqz.script= system.file("exec", "sequenza-utils.py", package="sequenza")

#Workflow
#1. Convert pileup to seqz format
#2. Normalization of depth ratio
#3. Allele-specific segmentation using the depth ratio and the B allele frequencies (BAFs)
#4. Infer cellularity and ploidy by model fitting
#5. Call CNV and variant allele


#first prepare the reference
#gcfile="/scratch/sequenza/hg19.gc50Base.txt.gz"
#humanGenome=paste0(Sys.getenv("humanGenomeDir"),"/genome.fa")
#cmd=sprintf("%s GC-windows -w 50 %s | gzip > %s",
#		seqz.script , humanGenome, gcfile)
#system( cmd, intern=TRUE)

#1. Convert pileup to sez format
message("Converting pileup to seqz format")


output.tmp=paste0(output,".seqz.tmp.gz")
output.final=paste0(output,".seqz")

#mapper part
chromosomes=paste0('chr',c(seq(1,22),'X','Y') )

chrfiles=mclapply( chromosomes, FUN=function(chr){
	message("processing chromosome ", chr)
	cmd=sprintf( "%s  bam2seqz -S %s -F %s -C %s -gc %s -n %s -t %s | gzip > %s-%s ; %s  seqz-binning -w 50 -s %s-%s | gzip > %s-%s", 
             seqz.script, samtools, fastafile, chr, gcfile, pileup.normal, pileup.tumor, chr,output.tmp,
             seqz.script, chr, output.tmp, chr,output.final)
	#system( cmd, intern=TRUE)
	file.remove( paste(chr, output.tmp,sep="-") )
	#message(cmd)
	paste(chr, output.final,sep="-")
}, mc.cores=cores)

#reducer part
if(file.exists( output.final) ){
	file.remove(output.final) 
}
if(file.exists( paste0(output.final,".gz") ) ){
	file.remove( paste0(output.final,".gz")) 
}
cmd= sprintf("gunzip -c %s |head -1 > %s", chrfiles[[1]], output.final)
system(cmd,intern=TRUE)
j=lapply( chrfiles, function(X){
	message("Merging file ",X)
	cmd=sprintf("gunzip -c %s | grep -v chromosome >> %s", X, output.final)
	system(cmd,intern=TRUE)
	
})
cmd=sprintf("gzip %s", output.final)
system(cmd,intern=TRUE)
output.final=paste0(output.final,".gz")

#2. Normalization of depth ratio
message("Normalizing data in ",output.final)
seqz.data = read.seqz(output.final)
gc.stats = gc.norm( x=seqz.data$depth.ratio, gc=seqz.data$GC.percent)
gc.vect = setNames(gc.stats$raw.mean, gc.stats$gc.values)
seqz.data$adjusted.ratio <- seqz.data$depth.ratio / gc.vect[as.character(seqz.data$GC.percent)]
#par(mfrow = c(1,2), cex = 1, las = 1, bty = 'l')
#matplot(gc.stats$gc.values, gc.stats$raw,type = 'b', col = 1, pch = c(1, 19, 1), lty = c(2, 1, 2),xlab = 'GC content (%)', ylab = 'Uncorrected depth ratio')
#legend('topright', legend = colnames(gc.stats$raw), pch = c(1, 19, 1))
#hist2(seqz.data$depth.ratio, seqz.data$adjusted.ratio,breaks = prettyLog, key = vkey, panel.first = abline(0, 1, lty = 2),xlab = 'Uncorrected depth ratio', ylab = 'GC-adjusted depth ratio')


#3. Allele-specific segmentation using the depth ratio and the B allele frequencies (BAFs)
test <- sequenza.extract(output.final,chromosome.list = chromosomes)
for(i in length(chromosomes)){
  chromosome.view(mut.tab = test$mutations[[i]], baf.windows = test$BAF[[i]],
   ratio.windows = test$ratio[[i]], min.N.ratio = 1,
  segments = test$segments[[i]], main = test$chromosomes[i])
}

#4. Infer cellularity and ploidy by model fitting
CP.example <- sequenza.fit(test)

sequenza.results(sequenza.extract = test, cp.table = CP.example,
 sample.id = output, out.dir=output )
 
#  cint <- get.ci(CP.example)
# 
# cp.plot(CP.example)
# 
# cp.plot.contours(CP.example, add = TRUE)
# 
# 
# par(mfrow = c(2,2),mar=c(5,2,2,1),oma=c(3,3,3,3))
# cp.plot(CP.example)
# cp.plot.contours(CP.example, add = TRUE, likThresh = c(0.95))
# plot(cint$values.cellularity, ylab = "Cellularity",
# 	xlab = "posterior probability", type = "n")
# select <- cint$confint.cellularity[1] <= cint$values.cellularity[,2] &
# 	cint$values.cellularity[,2] <= cint$confint.cellularity[2]
# polygon(y = c(cint$confint.cellularity[1], cint$values.cellularity[select, 2], cint$confint.cellularity[2]),
# 	x = c(0, cint$values.cellularity[select, 1], 0), col='red', border=NA)
# lines(cint$values.cellularity)
# abline(h = cint$max.cellularity, lty = 2, lwd = 0.5)
# plot(cint$values.ploidy, xlab = "Ploidy",
# 	ylab = "posterior probability", type = "n")
# select <- cint$confint.ploidy[1] <= cint$values.ploidy[,1] &
# 	cint$values.ploidy[,1] <= cint$confint.ploidy[2]
# polygon(x = c(cint$confint.ploidy[1], cint$values.ploidy[select, 1], cint$confint.ploidy[2]),
# 	y = c(0, cint$values.ploidy[select, 2], 0), col='red', border=NA)
# lines(cint$values.ploidy)
# abline(v = cint$max.ploidy, lty = 2, lwd = 0.5)


#5. Call CNV and variant allele

#cellularity <- cint$max.cellularity
#ploidy <- cint$max.ploidy
#avg.depth.ratio <- mean(test$gc$adj[, 2])
#mut.tab <- na.exclude(do.call(rbind, test$mutations))

#mut.alleles <- mufreq.bayes(mufreq = mut.tab$F,
#	depth.ratio = mut.tab$adjusted.ratio,
#	cellularity = cellularity, ploidy = ploidy,
#	avg.depth.ratio = avg.depth.ratio)

#seg.tab <- na.exclude(do.call(rbind, test$segments))
#cn.alleles <- baf.bayes(Bf = seg.tab$Bf, depth.ratio = seg.tab$depth.ratio,
#	cellularity = cellularity, ploidy = ploidy,
#	avg.depth.ratio = avg.depth.ratio)
	
	
#chromosome.view(mut.tab = test$mutations[[3]], baf.windows = test$BAF[[3]],
#	ratio.windows = test$ratio[[3]], min.N.ratio = 1,
#	segments = seg.tab[seg.tab$chromosome == test$chromosomes[3],],
#	main = test$chromosomes[3],
#	cellularity = cellularity, ploidy = p
	
	
#genome.view(seg.cn = seg.tab, info.type = "CNt")
#legend("bottomright", bty="n", c("Tumor copy number"),col = c("red"),
#	inset = c(0, -0.4), pch=15, xpd = TRUE)
	
	
	
#genome.view(seg.cn = seg.tab, info.type = "AB")
#legend("bottomright", bty = "n", c("A-allele","B-allele"), col= c("red", "blue"),
#	inset = c(0, -0.45), pch = 15, xpd = TRUE)
	