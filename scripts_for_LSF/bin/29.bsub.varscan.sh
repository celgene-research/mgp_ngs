#!/bin/bash
# This script runs Varscan2 on a single bam file
# input to the script is a bam file 
# The script runs varscan for snp and indels and then produces a concatenated and sorted vcf file.


scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1
index=$(echo $input|sed 's/bam$/bai/');
analysistask=92
step="Varscan2"
initiateJob $stem $step $1
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
#$Date: 2015-09-25 08:56:09 -0700 (Fri, 25 Sep 2015) $ $Revision: 1656 $
source $scriptDir/../lib/shared.sh

initiateJob $stem $step $1

input=\$( stage.pl --operation out --type file  $input )
index=\$( stage.pl --operation out --type file  $index )


genomeDatabase=$genomeDatabase
genomeIndex=${genomeIndex} 
genomeIndex2=${genomeIndex2} 
if [ \$input == \"FAILED\" -o \$genomeDatabase == \"FAILED\" -o \$genomeIndex2 == \"FAILED\" -o \$knownMuts1 == \"FAILED\" -o \$knownMuts2 == \"FAILED\" ] ; then
	echo \"Could not transfer \$input\"
	exit 1
fi

outputDirectory=\$( setOutput \$input ${step} )

# check the baseline for quality and append the command --fix_misencoded_quality_scores



# execute the command
# RealignerTargetCreator
# IndelRealigner

celgeneExec.pl --analysistask $analysistask \" \
samtools mpileup -B -f \${genomeDatabase}  \${input} | \
java -Xmx${memory}m -jar ${varscan2bin} mpileup2snp -v --output-vcf 1 > \${outputDirectory}/${stem}.snp.vcf ; \
samtools mpileup -B -f \${genomeDatabase}  \${input} | \
java -Xmx${memory}m -jar ${varscan2bin} mpileup2indel -v --output-vcf 1 > \${outputDirectory}/${stem}.indel.vcf ; \
vcf-concat \${outputDirectory}/${stem}.snp.vcf  \${outputDirectory}/${stem}.indel.vcf | \
vcf-sort -c >  \${outputDirectory}/${stem}.vcf ; \
rm  \${outputDirectory}/${stem}.indel.vcf ; \
rm  \${outputDirectory}/${stem}.snp.vcf  \"
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


"> ${stem}.${step}.$( getStdSuffix ).bsub

bsub < ${stem}.${step}.$( getStdSuffix ).bsub
#rm $$.tmp

