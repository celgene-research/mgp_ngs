#SCRIPT to stage the reference databases depending on the requirements of the job
# it is basically a dispatcher that depending on the arguments provided by the user initially decides what to stage
# all the data is copied to $ NGS_USR_DATA_DIR

if [ -z "$CELGENE_AWS" -o "$CELGENE_AWS" != "true" ] ;then
	echo 'This is not an AWS environment. Assuming HPC'
	exit 0
fi
if [ -z "$NGS_USR_DATA_DIR" ] ; then
	echo 'Please make sure that the $NGS_USR_DATA_DIR environment variable is set'
	exit 100
fi



# create a soft link to place the refernece data. 
mkdir -p /scratch/reference
if [ ! -d /celgene/reference ] ;then
	ln -s /scratch/reference /celgene
fi

# wait until the lock ;;le disappears and then exit
function waitLoop(){
	directory=$1
	
	while [ -e $directory/LOCKFILE ]
	do
		sleep 15s
	done
	if [ -d $directory -a -e $directory/DONETRANSFER ] ; then
		return
	fi
	echo 'Although the lock file is not in the directory anymore, there is no DONETRANSFER file. Something must have gone wrong'
	exit 10	
}

function stageDirectory(){
	awsDirectory=$1
	localDirectory=$2
			
	mkdir -p $localDirectory
	touch $localDirectory/LOCKFILE
	s3cmd sync $awsDirectory/ $localDirectory/  &> $localDirectory/transfer.$$.log
	
	if [ $? -ne 0 ] ; then
		echo "Failed to run command"
		rm $localDirectory/LOCKFILE
		touch $localDirectory/FAILED_TRANSFER
		exit 102
	fi
	rm $localDirectory/LOCKFILE
	touch $localDirectory/DONETRANSFER
				
	return		
	
}

option=$1
# dispatcher



function dispatch(){
	awsDirectory=$1
	localDirectory=$2
	if [ -d $localDirectory -a -e $localDirectory/LOCKFILE ] ; then
		waitLoop $localDirectory
		return
	fi
	if [ -d $localDirectory -a -e $localDirectory/DONETRANSFER ] ; then
		return
	fi
	stageDirectory $awsDirectory $localDirectory 
	
}


	
# main dispatch loop
# here all the different steps need to be known
# so as to bring the correct files
# if the step is unknown the script will mention that
# but will not exit (since there are steps that do not require any staging

echo "Staging data for step $option"
case "$option" in
##############
# ERCC
# download the ERCC spike ins
 "Bowtie2.ERCC" )
	dispatch $erccDirAWS $erccDir 
;;

##############
# Homo sapiens
# download the human indexes for bwa
"BWAmem.human" )
	dispatch $humanBWAidxAWS $humanBWAidx
;;
"RSEM.human" )
	dispatch $humanrsemidxAWS $humanrsemidx
;;
"bowtie2-transcripts.human" )
	dispatch $humanrsemidxAWS $humanrsemidx
;;
"Bowtie2.human" )
	dispatch $humanBowtie2idxAWS $humanBowtie2idx
;;
"Bowtie.human" )
	dispatch $humanBowtieidxAWS $humanBowtieidx
;;
"Bismark.human" )
	dispatch $humanbismarkidxAWS $humanbismarkidx
;;
"BismarkExtractor.human" )
	dispatch $humanGenomeDirAWS $humanGenomeDir
;;
"Express.human" )
	dispatch $humanrsemidxAWS $humanrsemidx
;;
"Salmon-bam.human" )
	dispatch $humanrsemidxAWS $humanrsemidx
;;
"Sailfish.human" )
	dispatch ${humanDirAWS}/SailFish0.9_Index ${humanDir}/SailFish0.9_Index
;;
# download the human indexes for STAR
"STARaln.human" )
   dispatch $humanSTARidxAWS $humanSTARidx
;;
"MISO.human" )
	dispatch $humanAnnotationDirAWS $humanAnnotationDir
;;
"cufflinks.human" )
	dispatch $humanChromosomesDirAWS $humanChromosomesDir
	dispatch $humanAnnotationDirAWS $humanAnnotationDir
;;
# Download reference sequences for human
"CalculateHsMetrics.human" | \
"MergeBamAlignment.human" | \
"CalculateAlnMetrics.human" | \
"InsertSize.human" | \
"CollectRNASeqMetrics.human" | \
"MarkDuplicates.human" | \
"LibraryComplexity.human" | \
"htseqGeneCount.human" )
	dispatch $humanAnnotationDirAWS $humanAnnotationDir
	dispatch $humanGenomeDirAWS $humanGenomeDir
	
;;
"controlFreec.human" )
	dispatch $humanChromosomesDirAWS $humanChromosomesDir
	dispatch $humanGenomeDirAWS $humanGenomeDir
;;
# Download the reference variant dbs for human
"human-variants" | \
"Vannot" )
	dispatch $humanVariantsDirAWS $humanVariantsDir
;;
# Download the reference variants for GATK related jobs
"GATK"* )
	dispatch  $humanVariantsDirAWS $humanVariantsDir
	dispatch $humanGenomeDirAWS $humanGenomeDir
	dispatch $GATK_REF_AWS $GATK_REF
;;

##################
# Rattus norvegicus
"BWAmem.rat" )
	dispatch $ratBWAidxAWS $ratBWAidx
;;
# download the rat indexes for STAR
"STARaln.rat" )
	dispatch $ratSTARidxAWS $ratSTARidx
;;

# Download reference sequences for rat
"CalculateHsMetrics.rat" | \
"CalculateAlnMetrics.rat" | \
"InsertSize.rat" | \
"CollectRNASeqMetrics.rat" | \
"MarkDuplicates.rat" | \
"LibraryComplexity.rat" | \
"htseqGeneCount.rat" )
	dispatch $ratAnnotationDirAWS $ratAnnotationDir
	dispatch $ratGenomeDirAWS $ratGenomeDir
	
;;


##################
# xenografts
"BWAmem.xenograft" )
	dispatch $human_mouseBWAidxAWS $human_mouseBWAidx
;;
# download the xenograft indexes for STAR
"STARaln.xenograft" )
	dispatch $human_mouseSTARidxAWS $human_mouseSTARidx
;;

# Download reference sequences for xenograft
"CalculateHsMetrics.xenograft" | \
"CalculateAlnMetrics.xenograft" | \
"InsertSize.xenograft" | \
"CollectRNASeqMetrics.xenograft" | \
"MarkDuplicates.xenograft" | \
"LibraryComplexity.xenograft" | \
"htseqGeneCount.xenograft" )
	dispatch $human_mouseAnnotationDirAWS $human_mouseAnnotationDir
	dispatch $human_mouseGenomeDirAWS $human_mouseGenomeDir
	
;;

##################
# rat

# download the xenograft indexes for STAR
"STARaln.rat" )
	dispatch $ratSTARidxAWS $ratSTARidx
;;

# Download reference sequences for xenograft
"CalculateHsMetrics.rat" | \
"CalculateAlnMetrics.rat" | \
"InsertSize.rat" | \
"CollectRNASeqMetrics.rat" | \
"MarkDuplicates.rat" | \
"LibraryComplexity.rat" | \
"htseqGeneCount.rat" )
	dispatch $ratAnnotationDirAWS $ratAnnotationDir
	dispatch $ratGenomeDirAWS $ratGenomeDir
	
;;

* )
	echo "Cannot recognize step $option. No action is taken"
;;

esac
