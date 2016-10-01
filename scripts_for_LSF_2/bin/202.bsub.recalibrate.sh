#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1
index=$(echo $input|sed 's/bam$/bai/');
analysistask=93
step="GATK.Recalibrate"

# TODO:
# one important note for WES data. We need to use the -L option to restrict the analysis of BQSR only in the target regions


NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR
stem=$( fileStem $input )

initiateJob $stem $step $1
output=${stem}.${step}.bam
cores=$(fullcores) # although this process requires only one core we use two in order to make it lighter for I/O and make sure there is enough memory
memory=$(fullmemory)
genomeDatabase=${humanGenomeDir}/genome.fa
genomeIndex=$(echo $genomeDatabase | sed 's%.fa%.dict%') 
genomeIndex2=${genomeDatabase}.fai
knownMuts1=${dbsnp}
knownMuts2=${mills}
knownMuts3=${f1000g_phase1}

header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header


source $scriptDir/../lib/shared.sh

initiateJob $stem $step $1

input=\$( stage.pl --operation out --type file  $input )
index=\$( stage.pl --operation out --type file  $index )
knownMuts1=$knownMuts1
knownMuts2=$knownMuts2 
knownMuts3=$knownMuts3 
genomeDatabase=$genomeDatabase 
genomeIndex=${genomeIndex} 
genomeIndex2=${genomeIndex2} 


if [ \$input == \"FAILED\" -o \$genomeDatabase == \"FAILED\" -o \$knownMuts1 == \"FAILED\"  ] ; then
	echo \"Could not transfer \$input\"
	exit 1
fi

outputDirectory=\$( setOutput \$input ${step} )




celgeneExec.pl --analysistask $analysistask \"java -Xmx${memory}m -jar ${gatkbin} -T BaseRecalibrator \
-R \${genomeDatabase} \
-knownSites \${knownMuts1} \
-knownSites \${knownMuts2} \
-knownSites \${knownMuts3} \
-I \${input} \
-dt ALL_READS -dfrac 0.10 \
-o \${outputDirectory}/${stem}.base_recal ; \
java -Xmx${memory}m -jar ${gatkbin} -T PrintReads \
-I \${input}  \
-R \${genomeDatabase} \
-BQSR \${outputDirectory}/${stem}.base_recal \
-o \${outputDirectory}/${output}\"



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

