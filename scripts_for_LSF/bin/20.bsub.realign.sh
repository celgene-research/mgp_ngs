#!/bin/bash

# input to the script is a bam file 
# 4 Mar 2015: Kostas: the script detects the quality coding of the file and adjusts the command line to fix it or not   (--fix_misencoded_quality_scores)


scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1
index=$(echo $input|sed 's/bam$/bai/');
analysistask=92
step="GATK.Realign"

NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR
stem=$( fileStem $input )

cores=2 # although this process requires only one core we use two in order to make it lighter for I/O
genomeDatabase=${humanGenomeDir}/genome.fa
genomeIndex=$(echo $genomeDatabase | sed 's%.fa%.dict%')
genomeIndex2=${genomeDatabase}.fai

knownMuts1=${mills}
knownMuts2=${1000g_phase1}
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
knownMuts1=$knownMuts1
knownMuts2=$knownMuts2

genomeDatabase=$genomeDatabase
genomeIndex=${genomeIndex} 
genomeIndex2=${genomeIndex2} 
if [ \$input == \"FAILED\" -o \$genomeDatabase == \"FAILED\" -o \$genomeIndex2 == \"FAILED\" -o \$knownMuts1 == \"FAILED\" -o \$knownMuts2 == \"FAILED\" ] ; then
	echo \"Could not transfer \$input\"
	exit 1
fi

outputDirectory=\$( setOutput \$input ${step} )

# check the baseline for quality and append the command --fix_misencoded_quality_scores
base=\$( $samtoolsbin view \${input} | head -1000 | checkQualityEncoding.pl)
if [ \"\${base}\" == \"64\" ] ; then
fixQual=\" --fix_misencoded_quality_scores \"
else
fixQual=\"\"
fi



# execute the command
# RealignerTargetCreator
# IndelRealigner

celgeneExec.pl --analysistask $analysistask \"${gatkbin} \
-T RealignerTargetCreator \
$fixQual \
-R \${genomeDatabase} \
-known \${knownMuts1} \
-known \${knownMuts2} \
-I \${input} \
-o \${outputDirectory}/${stem}.intervals ; \
${gatkbin} \
-T IndelRealigner -R \${genomeDatabase} \
-known \${knownMuts1} \
-known \${knownMuts2} \
-I \${input}  \
-targetIntervals \${outputDirectory}/${stem}.intervals \
-o \${outputDirectory}/${stem}.${step}.bam \
$fixQual \"
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


"> $stem.$step.bsub

bsub < $stem.$step.bsub
#rm $$.tmp

