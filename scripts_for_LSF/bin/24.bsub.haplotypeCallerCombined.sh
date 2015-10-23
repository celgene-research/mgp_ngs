#!/bin/bash

# script to run Haplotype Caller in a combined mode
# input is a file with a list of bam files
# and a bed file with regions to process

scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
inputListBAM=$1

analysistask=94
NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR
stem=$(fileStem $inputListBAM )
step="GATK.HaplotypeCallerCombinedCalls"

output=${stem}.${step}.vcf

genomeDatabase=${humanGenomeDir}/genome.fa
genomeIndex=$(echo $genomeDatabase | sed 's%.fa%.dict%') 
genomeIndex2=${genomeDatabase}.fai
knownMuts1=${dbsnp_gatk}
memory=6000
flist=$inputListBAM
if [ -e $inputListBAM ] ; then
	i=$(file $inputListBAM)
	if [[ "$i" =~ "ASCII text" ]] ; then
		flist=""
		for i in `cat $inputListBAM`; do
			flist=$flist" "$i
		done
	fi
fi
cores=2
header=$(bsubHeader $stem $step $memory $cores)

echo \
"$header

#BSUB -E \"$scriptDir/../lib/stageReference.sh $step\"
#$Date: 2015-10-15 17:44:21 -0700 (Thu, 15 Oct 2015) $ $Revision: 1719 $
source $scriptDir/../lib/shared.sh

initiateJob $stem $step
set -e

genomeDatabase=$genomeDatabase
genomeIndex=$genomeIndex
genomeIndex2=$genomeIndex2
knownMuts1=$knownMuts1
if [ \$genomeDatabase == \"FAILED\" -o \$knownMuts1 == \"FAILED\" ] ; then
	echo \"Could not transfer \$input\"
	exit 1
fi
for f in $flist; do
	file=\$( stage.pl --operation out --type file \$f )
	index=\$( echo \$file | sed 's/bam$/bai/' ) 
	index=\$( stage.pl --operation out --type file \$index )
	bamString=\${bamString}\" -I \$file \"
	if [ \$file == \"FAILED\"  ] ; then
		echo \"Could not transfer \$file\"
		exit 1
	fi
done

outputDirectory=\$( setOutput \$file ${step} )



experimentType=\$(ngs-sampleInfo.pl \$f experiment_type);
if [  \"\$experimentType\" == \"DNA-Seq\" ] ; then
	
celgeneExec.pl --analysistask $analysistask \"java -Xmx${memory}m -jar ${gatkbin} \
-T HaplotypeCaller \
-R \${genomeDatabase} \${bamString} \
--dbsnp \${knownMuts1} \
-stand_call_conf 30  -stand_emit_conf 10  \
-o \${outputDirectory}/${output} --max_alternate_alleles 2 -minPruning 2\"
if [ \$? != 0 ] ; then
	echo "Failed to run command"
	exit 1
fi 
elif [ \"\$experimentType\" == \"RNA-Seq\" ] ; then
celgeneExec.pl --analysistask $analysistask \"java -Xmx${memory}m -jar ${gatkbin} \
-T HaplotypeCaller \
-R \${genomeDatabase} \${bamString}  \
-stand_call_conf 20  \
-stand_emit_conf 20 \
-recoverDanglingHeads \
-dontUseSoftClippedBases  -o \${outputDirectory}/${output} \"
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

