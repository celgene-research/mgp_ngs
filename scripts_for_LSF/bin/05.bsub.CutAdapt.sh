#!/bin/bash

# Script that runs the cutadapt tool
# it was modified on May 20 2015 to run the latest stable release of cutadap v1.8.1
# as it stands it removes the Illumina adaptors from the sequence reads and produces a qcstats file
# with the statistics.
# By default the script does  produce fastq files with trimmed reads
# it the user wants not to, the script needs to be called with a second argument "no" whcih will
# force it to produce trimmed fastq files.
# e.g.
# 05.bsub.CutAdapt test.R1.fq.gz no
#    will run cutadapt on the files test.R1.fq.gz and test.R2.fq.gz (if present) and produce the statistics only
#
# 05.bsub.CutAdapt test.R1.fq.gz yes OR just 05.bsub.CutAdapt test.R1.fq.gz
#    will run cutadapt on the files test.R1.fq.gz and test.R2.fq.gz (if present) and produce the statistics and the trimmed fastq files

scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1
input2=$( getSecondReadFile $input)
storeOutput=$2
if [ ! -n "$storeOutput" ] ; then
	echo "The trimmed fastq files will be saved for further processing"
	storeOutput="yes"
fi 
 
analysistask=48
checkfile $input

readPE=$(ngs-sampleInfo.pl  $input paired_end )
if [ "$readPE" == "1" ] ; then
checkfile $input2
fi

#for step in MarkDuplicates CollectAlnSummary CollectInsertSize CollectRNASeqMetrics BamIndex LibraryComplexity
step="CutAdapt"
stem=$(fileStem $input)

memory=8000
cores=4 # one for cutadapt and 3 for gzip processes



export NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-06-01 18:04:39 -0700 (Mon, 01 Jun 2015) $ $Revision: 1527 $
source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step

input=\$( stage.pl --operation out --type file  $input )
if [ \"${readPE}\" == \"1\" ]; then
	input2=\$( stage.pl --operation out --type file  $input2)
fi



outputDirectory=\$( setOutput \$input fastqQC/${step} )

output1=\${outputDirectory}/${stem}.${step}.qcstats
if [ \"$storeOutput\" == \"yes\" ] ; then
	outputDirectory2=\$( setOutput \$input FastqFiles-${step} )
	outputfq1=\$(basename \$input   )

	outputfq1=\${outputDirectory2}/\${outputfq1}
	if [ \"${readPE}\" == \"1\" ]; then
		outputfq2=\${outputDirectory2}/\${outputfq2}
		outputfq2=\$(basename \$input2  )
	fi
else
	outputfq1=\"/dev/null\"
	if [ \"${readPE}\" == \"1\" ]; then
		outputfq2=\"/dev/null\"
	fi
fi

# command for paired end sequences
if [ \"${readPE}\" == \"1\" ]; then 
	adapterCMD1=\" -a AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC -A AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGTAGATCTCGGTGGTCGCCGTATCATT  \"
celgeneExec.pl --analysistask ${analysistask} \"\
$cutadaptbin \
  --format=fastq \
  -o \${outputfq1} \
  -p \${outputfq2} \
  -a AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC -A AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGTAGATCTCGGTGGTCGCCGTATCATT \
  \${input} \${input2}>\
  \${output1} \" 
else
	adapterCMD1=\" -a AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC  \"
celgeneExec.pl --analysistask ${analysistask} \"\
$cutadaptbin \
  --format=fastq \
  -o \${outputfq1} \
  -a AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC  \
  \${input} >\
  \${output1} \" 
fi


# command for single end sequences
#celgeneExec.pl --analysistask ${analysistask} \"$binary -o /dev/null $adapterCMD2 ${input2} >> \${output1}\" 


runQC-fastq.pl --logfile \$MASTER_LOGFILE --inputfq \${input},\${input2} --outputfile \${output1} --reuse --qcStep Adapter
if [ \$? != 0 ] ; then
	echo "Failed to update database"
	exit 1
fi 

ingestDirectory \${outputDirectory}
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 
rm -rf \${outputDirectory} 

ingestDirectory \${outputDirectory2}
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 
rm -rf \${outputDirectory2} 

closeJob


" > ${stem}.${step}.bsub

bsub < ${stem}.${step}.bsub
#rm $$.tmp

