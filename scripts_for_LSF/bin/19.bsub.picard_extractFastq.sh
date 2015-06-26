#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1
analysistask=75
step="ExtractFastq"
stem=$( fileStem $input )

export NGS_LOG_DIR=${NGS_LOG_DIR}/${step}

cores=1
memory=6000
mkdir -p $NGS_LOG_DIR

header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-06-01 18:05:45 -0700 (Mon, 01 Jun 2015) $ $Revision: 1529 $
initiateJob $stem $step
set -e


input=\$( stage.pl --operation out --type file  $input )
if [ \$input == \"FAILED\" ] ; then
	
	echo \"Could not transfer \$input\"
	exit 1
fi

outputDirectory=\$( setOutput \$input fastq )


celgeneExec.pl --analysistask $analysistask \"java -Xmx6g -jar ${PICARD_BASE}/picard.jar SamToFastq INPUT=\${input} \
  FASTQ=\${outputDirectory}/${stem}_R1.fastq \
  SECOND_END_FASTQ=\${outputDirectory}/${stem}_R2.fastq \
  UNPAIRED_FASTQ=\${outputDirectory}/${stem}_unpaired.fastq  \
  INCLUDE_NON_PF_READS=TRUE TMP_DIR=\${NGS_TMP_DIR} VERBOSITY=WARNING  \
  VALIDATION_STRINGENCY=SILENT ; \
$makepairedreads --input \${outputDirectory}/${stem}_unpaired.fastq  \
  --output1 \${outputDirectory}/${stem}_R1.fastq \
  --output2 \${outputDirectory}/${output2}; rm \${outputDirectory}/${stem}_R2.fastq ; \
gzip \${outputDirectory}/${stem}_R1.fastq ; gzip \${outputDirectory}/${stem}_R2.fastq \" 
if [ $? != 0 ] ; then
	echo \"Failed to execute command\"
	exit 1
fi 

ingestDirectory \$outputDirectory
if [ $? != 0 ] ; then
	echo \"Failed to ingest data\"
	exit 1
fi 


closeJob
	"> $stem.$step.bsub

bsub < $stem.$step.bsub
#rm $$.tmp

