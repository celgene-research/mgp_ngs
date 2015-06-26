#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
inputVCF=$1

analysistask=95
step="GATK.VariantRecalibration"
stem=$( fileStem $inputVCF )

NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR
output=${stem}.${step}
cores=2 # although this process requires only one core we use two in order to make it lighter for I/O
genomeDatabase=${humanGenomeDir}/genome.fa
genomeIndex=$(echo $genomeDatabase | sed 's%.fa%.dict%') 
genomeIndex2=${genomeDatabase}.fai
resource1=${hapmap_gatk}
resource2=${1000g_omni_gatk}
resource3=${1000g_snps_gatk}
resource4=${dbsnp_gakt}
resource5=${mills}
memory=6000

header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#BSUB -E \"$scriptDir/../lib/stageReference.sh $step\"
#$Date: 2015-06-01 18:02:35 -0700 (Mon, 01 Jun 2015) $ $Revision: 1524 $
source $scriptDir/../lib/shared.sh

initiateJob $stem $step
set -e

inputVCF=\$( stage.pl --operation out --type file  $inputVCF )
genomeDatabase=$genomeDatabase
genomeIndex=$genomeIndex
genomeIndex2=$genomeIndex2
resource1=$resource1
resource2=$resource2
resource3=$resource3
resource4=$resource4
resource5=$resource5
if [ \$inputVCF == \"FAILED\" -o \$genomeDatabase == \"FAILED\" -o \$resource1 == \"FAILED\" -o  \$resource2 == \"FAILED\" -o  \$resource3 == \"FAILED\" -o  \$resource4  == \"FAILED\" ]; then
	echo \"Could not transfer \$inputVCF\"
	exit 1
fi

outputDirectory=\$( setOutput \$inputVCF GATK-${step} )




celgeneExec.pl --analysistask $analysistask \"${gatkbin} \
   -T VariantRecalibrator \
   -R \${genomeDatabase} \
   -input \${inputVCF} \
   -recalFile \${outputDirectory}/${stem}.vqsr-snp.recal \
   -tranchesFile \${outputDirectory}/${stem}.tranches \
   -rscriptFile \${outputDirectory}/$stem.snp.R \
   -resource:hapmap,known=false,training=true,truth=true,prior=15.0 \${resource1} \
   -resource:omni,known=false,training=true,truth=true,prior=12.0 \${resource2} \
   -resource:1000G,known=false,training=true,truth=false,prior=10.0 \${resource3} \
   -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 \${resource4} \
   -an MQRankSum -an ReadPosRankSum -an FS -an MQ -an DP -an QD -mode SNP ;\
${gatkbin} \
   -T VariantRecalibrator \
   -R \${genomeDatabase} \
   -input \${inputVCF} \
   -recalFile \${outputDirectory}/${stem}.vqsr-indel.recal \
   -tranchesFile \${outputDirectory}/${stem}.tranches \
   -rscriptFile \${outputDirectory}/$stem.snp.R \
   -resource:mills,known=false,training=true,truth=true,prior=12.0 \${resource5} \
   -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 \${resource4} \
   -an MQRankSum -an ReadPosRankSum -an FS -an DP -an QD \
   --maxGaussians 4 \
   -mode INDEL ; \
${gatkbin} \
   -T ApplyRecalibration \
   -R \${genomeDatabase} \
   -input \${inputVCF} \
   -mode SNP \
   -ts_filter_level 99.5 \
   -tranchesFile \${outputDirectory}/${stem}.tranches \
   -recalFile \${outputDirectory}/${stem}.vqsr-snp.recal \
   --out \${outputDirectory}/${stem}.snp.vcf ; \
${gatkbin} \
   -T ApplyRecalibration \
   -R \${genomeDatabase} \
   -ts_filter_level 99.0 \
   -input \${inputVCF} \
   -mode INDEL \
   -tranchesFile \${outputDirectory}/${stem}.tranches \
   -recalFile \${outputDirectory}/${stem}.vqsr-indel.recal  \
   --out \${outputDirectory}/${stem}.indel.vcf  \"  
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

