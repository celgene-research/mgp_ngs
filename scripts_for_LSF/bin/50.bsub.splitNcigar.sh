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

#$Date: 2015-10-14 07:44:57 -0700 (Wed, 14 Oct 2015) $ $Revision: 1704 $
source $scriptDir/../lib/shared.sh

initiateJob $stem $step $1
input=\$( stage.pl --operation out --type file  $input )
index=\$( stage.pl --operation out --type file  $index )
genomeDatabase=$genomeDatabase 
genomeIndex=${genomeIndex}  
genomeIndex2=${genomeIndex2} 

outputDirectory=\$( setOutput \$input ${step} )


# check the baseline for quality and append the command --fix_misencoded_quality_scores
base=\$( $samtoolsbin view \${input} | head -1000 | checkQualityEncoding.pl)
if [ \"\${base}\" == \"64\" ] ; then
fixQual=\" --fix_misencoded_quality_scores \"
else
fixQual=\"\"
fi


celgeneExec.pl --analysistask $analysistask \"java -Xmx${memory}m -jar ${gatkbin} \
  -T SplitNCigarReads \
  -R \${genomeDatabase}  \
  $fixQual \
  -I \${input} \
  -o \${outputDirectory}/${stem}.split.bam \
  -rf ReassignOneMappingQuality \
  -RMQF 255 -RMQT 60 \
  -U ALLOW_N_CIGAR_READS \
  -L chr1 -L chr2 -L chr3 -L chr4 -L chr5 -L chr6 -L chr7 -L chr8 -L chr9 -L chr10 -L chr11 -L chr12 \
  -L chr13 -L chr14 -L chr15 -L chr16 -L chr17 -L chr18 -L chr19 -L chr20 -L chr21 -L chr22 -L chrX -L chrY \"
 if [ \$? != 0 ] ; then
	echo \"Failed to run command\"
	exit 1
fi 


ingestDirectory \$outputDirectory
if [ \$? != 0 ] ; then
	echo \"Failed to ingest data\"
	exit 1
fi 

closeJob
"> ${stem}.${step}.$( getStdSuffix ).bsub

bsub < ${stem}.${step}.$( getStdSuffix ).bsub
#rm $$.tmp

