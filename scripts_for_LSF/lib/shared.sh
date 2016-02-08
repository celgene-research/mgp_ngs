#!/bin/bash


# script that does some preparation for an NGS pipeline script
# sets the log directory
# sets the temp directory
# sets the log file 


function setLogging(){
	stem=$1
	step=$2
	da=$3
	
	NGS_LOG_DIR=$(echo $NGS_LOG_DIR | sed 's|/'${step}'||g' )
	echo "Logging: Step is set to $step" 1>&2
	if [ -z "${da}" ] ;then
		NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
	else
		NGS_LOG_DIR=$(echo $NGS_LOG_DIR | sed 's|/'${da}'||g' )
		NGS_LOG_DIR=${NGS_LOG_DIR}/${da}/${step}
		echo "Logging: Data assets is set to  $da" 1>&2
	fi
	export NGS_LOG_DIR=$(echo $NGS_LOG_DIR | sed 's|//|/|g' )
	mkdir -p $NGS_LOG_DIR
	echo "Logging: Created directory $NGS_LOG_DIR" 1>&2
	export MASTER_LOGFILE=${NGS_LOG_DIR}/${stem}.${step}.log
	export STAGEFILE_LOGFILE=${MASTER_LOGFILE}
	export CELGENE_EXEC_LOGFILE=${MASTER_LOGFILE}
	if [ -e $CELGENE_EXEC_LOGFILE ] ; then
			rm -f $CELGENE_EXEC_LOGFILE	
	fi
	echo "Logging: Master log file is set to $MASTER_LOGFILE" 1>&2
	echo "Logging: Stage file is set to $STAGEFILE_LOGFILE" 1>&2
	echo "Logging: CelgeneExec log file is set to $CELGENE_EXEC_LOGFILE" 1>&2
	
	echo $NGS_LOG_DIR
}

function checkfile(){
file=$1
	sample_id=$(ngs-sampleInfo.pl $file sample_id)
	
	if [ "$sample_id" ==  "NA" ]; then
		echo "File $file has not been registered to the database"
		exit 1
	fi
	echo "Processing file $file of sample $sample_id"
}

function setTemp(){
	step=$1
	NGS_TMP_DIR_ORIGINAL=${NGS_TMP_DIR}
	export NGS_TMP_DIR=${NGS_TMP_DIR_ORIGINAL}/${step}/${LSB_JOBID}	
	mkdir -p $NGS_TMP_DIR
}


# get the scheduler type
function getScheduler(){
	clusterString=$(lsid| head -1)
if [[ "$clusterString" =~ 'LSF' ]]
	then echo "LSF"
elif [[ "$clusterString" =~ 'openlava' ]]
	then echo "openlava"
fi
}

# if we run on LSF we give the same amount of memory
# that the user requests
# on openlava we divide the full amount with the cores
# to give the memory per core
function res_memory(){
	memory=$1
	cores=$2
	
	maxMem=$( fullmemory )
	if [ ${memory} -gt ${maxMem} ]; then
		memory=$maxMem
	fi
	
	scheduler=$( getScheduler )
	if [ "$scheduler" == "LSF" ]; then
		echo $memory
	elif [ "$scheduler" == "openlava" ]; then
		#echo $(( memory / cores ))
		echo $( awk "BEGIN{ print int($memory/$cores)}" )
			
	fi
	
	
}
# return the string that goes at the top of a bsub script with
# the name of teh job, stderr and stdout etc
function bsubHeader(){
	stem=$1
	step=$2	
	memory=$3
	cores=$4
	
	if [ -z "$cores" ]; then
		cores=1
	fi
	
	#if the requested cores are more than the cores the system can provide
	# then downsize to as many cores the node has
	fc=$(nproc)
	if [ "$cores" -gt "$fc" ] ; then
		cores=$fc
	fi 
	
	
	if [ -z "$memory" ]; then 
		memory=$(( 4000*$cores))
	fi
	
	
	
	
echo "#!/bin/bash"
echo "#BSUB -e ${NGS_LOG_DIR}/${stem}.${step}.bsub.stderr"
echo "#BSUB -o ${NGS_LOG_DIR}/${stem}.${step}.bsub.stdout"
echo "#BSUB -J ${stem}.${step}.bsub"
echo "#BSUB -r"
echo "#BSUB -E \"$scriptDir/../lib/stageReference.sh $step\""
resourceString $memory $cores
suffix=$( getStdSuffix $step )
echo "export suffix=${suffix}"
}

# use this function to get a string that can be appended to the output directory
# as a suffix, and will be used to distinguish different runs
function getStdSuffix(){
	step=$1
	
	if [ -n "$NGS_SUFFIX" ] ; then
		suffix="$NGS_SUFFIX"
echo "User has provided a directory suffix ${NGS_SUFFIX} for this run" 1>&2
	else
	# create a file with a predermined filename and use its date as the suffix for 
	# all directories
		if [ ! -e ${step}_suffixer ] ; then
			touch ${step}_suffixer
		fi
		
		suffix=$( stat -c %Y ${step}_suffixer )
		
	# if this suffix correspond to an older time (> 1h difference) 
	# then we need to re-issue this suffix
		cutoff=$(( $suffix + 3600 ))
		if (( $cutoff < $(date +%s) )) ; then
			touch ${step}_suffixer
			suffix=$( stat -c %Y ${step}_suffixer )
		fi
	fi
	

	
echo $suffix

	
	

}
# return the string that is appended at the top of a bsub script
# ask for the full memory and all the cores needed
function resourceString(){
	memory=$1
	cores=$2		
	mem=$(res_memory $memory $cores)
echo "#BSUB -n $cores"
echo "#BSUB -R \"span[ptile=$cores] rusage[mem=$mem]\" "
}

function fullcores(){
	maxCores=11 
	if [ "$NEWCLUSTER" == "1" ] ; then
		fc=$maxCores
	else
		fc=$(nproc)
		if [ "$fc" -gt "$maxCores" ] ; then 
				fc=$maxCores
		fi
	fi
	echo $fc				
							
}

function fullmemory(){
	
	var=$(free | awk '/^Mem:/{print $2}')
	var=$(( $var - 4000 ))
	
	echo $var
	
}

function initiateJob(){
	stem=$1
	step=$2
	filename=$3
	
	da=$( getDataAssets $filename  )
	
	setLogging $stem $step $da
	setTemp $step				
	
	
	echo "###############################"
	echo -n "Starting job at " 
	date
	echo "on host " $(hostname)
	if [ -e $LSB_ERRORFILE ] ;then
		rm -f $LSB_ERRORFILE
	
	fi
	
}

function closeJob(){
	rm -rf $NGS_TMP_DIR
	echo "$NGS_TMP_DIR was removed"
	export NGS_TMP_DIR=${NGS_TMP_DIR_ORIGINAL}	
	
	
	echo "End of job"
	echo "######################"
}


#return the dirname of a directory (i.e. everything except the last part)
function workDir(){
	input=$1
	local workDir=$( dirname $input )
	echo $workDir
}
#return the basename of a directory (i.e. only the last part)
function lastDir(){
	input=$1
	local workDir=$( workDir $input )
	local lastDir=$( basename $workDir )	
	echo $lastDir
}

function replaceDirNames(){
	directoryName=$1
	# for data that is on the cloud
	
	local newDirectoryName=$(  echo ${directoryName}  | sed 's%SRC%Processed%'| sed 's%src%Processed%'| sed 's%RawData%Processed%' | sed 's%Raw_Data%Processed%'| sed 's%rawdata%Processed%' | sed 's%raw_data%Processed%' )
	
	echo $newDirectoryName
}



# input is the name of the input file
# newDir is the name of the directory that will hold the results (e.g. contains the processing step)
function setOutput(){
	input=$1
	newDir=$2
	
	
	if [ -z "$input" ]; then
		echo "setOutput: input directory was not provided. Exiting" 1>&2
		exit 112
	fi
	if [ -z "$newDir" ]; then
		echo "setOutput: output directory was not provided. Exiting" 1>&2
		exit 112
	fi
	
	local workDir=$( workDir $input ) # get the directory including the last part
	workDir=$( dirname $workDir ) # get the directory without the last part
	local lastDir=$( lastDir $input)  # get the last part of teh directory name
	local outputDirectory=""
	
	workDir=$( replaceDirNames $workDir )  # replace the RawData names with Processed
	
	workDir=$( sanitizeDirectoryName ${workDir} )
	
	if [ -z "$NGS_OUTPUT_DIRECTORY" ] ; then
		newDir=$( sanitizeDirectoryName ${newDir} )
	else
		newDir=$( sanitizeDirectoryName ${NGS_OUTPUT_DIRECTORY} )
		echo "setOutput: User has provided a output directory (to replace the name of the tool/step of workflow)" 1>&2
	fi
	
	
	if [ -z "$NGS_PROCESSED_DIRECTORY" ] ; then
		
		outputDirectory="${workDir}/${newDir}"
	else
		#echo "Output will be under $NGS_PROCESSED_DIRECTORY"		
		NGS_PROCESSED_DIRECTORY=$(sanitizeDirectoryName ${NGS_PROCESSED_DIRECTORY} )
		outputDirectory="${workDir}/${NGS_PROCESSED_DIRECTORY}/${newDir}"
	fi
	
	
	#make sure that teh output directory does not end with a /
	outputDirectory=$(sanitizeDirectoryName ${outputDirectory})
	
	outputDirectory="/${outputDirectory}_${suffix}"

	
	mkdir -p $outputDirectory
	echo "setOutput: output directory is set to $outputDirectory" 1>&2
	echo $outputDirectory
}


function fileStem(){
	input=$1

	
	if [ -z "$input" ]; then exit;fi
	
	
	stem=$(basename $input)
# remove compress info
	stem=$( echo $stem | sed 's%\.bz$%%' | sed 's%\.gz$%%'  | sed 's%\.zip$%%' | sed 's%\.bz2$%%' )
# remove paired end info
	stem=$(echo $stem| sed 's%_R1%%'| sed 's%_R2%%' )
# remove some file parts that the pipeline adds
	stem=$(echo $stem | sed 's%_name%%'|sed 's%_coord%%'| sed 's%\.name%%'|sed 's%\.coord%%')

	stem=$(echo $stem | sed 's%Aligned.out%%' ) # added by STAR

# remove known extensions
	
	stem=$(echo $stem| sed 's%\.bdg%%'| sed 's%\.wig%%' | sed 's%\.bed%%' | sed 's%\.bigwig%%' )
	stem=$(echo $stem| sed 's%\.fq%%'| sed 's%\.fastq%%')
	stem=$(echo $stem| sed 's%\.sam$%%' | sed 's%\.bam$%%')
	stem=$(echo $stem| sed 's%\.fa$%%'| sed 's%\.fai$%%'| sed 's%\.fna$%%' | sed 's%\.faa$%%')
	stem=$(echo $stem| sed 's%\.bcf$%%'| sed 's%\.vcf$%%')
	stem=$(echo $stem| sed 's%GATK\.%%' )
	stem=$(echo $stem| sed 's%Realign%%'|sed 's%Recalibrate%%' | sed 's%HaplotypeCallerCombinedCalls%%' | sed 's%Haplotype_gvcf%%')
	stem=$(echo $stem| sed 's%VariantRecalibration%%'| sed 's%GenotypeGVCFs%%' | sed 's%SplitNCigarReads%%')
	

	echo $stem	
}

function ingestDirectory(){

	outputDirectory=$1    # this is the directory to ingest
	processDirectory=$2
	if [ -z "$outputDirectory" ];then
		echo "Please provide the full path of a directory to ingest"
		exit 2;
	fi
	
	currentDirectory=$PWD
	echo "Ingesting data in directory $outputDirectory"
	cd $outputDirectory
	
	echo "Updating OODT with the data files"
	
	echo "Ingesting files only"
	run_crawler.sh &> $LSB_JOBID.crawler.log
	rm -f cas-crawler*
	if [ -n "$processDirectory" ]; then
		echo "Ingesting full directories"
		run_crawler.sh $processDirectory &> $LSB_JOBID.crawler.log
	fi
	
	echo "OODT updated successfully"
	
	echo "Staging in data files"
	
	for i in `ls -d $outputDirectory/* | grep -v '/cas-crawler' | grep -v 'lock4filetransfer$'`  ; do
		echo "Staging $i in directory $outputDirectory"
	        if [ -f $i ] ; then
	                stage.pl --operation in --type file  $i 
	        fi
	        if [ -d $i ] ; then
	                stage.pl --operation in --type directory $i 
	        fi
	done
	
	echo "Staging completed successfully"
	cd $currentDirectory

}

function getSecondReadFile(){
	FirstReadFile=$1
	SecondReadFile=$( echo $FirstReadFile | sed 's/_R1.fastq/_R2.fastq/' | sed 's/_1.fastq/_2.fastq/'|sed 's/_R1.fq/_R2.fq/' | sed 's/_1.fq/_2.fq/' | sed 's/_R1.001.fastq/_R2.001.fastq/' | sed 's/read1.fastq/read2.fastq/'| sed 's/read1.fq/read2.fq/')
	
	
	if [ "$FirstReadFile" == "$SecondReadFile" ] ; then
		echo "$SecondReadFile is the same as $FirstReadFile. Either a parsing error or wrong input provided" >&2
		#exit 3
	fi
	echo $SecondReadFile						
					
	
}

# remove front and trailing slashes from directory names

function sanitizeDirectoryName(){
	directoryName=$1
	lastchar="${directoryName: -1}"
	if [ "$lastchar" == "/" ] ; then
		directoryName=${directoryName:0:${#directoryName}-1}
	fi


	firstchar=${directoryName:0:1}
	if [ "$firstchar" == "/" ] ; then
		directoryName=${directoryName:1:${#directoryName}}
	fi
	echo $directoryName
}

# try to find the dataassets id (DAXXXXXXX) or 
#public assets (PDXXXXXXX)


function getDataAssets(){
	directoryName=$1
	
	da=$( echo $directoryName | perl -lne 'print $1 if /\/(DA\d{7})\// or /\/(PD\d{7})\// ' )

	echo $da
}