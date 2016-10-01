#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
inputBAM=$1
stem=$(fileStem $inputBAM )
step="GATK.Haplotype_gvcf"
analysistask=94
NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR
initiateJob $stem $step $1
output=${stem}.g.vcf
genomeDatabase=${humanGenomeDir}/genome.fa
genomeIndex=$(echo $genomeDatabase | sed 's%.fa%.dict%') 
genomeIndex2=${genomeDatabase}.fai
knownMuts1=${dbsnp}
memory=28000
experimentType=$(ngs-sampleInfo.pl $inputBAM experiment_type);
cores=$(fullcores)
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

source $scriptDir/../lib/shared.sh

initiateJob $stem $step $1



genomeDatabase=$genomeDatabase
genomeIndex=$genomeIndex 
genomeIndex2=$genomeIndex2
knownMuts1=$knownMuts1
if [ \$genomeDatabase == \"FAILED\" -o \$knownMuts1 == \"FAILED\" ] ; then
	echo \"Could not transfer \$input\"
	exit 1
fi
index=\$( echo $inputBAM | sed 's/bam$/bai/' ) 
index=\$( stage.pl --operation out  --type file \$index )
inputBAM=\$(stage.pl --operation out --type file  $inputBAM )


outputDirectory=\$( setOutput \$inputBAM ${step} )




if [[  \"$experimentType\" =~ ^DNA-Seq ]] ; then
	
celgeneExec.pl --analysistask $analysistask \"\
java -Xmx${memory}m -jar ${gatkbin} \
-T HaplotypeCaller \
-R \${genomeDatabase} \
-I \${inputBAM} \
--dbsnp \${knownMuts1} \
-stand_call_conf 30  \
-stand_emit_conf 10  -o \${outputDirectory}/${output} \
--max_alternate_alleles 20 \
-minPruning 2  \
--emitRefConfidence GVCF \
--variant_index_type LINEAR \
--variant_index_parameter 128000 \
-nct $cores \"
if [ \$? != 0 ] ; then
	echo \"Failed to run command\"
	exit 1
fi 
elif [[ \"$experimentType\" =~ ^RNA-Seq ]] ; then
celgeneExec.pl --analysistask $analysistask \"\
java -Xmx${memory}m -jar ${gatkbin} \
-T HaplotypeCaller \
-R \${genomeDatabase} \
-I \${inputBAM} \
--max_alternate_alleles 20 \
-stand_call_conf 20  \
-stand_emit_conf 20 \
-recoverDanglingHeads \
-dontUseSoftClippedBases  \
-o \${outputDirectory}/${output} \
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

