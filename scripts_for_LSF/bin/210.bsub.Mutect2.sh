#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
inputNormalBAM=$1
inputTumorBAM=$2
stem=$(fileStem $inputTumorBAM )
step="GATK.Mutect2"
analysistask=94
NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR
initiateJob $stem $step $1
genomeDatabase=${humanGenomeDir}/genome.fa
genomeIndex=$(echo $genomeDatabase | sed 's%.fa%.dict%') 
genomeIndex2=${genomeDatabase}.fai
knownMuts1=${dbsnp}
cosmicMuts1=${cosmiccoding}
memory=28000
experimentType=$(ngs-sampleInfo.pl $inputNormalBAM experiment_type);
cores=$(fullcores)
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

source $scriptDir/../lib/shared.sh

initiateJob $stem $step $1

indexNormal=\$( echo $inputNormalBAM | sed 's/bam$/bai/' ) 
indexNormal=\$( stage.pl --operation out  --type file \$indexNormal )
inputNormalBAM=\$(stage.pl --operation out --type file  $inputNormalBAM )
indexTumor=\$( echo $inputTumorBAM | sed 's/bam$/bai/' ) 
indexTumor=\$( stage.pl --operation out  --type file \$indexTumor )
inputTumorBAM=\$(stage.pl --operation out --type file  $inputTumorBAM )

outputDirectory=\$( setOutput \$inputTumorBAM ${step} )




	
celgeneExec.pl --analysistask $analysistask \"\
java -Xmx${memory}m -jar ${gatkbin} \
-T MuTect2 \
-R \${genomeDatabase} \
-I:normal \${inputNormalBAM} \
-I:tumor \${inputTumorBAM} \
--dbsnp ${dbsnp} \
--cosmic ${ cosmiccoding }\
--dontUseSoftClippedBases \
--output_mode EMIT_VARIANTS_ONLY \
-o \${outputDirectory}/${stem}.vcf \
--bamOutput \${outputDirectory}/$stem.bam \
--bamWriterType ALL_POSSIBLE_HAPLOTYPES \
-nct $cores \"
if [ \$? != 0 ] ; then
	echo \"Failed to run command\"
	exit 1
fi 
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

