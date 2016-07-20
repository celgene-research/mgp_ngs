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
	echo "20.bsub.fusionCatcher.sh <INPUT_FASTQ (for a single sample or the tumor sample> <NORMAL FASTQ>"
	echo "   if a pair of files is used for input (e.g. XXX_R1.fastq.gz and XXX_R2.fastq.gz)"
	echo "   INPUT_FASTQ will be the first only e.g."
	echo "   20.bsub.fusionCatcher.sh XXX_R1.fastq.gz"
	exit;
fi

checkfile $input1
stem=$(fileStem $input1)
input2=$( getSecondReadFile $input1 )
if [ -n "$2" ]
then
	inputControl1=$2
	inputControl2=$( getSecondReadFile $inputControl1 )
fi
analysistask=63

initiateJob $stem $step $1

cores=$(fullcores)


memory=20000
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header


initiateJob $stem $step $1


input1=\$( stage.pl --operation out --type file  $input1 )
input2=\$( stage.pl --operation out --type file  $input2 )
if [ -n "$inputControl1" ] ; then
	inputControl1=\$( stage.pl --operation out --type file  $inputControl1 )
	inputControl2=\$( stage.pl --operation out --type file  $inputControl2 )
	cmdAdd=\" -I \$inputControl1,\$inputControl2 \"
fi

if [ \"\$input1\" == "FAILED" -o \"\$input2\" == "FAILED" -o  \"\$inputControl1\" == "FAILED" -o \"\$inputControl2\" == "FAILED"] ; then
	echo "Could not transfer  one of the fastq files"
	exit 1
fi

outputDirectory=\$( setOutput \$input1 ${step} )

celgeneExec.pl --analysistask ${analysistask} \"$fusioncatcherbin \
-d \$fusioncatcheridx \
-i \${input1},\${input2} \$cmdAdd\
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

