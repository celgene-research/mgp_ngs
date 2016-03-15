#!/bin/bash

echo "This script is running the GenotypeGVCF tool"
echo "it requires as input a file with the list of gvcf filenames to compare"
echo "NOTE: On AWS this script is better to be run on a single node cluster "
echo " since the home directories (where the bsub file is stored) are not shared "
echo " between the nodes"


scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
inputListGVCF=$1
stem=$(fileStem $inputListGVCF )
step="GATK.GenotypeGVCFs"
analysistask=96
NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR
initiateJob $stem $step $1
output=${stem}.${step}.vcf
genomeDatabase=${humanGenomeDir}/genome.fa
genomeIndex=$(echo $genomeDatabase | sed 's%.fa%.dict%') 
genomeIndex2=${genomeDatabase}.fai
memory=7000
cores=$(fullcores)
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header


$scriptDir/../lib/stageReference.sh $step
#$Date: 2015-10-15 17:44:21 -0700 (Thu, 15 Oct 2015) $ $Revision: 1719 $

source $scriptDir/../lib/shared.sh

initiateJob $stem $step $1
set -e

genomeDatabase=$genomeDatabase
genomeIndex=$genomeIndex 
genomeIndex2=$genomeIndex2

if [ \$genomeDatabase == \"FAILED\" ] ; then
	echo \"Could not transfer \$genomeDatabase\"
	exit 1
fi

variantString=\"\"
for f in \`cat $inputListGVCF\`; do
	file=\$( stage.pl --operation out --type file \$f )
	if [ \$file == \"FAILED\"  ] ; then
		echo \"Could not transfer \$file\"
		exit 1
	fi
variantString=\$variantString\" --variant \$file \"
done

outputDirectory=\$( setOutput \$file ${step} )

celgeneExec.pl --analysistask $analysistask \"\
java -Xmx${memory}m -jar ${gatkbin} \
-T GenotypeGVCFs \
-R \${genomeDatabase} \$variantString \
-o \${outputDirectory}/$stem.combined.vcf\"
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

"> $stem.$step.bsub


bash $stem.$step.bsub
#bsub < $stem.$step.bsub
#rm $$.tmp
