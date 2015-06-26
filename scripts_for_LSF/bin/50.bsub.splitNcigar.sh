#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1

checkfile $input
index=$(echo $input|sed 's/bam$/bai/');
analysistask=92
step="GATK.SplitNCigarReads"

NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR
stem=$( fileStem $input )
output=${stem}.${step}.bam
cores=2 # although this process requires only one core we use two in order to make it lighter for I/O
memory=6000


genomeDatabase=${humanGenomeDir}/genome.fa

genomeIndex=$(echo $genomeDatabase | sed 's%.fa%.dict%') 
genomeIndex2=${genomeDatabase}.fai

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
genomeDatabase=\$( stage.pl --operation out --type file  $genomeDatabase )
genomeIndex=\$( stage.pl --operation out --type file ${genomeIndex}  )
genomeIndex2=\$( stage.pl --operation out --type file ${genomeIndex2}  )
if [ \$input == \"FAILED\" -o \$genomeDatabase == \"FAILED\" ] ; then
	echo \"Could not transfer \$input\"
	exit 1
fi

outputDirectory=\$( setOutput \$input ${step} )




celgeneExec.pl --analysistask $analysistask \"${gatkbin} \
  -T SplitNCigarReads \
  -R \${genomeDatabase}  \
  --fix_misencoded_quality_scores \
  -I \${input} \
  -o \${outputDirectory}/${stem}.split.bam \
  -rf ReassignMappingQuality \
  -DMQ 60 \
  -U ALLOW_N_CIGAR_READS \
  -L chr1 -L chr2 -L chr3 -L chr4 -L chr5 -L chr6 -L chr7 -L chr8 -L chr9 -L chr10 -L chr11 -L chr12 \
  -L chr13 -L chr14 -L chr15 -L chr16 -L chr17 -L chr18 -L chr19 -L chr20 -L chr21 -L chr22 -L chrX -L chrY \"
 if [ $? != 0 ] ; then
	echo "Failed to run command"
	exit 1
fi 


ingestDirectory \$outputDirectory
if [ $? != 0 ] ; then
	echo \"Failed to ingest data\"
	exit 1
fi 

closeJob
"> ${stem}.${step}.bsub

bsub < ${stem}.${step}.bsub
#rm $$.tmp

