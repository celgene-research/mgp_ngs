#!/usr/bin/env Rscript


# run sequenza following the user guide at https://cran.r-project.org/web/packages/sequenza/vignettes/sequenza.pdf

#setup the R environment to be able to find teh packages needed
.libPaths(
  c("/celgene/software/R_lib/",Sys.getenv("sequenzalib"))
)
          

suppressMessages( library("optparse", verbose=FALSE,quietly=TRUE) )
option_list <- list(
		make_option(c("-s", "--seqfile"), action="store",type="character",
				dest="seqfile", help="Sequenza file of (typically .seqz)"),
		make_option(c("-o", "--output"), action="store",type="character",
				dest="output", help="Output of run"),
		make_option(c("-c", "--cores"), action="store",type="numeric",
				dest="cores", help="Number of cores to use"),	
		make_option(c("-w", "--window"), action="store",type="numeric",
				dest="window", help="Window size for seqz binning")
)
opt <- parse_args(OptionParser(option_list=option_list))




# the inputs require

seqfile=NULL


seqfile=opt$seqfile
output=opt$output
cores=opt$cores
window=opt$window
if(is.null(seqfile)){
	stop(sprintf("Please provide the sequenza file for processing \n"))
}
if(is.null(cores)){
	cores=1
}
if(is.null(window)){
	window=50
}
if(is.null(output)){
	stop(sprintf("Please provide the output location \n"))
}

if(! file.exists(seqfile)){
	stop("Cannot file sequenza ",seqfile)
}

message("Input file is ",seqfile)
message("Output will be stored in ",output)
message("Window size for binning is set to ", window)
message("Using ",cores," cores")
suppressMessages( library("sequenza"))
#1. Convert pileup to seqz format (done outside this script)
#2. Normalization of depth ratio
#3. Allele-specific segmentation using the depth ratio and the B allele frequencies (BAFs)
#4. Infer cellularity and ploidy by model fitting
#5. Call CNV and variant allele



# reformat the file
# since the input seqz.gz is probably coming from parallel runs of sequenza
# it is likely that it contains the header line in multiple placesi n the file while it should have been only in the first
orig=seqfile
command=sprintf("pigz -p %d -d -c %s | sed '/position/{2,$d}' | pigz -p %d -c > tmp.%s ",cores, orig, cores, orig);
message("Executing command: ",command);
system( command, wait = TRUE )



# for memory efficiency we can bin the sez file
command2=sprintf("%s seqz-binning -w %d -s tmp.%s | pigz -p %d -c > binned.%s", Sys.getenv( "sequenzautilsbin" ), window, orig, cores, orig)
seqfile=paste0("binned.",orig) 
message("Executing command: ",command2);
system( command2, wait = TRUE )


# run the sequenza pipeline
chromosomes=paste0('chr',c(seq(1,22),'X','Y') )
test <- sequenza.extract(seqfile,chromosome.list = chromosomes)

CP.example <- sequenza.fit(test, mc.cores=cores)

sequenza.results(sequenza.extract = test, cp.table = CP.example,
 sample.id = output, out.dir=output )
 
file.remove( paste0("tmp.",orig),
			 paste0("binned.",orig)
			 )
 
	