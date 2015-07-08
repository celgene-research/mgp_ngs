#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1
index=$(echo $input|sed 's/bam$/bai/');
analysistask=92
step="Freebayes"
checkfile $input

NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR
stem=$( fileStem $input )

cores=2 # although this process requires only one core we use two in order to make it lighter for I/O
genomeDatabase=${humanGenomeDir}/genome.fa
genomeIndex=$(echo $genomeDatabase | sed 's%.fa%.dict%')
genomeIndex2=${genomeDatabase}.fai

memory=6000
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#BSUB -E \"$scriptDir/../lib/stageReference.sh $step\"
#$Date: 2015-06-01 18:02:35 -0700 (Mon, 01 Jun 2015) $ $Revision: 1524 $
source $scriptDir/../lib/shared.sh

initiateJob $stem $step
set -e

input=\$( stage.pl --operation out --type file  $input )
index=\$( stage.pl --operation out --type file  $index )


genomeDatabase=$genomeDatabase
genomeIndex=${genomeIndex}  
genomeIndex2=${genomeIndex2} 
if [ \$input == \"FAILED\" -o \$genomeDatabase == \"FAILED\" -o \$genomeIndex2 == \"FAILED\" ] ; then
	echo \"Could not transfer \$input\"
	exit 1
fi

outputDirectory=\$( setOutput \$input ${step} )



celgeneExec.pl --analysistask $analysistask \"${freebayesbin}  \
   --vcf \${outputDirectory}/${stem}.${step}.vcf \
   --fasta-reference \${genomeDatabase} \
   --ploidy 2 \
   --standard-filters \
   --min-coverage 3 \${input}\"
 if [ \$? != 0 ] ; then
	echo "Failed to run command"
	exit 1
fi 
ingestDirectory \$outputDirectory
if [ \$? != 0 ] ; then
	echo \"Failed to ingest data\"
	exit 1
fi 

closeJob


"> $stem.$step.bsub

bsub < $stem.$step.bsub
#rm $$.tmp

