#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
inputaln=$1
inputump=$2
analysistask=75
step="MergeBamAlignment"

inputaln=$( echo $inputaln | tr ',' ' ')
inputump=$( echo $inputump | tr ',' ' ') 

stem=$( fileStem $inputaln )

echo "$0 <aligned bam files in a comma separated list> <unmapped bam files in a comma separated list>"
echo "Currently (May 2016) picard tools has two tools to merge bam files"
echo "This script submits jobs that use the MergeBamAlignment tool which "
echo "merges aligned bam files with unmapped bam files"



export NGS_LOG_DIR=${NGS_LOG_DIR}/${step}


refgenome=$(ngs-sampleInfo.pl $inputaln reference_genome)
if [ -z "$refgenome" -o "$refgenome" == "" ]; then echo "Could not find reference genome. Exiting";exit;fi

if [ $refgenome == 'Homo_sapiens' ] ; then

	#ribosomal_intervals=${humanAnnotationDir}/gencode.ribosomal.intervals
	#annotationfile=${humanAnnotationDir}/gencode.refFlat.txt
	genomefile=${humanGenomeDir}/genome.fa
	step=${step}".human"
fi


cores=3 # this is done to provide lighter operations on the nodes
memory=6000
mkdir -p $NGS_LOG_DIR
initiateJob $stem $step $1
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-09-15 17:31:31 -0700 (Tue, 15 Sep 2015) $ $Revision: 1644 $
source $scriptDir/../lib/shared.sh
initiateJob $stem $step $1
set -e


inputaln=\$( stage.pl --operation out --type file  $inputaln )

inputumpfilestr=\"\"
for i in "$inputump" ;do
	i=\$( stage.pl --type file --operation out \${i} )
	inputumpfilestr=\"\${inputumpfilestr} \${i}\"
	extension=\${filestr1##*.}
done
inputump=\$( stage.pl --operation out --type file  $inputump )
if [ \$inputaln == \"FAILED\" -o \$inputump == \"FAILED\" ] ; then
	
	echo \"Could not transfer \$inputaln or \$inputump\"
	exit 1
fi

outputDirectory=\$( setOutput \$inputaln $step )


celgeneExec.pl --analysistask $step \"\
java -Xmx6g -jar ${PICARDBASE}/picard.jar MergeBamAlignment \
  ALIGNED=\${inputaln} \
  UNMAPPED=\${inputump} \
  REFERENCE_SEQUENCE=\$genomefile \
  OUTPUT=\${outputDirectory}/${stem}.coord.bam \
  SORT_ORDER=coordinate \ 
  VERBOSITY=WARNING  \
  VALIDATION_STRINGENCY=SILENT\
  " 
if [ \$? != 0 ] ; then
	echo \"Failed to execute command\"
	exit 1
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

