#!/bin/bash


# script that does some preparation for an NGS pipeline script
# sets the log directory
# sets the temp directory
# sets the log file 
declare -A queues
declare -A queueMem
declare -A queueCores
declare -A queueDisk
declare queue_name
# queue     instance type: cores, RAM, scratch space
# normal  = c3.4xlarge:16cores, 30GB RAM, 2 x 160 HD 
# bigdisk = i2.2xlarge: 8cores, 61GB RAM, 2 x 800 HD 
# bigmem  = r3.2xlarge: 8cores, 61GB RAM, 1 x 160 HD
# hugemem = r3.4xlarge:16cores,	122GB RAM, 1 x 320 HD
queueCores["normal"]=16
queueCores["bigdisk"]=8
queueCores["bigmem"]=8
queueCores["hugemem"]=16
queueCores["small"]=16
queueMem["normal"]=30
queueMem["bigdisk"]=61
queueMem["bigmem"]=61
queueMem["hugemem"]=122
queueMem["small"]=61
queueDisk["normal"]=320
queueDisk["bigdisk"]=1600
queueDisk["bigmem"]=160
queueDisk["hugemem"]=320
queueDisk["small"]=320


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
	
	NGS_LOG_DIR=$(echo $NGS_LOG_DIR | sed 's|//|/|g' )

	
	# to avoid overwhelming the fileserver store the logs locally on the node
	# and transfer them to the logs directory when the job finishes
	if [ -n "${LSB_JOBID} ] ; then
		FINAL_LOG_DIR=$NGS_LOG_DIR
		NGS_LOG_DIR=$NGS_TMP_DIR/LOGS/${LSB_JOBID}
		export FINAL_LOG_DIR
	fi	
	mkdir -p $NGS_LOG_DIR
	export NGS_LOG_DIR
	echo "Logging: Created directory $NGS_LOG_DIR" 1>&2
	if [ -z "$LSB_ERRORFILE" ] ; then
		export LSB_ERRORFILE=${NGS_LOG_DIR}/${LSB_JOBID}.stderr
	fi
	export MASTER_LOGFILE=${NGS_LOG_DIR}/$( basename $LSB_ERRORFILE | sed 's/bsub.stderr/log/' )
	export STAGEFILE_LOGFILE=${MASTER_LOGFILE}
	export CELGENE_EXEC_LOGFILE=${MASTER_LOGFILE}
	if [ -e $CELGENE_EXEC_LOGFILE ] ; then
			rm -f $CELGENE_EXEC_LOGFILE	
	fi
	echo "Logging: Log directory is set to : " $NGS_LOG_DIR  1>&2
	echo "Logging: Master log file is set to $MASTER_LOGFILE" 1>&2
	echo "Logging: Stage file is set to $STAGEFILE_LOGFILE" 1>&2
	echo "Logging: CelgeneExec log file is set to $CELGENE_EXEC_LOGFILE" 1>&2
	echo "Logging: desired queue for this job is $queue_name" 1>&2
	echo "Logging: max CPU for this queue is set to ${queueCores[$queue_name]}"  1>&2
	echo "Logging: max memory (MB) for this queue is set to ${queueMem[$queue_name]}" 1>&2 
	echo "Logging: Instance type is "$( curl http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null ) 1>&2
	echo "Logging: Node available disk space "	1>&2
	df -h  1>&2
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
	#if [ -n "$LSB_JOB_ID" ] ; then
		NGS_TMP_DIR=${NGS_TMP_DIR_ORIGINAL}/${step}/${LSB_JOBID}
	#else
		#	NGS_TMP_DIR=${NGS_TMP_DIR_ORIGINAL}/${step}/TMP_$$
	#fi
	export NGS_TMP_DIR
	mkdir -p $NGS_TMP_DIR
}


# get the scheduler type
function getScheduler(){
	clusterString=$(lsid| head -1)
	clusterString=$(echo $clusterString | tr '[:upper:]' '[:lower:]')
if [[ "$clusterString" =~ 'lsf' ]]
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

# get the queue name based on the application running
function getQueue(){
	step=$1

# assotiative array to place all the known steps and their requirements in queues

	
	queues["ExtractFastqBed"]="bigdisk"
	queues["ExtractFastq"]="normal"
	queues["GATK.GenotypeGVCFs"]="bigdisk"
	queues["GATK.VariantRecalibration"]="bigdisk"
	queues["GATK.Mutect2"]="bigdisk"
	queues["mpileup"]="bigdisk"
	queues["controlFreec.human"]="bigdisk"
	queues["STARaln.xenograft"]="bigmem"
	queues["MarkDuplicates"]="bigmem"
	queues["LibraryComplexity"]="bigmem"
	queues["BWAmem"]="bigmem"
	queues["Bismark"]="bigdisk"
	queues["BismarkExtractor"]="bigdisk"
	queues["HomerQC"]="bigdisk"
	queues["MACS2"]="bigdisk"
	queues["Bowtie2.human"]="bigmem"
	queues["STARaln.human"]="bigmem"

# decide the queue -
# in the future perhaps a more sophisticated method will be used to take into consideration
#       the size of the input file
if [ ${queues["${step}"]+_} ] ; then
		queue_name=${queues["${step}"]}
	else
		queue_name="normal"
	fi
	if [ -n "$NGS_QUEUE" ] ; then
		echo "User specified queue set to $NGS_QUEUE" 1>&2
		queue_name="$NGS_QUEUE"
	fi
	echo "getQueue: queue is set to $queue_name" 1>&2
	echo $queue_name
}


# return the string that goes at the top of a bsub script with
# the name of teh job, stderr and stdout etc
function bsubHeader(){
	stem=$1
	step=$2	
	memory=$3
	cores=$4

#echo "bsubHeader: stem=$stem, step=$step, memory=$memory, cores=$cores" 1>&2

	if [ -z "$cores" ]; then
		cores=1
	fi
	
	if [ -z "$NGS_CORE_FACTOR" ] ; then
		NGS_CORE_FACTOR=4
	fi
	
    expectedSize=$(( $filesize * $NGS_CORE_FACTOR ))
    echo "The expected size of this job on the disk is $expectedSize" 1>&2
    allocatedSize=$(( ${queueDisk[${queue_name}]} / ${queueCores[${queue_name}]}  ))
    allocatedSize=$(( $allocatedSize * $cores ))
    echo "The allocated size of this job on the disk is $allocatedSize" 1>&2
    if [ "$expectedSize" -gt "$allocatedSize" ] ; then
            echo "The expected disk footprint of the job is $expectedSize and the allocated based on the queue type is $allocatedSize" 1>&2

            fraction=$( echo "${queueDisk[${queue_name}]}/ $expectedSize" | bc -l )

            coresFraction=$( echo "${queueCores[$queue_name]}/$fraction" | bc -l )
            cores=$(printf "%.0f" $coresFraction)
            echo "The number of requested cores will need to be changed to $cores" 1>&2
    fi
		
	
	#if the requested cores are more than the cores the system can provide
	# then downsize to as many cores the node has
	fc=$( fullcores )
	if [ "$cores" -gt "$fc" ] ; then
		cores=$fc
		echo "The requested cores $cores is larger than what the system can provide $fc. Reverting to $fc" 1>&2
	fi 
	
	
	
	if [ -z "$memory" ]; then 
		memory=$(( 4000*$cores))
		echo "Since memory wasn not provided setting to $memory" 2>&1
	fi
	
	fm=$( fullmemory )
	if [ "$memory" -gt "$fm" ] ; then
		memory=$fm
		echo "The requested memory $memory is larger than what the system can provide $fm. Reverting to $fm" 1>&2
	fi


	mem=$(res_memory $memory $cores)
	
	
#echo "bsubHeader: stem=${stem}, \
#step=${step}, \
#memory=${memory}, mem=${mem}\
#cores=${cores}" >&2
suffix=$( getStdSuffix $step )
echo "#!/bin/bash"
echo "#BSUB -e ${NGS_LOG_DIR}/${stem}.${step}.${suffix}.bsub.stderr"
echo "#BSUB -o ${NGS_LOG_DIR}/${stem}.${step}.${suffix}.bsub.stdout"
echo "#BSUB -J ${stem}.${step}.bsub"
echo "#BSUB -r"
echo "#BSUB -E \"$scriptDir/../lib/stageReference.sh $step\""
echo "#BSUB -q \"${queue_name}\""
echo "#BSUB -n $cores"
echo "#BSUB -R \"span[ptile=$cores] rusage[mem=$mem]\" "
echo "scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh"
echo "trap closeJob EXIT SIGTERM"
echo "set -e"
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
		cutoff=$(( $suffix + 10800 ))
		if (( $cutoff < $(date +%s) )) ; then
			touch ${step}_suffixer
			suffix=$( stat -c %Y ${step}_suffixer )
		fi
	fi
	

	
echo $suffix

	
	

}

function fullcores(){
	#	if [ -z "$queue_name" ] ;then
	#		echo "Queue name is not defined for this step. Has the job been initiated in the bsub script?" &>2
	#	echo 'Check if line "initiateJob $stem $step $1" appears in the script before the line header=$(bsubHeader $stem $step $memory $cores)' &>2
	#	exit
	#   fi
	maxCores=11 
	instanceCores=${queueCores[$queue_name]}
	if [ "$NEWCLUSTER" == "1" ] ; then
		fc=$maxCores
		#echo "fullCores: Setting max core usage to $maxCores on NEWCLUSTER" 1>&2
	else
		fc=${instanceCores}
		#echo "fullCores: Setting max core usage to $instanceCores on queue $queue_name" 1>&2
	fi
	
	if [ -n "$NGS_CORE_NUM" ] ; then
		fc=${NGS_CORE_NUM}
	fi
	 
	echo $fc				
							
}

function fullmemory(){

	#memory on head node
	maxMem=$(free | awk '/^Mem:/{print $2}')
	maxMem=$(( $maxMem - 4000 ))
	#memory on instance
	instanceMem=${queueMem[$queue_name]}
	instanceMem=$(( $instanceMem * 1000 - 4000 ))

	var=$instanceMem
	
	if [ -n "$NGS_MAXMEM_NUM"  ] ; then
		var=${NGS_MAXMEM_NUM}
	fi
	echo $var
	
}

function initiateJob(){
	stem=$1
	step=$2
	filename=$3
	
	da=$( getDataAssets $filename  )
	getQueue $step 


	  setLogging $stem $step $da
	  setTemp $step			
	
	# get the size of the file
	bname=$(basename $filename)
	filesize=$(aws s3 ls $filename | grep ${bname}$ |  awk -v N=$3 '{print $3}' )
#echo "Filesize for file $filename is $filesize"
	filesize=$(( $filesize / 1000000000 ))
	echo "###############################"
	echo -n "Starting job at " 
	date
	echo "on host " $(hostname)
	if [ -f $LSB_ERRORFILE ] ;then
		rm -f $LSB_ERRORFILE
	
	fi
		
	#echo "initiateJob: Setting environment for this job" 2>&1
	#echo "stem=$step, step=$step, filename=$filename" 2>&1
	#echo "da=$da, queue=$queue_name" 2>&1
}

function closeJob(){
	echo "Closing job " 1>&2
	df -h  1>&2
	
	cp -r $NGS_LOG_DIR/* $FINAL_LOG_DIR/
	
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
	
	local newDirectoryName=$(  echo ${directoryName}  | sed 's%/SRC%/Processed%'| sed 's%/src%/Processed%'| sed 's%/RawData%/Processed%' | sed 's%/Raw_Data%/Processed%'| sed 's%/rawdata%/Processed%' | sed 's%/raw_data%/Processed%' | sed 's%/OriginalData%/ProcessedData%' )
	
	echo $newDirectoryName
}



# input is the name of the input file
# newDir is the name of the directory that will hold the results (e.g. contains the processing step)
function setOutput(){
	input=$1
	newDir=$2
	skipmkdir=$3
	
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

	if [ -n "$skipmkdir" ] ; then
		echo "Output directory $outputDirectory will not be created" 1>&2
	else
		mkdir -p $outputDirectory
	fi
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
	
	if [ -n "${NGS_STEM_DISPLAYNAME}" ] ; then
		stem=$( ngs-sampleInfo.pl $input display_name )
	fi

	echo $stem	
}



# process Directory can be eiher
# blank (NULL) which means that the script will process all files in the directory
# 'yes' which means that will ingest the directory as a whole
# 'r
function ingestDirectory(){

	local outputDirectory=$1    # this is the directory to ingest
	local processDirectory=$2
	if [ -z "$outputDirectory" ];then
		echo "Please provide the full path of a directory to ingest"
		exit 2;
	fi
	
	local currentDirectory=$PWD
	echo "Ingesting data in directory $outputDirectory"
	cd $outputDirectory
	
	echo "Updating OODT with the data files"
	if [ "$processDirectory" == "recursive" ]; then
		echo "Ingesting subdirectories recursively"
		for subdir in `find $1 -type d` ; do
			ingestDirectory $subdir none
		done 
	fi
	
	# Ingesting only files. Run the script run_crawler.sh and store the output
	# in a log file in the outputDirectory with the lsf job id as prefix
	echo "Ingesting files only"
	run_crawler.sh &> $LSB_JOBID.crawler.log
	rm -f cas-crawler*
	# Ingesting the contents of a directory. Run the script run_crawler.sh and store the output
	# in a log file in the outputDirectory with the lsf job id as prefix	
	if [ "$processDirectory" == "yes" ]; then
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
