#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
step="FusionCatcher"
if [ -n "$1" ]
then
	input1=$1
else
	echo "20.bsub.fusionCatcher.sh"
	echo "script to distribute fusioncatcher jobs to the cluster"
	echo "run using the following command format:"
	echo "20.bsub.fusionCatcher.sh <INPUT_FASTQ>"
	echo "   if a pair of files is used for input (e.g. XXX_R1.fastq.gz and XXX_R2.fastq.gz)"
	echo "   INPUT_FASTQ will be the first only e.g."
	echo "   20.bsub.fusionCatcher.sh XXX_R1.fastq.gz"
	exit;
fi
checkfile $input1
stem=$(fileStem $input1)
input2=$( getSecondReadFile $input1 )

analysistask=63



export NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR


database=/celgene/software/fusionCatcher/data/current
cores=$(fullcores)


memory=20000
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#BSUB -E \"$scriptDir/../lib/stageReference.sh $step\"
#$Date: 2015-06-01 18:05:20 -0700 (Mon, 01 Jun 2015) $ $Revision: 1528 $


source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step

database=$database
input1=\$( stage.pl --operation out --type file  $input1 )
input2=\$( stage.pl --operation out --type file  $input2 )


if [ \$database == "FAILED" -o \$input1 == "FAILED" -o \$input2 == "FAILED" ] ; then
	echo "Could not transfer either \$database or \$input1 or \$input2"
	exit 1
fi

outputDirectory=\$( setOutput \$input1 ${step} )

celgeneExec.pl --analysistask ${analysistask} \"$fusioncatcherbin \
-d \$database \
-i \${input1},\${input2} \
-o \${outputDirectory}\"

if [ $? != 0 ] ; then
	echo "Failed to run command"
	exit 1
fi 
ingestDirectory \$outputDirectory
if [ $? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 

rm -rf \$outputDirectory

closeJob

"\
>${stem}.${step}.bsub


bsub < ${stem}.${step}.bsub
#rm $jobDesc.bsub

