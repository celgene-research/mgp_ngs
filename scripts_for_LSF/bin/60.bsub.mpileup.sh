#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
inputBam=$1

echo "This script uses the samtools to create a pileup from a single bam file"
echo "which can be further used as input to a variety of subsequent steps"
echo "The output file is gzip compressed"

analysistask=56

stem=$(fileStem $inputBam)

step="mpileup"

initiateJob $stem $step $1
ref=${humanGenomeDir}/genome.fa
inputIdx=$(echo $inputBam| sed 's/bam$/bai/')
cores=$(fullcores) # simply because we want the full node for its disk space
memory=5000

header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-08-19 10:49:41 -0700 (Wed, 19 Aug 2015) $ $Revision: 1628 $
source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step $1


inputBam=\$(stage.pl --operation out --type file  $inputBam)
inputIdx=\$(stage.pl --operation out --type file  $inputIdx)
outputDirectory=\$( setOutput \$inputBam $step )

celgeneExec.pl --analysistask=$step \"\
$samtoolsbin mpileup  -f $ref \$inputBam | gzip > \${outputDirectory}/${stem}.pileup.gz\
\"

if [ \$? != 0 ] ; then
	echo "Failed to execute command"
	exit 1
fi 
ingestDirectory \$outputDirectory
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 

closeJob
" > ${stem}-${step}.bsub

bsub < ${stem}-${step}.bsub


