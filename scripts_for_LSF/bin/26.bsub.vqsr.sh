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
resource2=${f1000g_omni_gatk}
resource3=${f1000g_snps_gatk}
resource4=${dbsnp}
resource5=${mills}
memory=6000
experimentType=$(ngs-sampleInfo.pl $inputVCF experiment_type);
if [[  \"$experimentType\" =~ ^DNA-Seq ]] ; then
echo "The input file comes from a DNA-Seq experiment and VariantRecalibration (VQSR) will be used"
elif [[ \"$experimentType\" =~ ^RNA-Seq ]] ; then

echo "The input file comes from a RNA-Seq experiment and VariantFiltration will be used"
fi
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-10-12 17:58:48 -0700 (Mon, 12 Oct 2015) $ $Revision: 1697 $
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

outputDirectory=\$( setOutput \$inputVCF ${step} )


## -an InbreedingCoeff is an option suggested by GATK best practices but in all cases I have tried
#  it gives me the error:
# Bad input: Values for InbreedingCoeff annotation not detected for ANY training variant in the input callset.
if [[  \"$experimentType\" =~ ^DNA-Seq ]] ; then

celgeneExec.pl --analysistask $analysistask \"\
java -Xmx${memory}m -jar ${gatkbin} \
   -T VariantRecalibrator \
   -R \${genomeDatabase} \
   -input \${inputVCF} \
   -recalFile \${outputDirectory}/${stem}.vqsr-snp.recal \
	-tranche 100.0 -tranche 99.9 -tranche 99.0 -tranche 90.0 \
   -tranchesFile \${outputDirectory}/${stem}.tranches \
   -rscriptFile \${outputDirectory}/$stem.snp.R \
   -resource:hapmap,known=false,training=true,truth=true,prior=15.0 \${resource1} \
   -resource:omni,known=false,training=true,truth=true,prior=12.0 \${resource2} \
   -resource:1000G,known=false,training=true,truth=false,prior=10.0 \${resource3} \
   -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 \${resource4} \
   -an MQRankSum -an ReadPosRankSum -an FS -an MQ -an DP -an QD -an SOR  \
   -mode SNP ;\
java -Xmx${memory}m -jar ${gatkbin} \
   -T ApplyRecalibration \
   -R \${genomeDatabase} \
   -input \${inputVCF} \
   -mode SNP \
   -ts_filter_level 99.0 \
   -tranchesFile \${outputDirectory}/${stem}.tranches \
   -recalFile \${outputDirectory}/${stem}.vqsr-snp.recal \
   --out \${outputDirectory}/${stem}.snp.vcf ; \
java -Xmx${memory}m -jar ${gatkbin} \
   -T VariantRecalibrator \
   -R \${genomeDatabase} \
   -input \${outputDirectory}/${stem}.snp.vcf \
   -recalFile \${outputDirectory}/${stem}.vqsr-indel.recal \
   -tranche 100.0 -tranche 99.9 -tranche 99.0 -tranche 90.0 \
   -tranchesFile \${outputDirectory}/${stem}.tranches \
   -rscriptFile \${outputDirectory}/$stem.snp.R \
   -resource:mills,known=false,training=true,truth=true,prior=12.0 \${resource5} \
   -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 \${resource4} \
   -an MQRankSum -an ReadPosRankSum -an FS -an DP -an QD -an SOR -an ReadPosRankSum \
   --maxGaussians 4 \
   -mode INDEL ; \
java -Xmx${memory}m -jar ${gatkbin} \
   -T ApplyRecalibration \
   -R \${genomeDatabase} \
   -ts_filter_level 99.0 \
-input \${outputDirectory}/${stem}.snp.vcf \
   -mode INDEL \
   -tranchesFile \${outputDirectory}/${stem}.tranches \
   -recalFile \${outputDirectory}/${stem}.vqsr-indel.recal  \
	--out \${outputDirectory}/${stem}.vqsr.vcf  \"  

if [ \$? != 0 ] ; then
	echo "Failed to run command"
	exit 1
fi 

elif [[ \"$experimentType\" =~ ^RNA-Seq ]] ; then
celgeneExec.pl --analysistask $analysistask \"\
java -Xmx${memory}m -jar ${gatkbin} \
 	-T VariantFiltration \
	-R  \${genomeDatabase} \
	-V \${inputVCF} \
	-window 35 \
	-cluster 3 \
	-filterName FS \
	-filter 'FS > 30.0' \
	-filterName QD \
	-filter 'QD < 2.0'\
	-o \${outputDirectory}/${stem}.varfilt.vcf \"

if [ \$? != 0 ] ; then
	echo "Failed to run command"
	exit 1
fi 
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

