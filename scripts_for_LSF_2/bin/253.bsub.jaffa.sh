#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
step="JAFFA"
if [ -n "$1" ]
then
	inputFastq1=$1
else
	echo "253.bsub.JAFFA.sh"
	echo "script to distribute JAFFA jobs to the cluster"
	echo "run using the following command format:"
	echo "253.bsub.fusionCatcher.sh <INPUT_FASTQ (for a single sample or the control sample> "
	echo "   if a pair of files is used for input (e.g. XXX_R1.fastq.gz and XXX_R2.fastq.gz)"
	echo "   INPUT_FASTQ will be the first only e.g."
	echo "   253.bsub.fusionCatcher.sh XXX_R1.fastq.gz"
	exit;
fi

checkfile $inputFastq1
stem=$(fileStem $inputFastq1)
inputFastq2=$( getSecondReadFile $inputFastq1 )
analysistask=63

initiateJob $stem $step $1

cores=$(fullcores)


memory=20000
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header


initiateJob $stem $step $1


inputFastq1=\$( stage.pl --operation out --type file  $inputFastq1 )
inputFastq2=\$( stage.pl --operation out --type file  $inputFastq2 )

if [ \"\$inputFastq1\" == \"FAILED\" -o \"\$inputFastq2\" == \"FAILED\"] ; then
	echo "Could not transfer  one of the fastq files"
	exit 1
fi

outputDirectory=\$( setOutput \$inputFastq1 ${step} )

jaffadir=\$(dirname $jaffabin)
fqdir=\$(dirname \$inputFastq1 )
# aligners option include bowtie2, bwa and star, but not blat because it takes extremely long time.
celgeneExec.pl --analysistask ${analysistask} \"$jaffabin run \
-p readLayout='paired' \
-p threads=${cores} \
\$jaffadir/../../JAFFA_hybrid.groovy \
\$fqdir/*.gz \

  \"

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

