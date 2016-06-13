#!/bin/bash

scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
step="Express"
inputBAM=$1

checkfile $inputBAM

analysistask=52
stem=$(fileStem $inputBAM)

step=$step.human

initiateJob $stem $step $1



transcripts=${humanrsemidx}/genome.fa.idx.fa
# for bwa: database=${humanAnnotationDir}/bwaIndex

cores=4
memory=26000
header=$(bsubHeader $stem $step $memory $cores)

echo \
"$header

#$Date: 2015-08-14 13:02:55 -0700 (Fri, 14 Aug 2015) $ $Revision: 1624 $

source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step $1

inputBAM=\$( stage.pl --operation out --type file  $inputBAM )
transcripts=$transcripts

outputDirectory=\$( setOutput \$inputBAM ${step}-transcriptCounts )

#celgeneExec.pl --analysistask ${analysistask} \"bwa mem -a -t $cores \${database}/gencode.pc_transcripts.fa \$inputFQ \$inputFQ2 | samtools view -Sh -F 4 - | samtools sort -n - | express --output-dir \${outputDirectory}/${stem}.express --rf-stranded \$transcripts\"

celgeneExec.pl --analysistask ${analysistask} \"\
$expressbin --output-dir \${outputDirectory}/${stem}.express \
   --rf-stranded \$transcripts \${inputBAM} \
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
	
closeJob
	"> ${stem}.${step}.${suffix}.bsub

bsub < ${stem}.${step}.${suffix}.bsub


#rm $$.tmp

