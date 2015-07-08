#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
inputList=$1

analysistask=56

stem=$(fileStem $input)
samtoolsBin=$samtoolsbin
vcfutilsBin=$vcfutilsbin
bcftoolsBin=$bcftoolsibn

step="mpileup"

if [ ! -e $inputList ];then
	echo "Please provide a list of available bam files as input"
fi

for ref in `ls ${humanChromosomesDir}/*.fa`
do
stem2=$(basename $ref | sed 's/.fa//')
NGS_LOG_DIR=${NGS_LOG_DIR}/${step}

cores=1
memory=5000
mkdir -p $NGS_LOG_DIR

header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#BSUB -E \"$scriptDir/../lib/stageReference.sh $step\"
#$Date: 2015-05-22 12:23:19 -0700 (Fri, 22 May 2015) $ $Revision: 1473 $
source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step



outputDirectory=\$( setOutput $inputList $step )

celgeneExec.pl derivedfromlist=$inputList,analysistask=$analysistask \"\
$samtoolsBin mpileup -r $stem -BQ0 -m 3 -F0.01 -C50 -DSuf $ref -R -b $inputList |\
$bcftoolsBin view -cgv - > \${outputDirectory}/${stem}-${stem2}.vcf\"

if [ \$? != 0 ] ; then
	echo "Failed to update database"
	exit 1
fi 
ingestDirectory \$outputDirectory
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 

closeJob
" > ${stem}-${stem2}.{$step}.bsub

bsub < ${stem}-${stem2}.{$step}.bsub

done
