#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
step="FusionCatcher"
if [ -n "$1" ]
then
	inputControl1=$1
else
	echo "20.bsub.fusionCatcher.sh"
	echo "script to distribute fusioncatcher jobs to the cluster"
	echo "run using the following command format:"
	echo "20.bsub.fusionCatcher.sh <INPUT_FASTQ (for a single sample or the control sample> <TUMOR FASTQ>"
	echo "   if a pair of files is used for input (e.g. XXX_R1.fastq.gz and XXX_R2.fastq.gz)"
	echo "   INPUT_FASTQ will be the first only e.g."
	echo "   20.bsub.fusionCatcher.sh XXX_R1.fastq.gz"
	exit;
fi

checkfile $inputControl1
stem=$(fileStem $inputControl1)
inputControl2=$( getSecondReadFile $inputControl1 )

if [ -n "$2" ]
then
	inputTumor1=$2
	inputTumor2=$( getSecondReadFile $inputTumor1 )
	stemB=$(fileStem $inputTumor1)
	stem=${stemB}-${stem}
fi
analysistask=63

initiateJob $stem $step $1

cores=$(fullcores)


memory=20000
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header


initiateJob $stem $step $1


inputControl1=\$( stage.pl --operation out --type file  $inputControl1 )
inputControl2=\$( stage.pl --operation out --type file  $inputControl2 )
cmdAdd=\" -i \${inputControl1},\${inputControl2} \"
if [ -n "$inputTumor1" ] ; then
	inputTumor1=\$( stage.pl --operation out --type file  $inputTumor1 )
	inputTumor2=\$( stage.pl --operation out --type file  $inputTumor2 )
	cmdAdd=\" -i \$inputTumor1,\$inputTumor2 -I \$inputControl1,\$inputControl2 \"
fi

if [ \"\$inputControl1\" == "FAILED" -o \"\$inputControl2\" == "FAILED" -o  \"\$inputTumor1\" == "FAILED" -o \"\$inputTumor2\" == "FAILED"] ; then
	echo "Could not transfer  one of the fastq files"
	exit 1
fi

outputDirectory=\$( setOutput \$inputControl1 ${step} )

celgeneExec.pl --analysistask ${analysistask} \"$fusioncatcherbin \
-d \$fusioncatcheridx \
 \$cmdAdd \
--aligners=star,bowtie2,bwa,blat \
-o \${outputDirectory}/$stem.strvar \
-p ${cores} \
-V  \"

if [ \$? != 0 ] ; then
	echo "Failed to run command"
	exit 1
fi 
ingestDirectory \$outputDirectory yes
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 

rm -rf \$outputDirectory

closeJob

"\
>${stem}.${step}.$( getStdSuffix ).bsub


bsub < ${stem}.${step}.$( getStdSuffix ).bsub
#rm $jobDesc.bsub

