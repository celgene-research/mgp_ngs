#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1
analysistask=75
step="ExtractFastq"
stem=$( fileStem $input )
initiateJob $stem $step $1

cores=$(fullcores) # done to make sure that there 
memory=$(fullmemory)


header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-09-15 17:31:31 -0700 (Tue, 15 Sep 2015) $ $Revision: 1644 $
source $scriptDir/../lib/shared.sh
initiateJob $stem $step $1
set -e


input=\$( stage.pl --operation out --type file  $input )
if [ \$input == \"FAILED\" ] ; then
	
	echo \"Could not transfer \$input\"
	exit 1
fi

outputDirectory=\$( setOutput \$input fastq )


celgeneExec.pl --analysistask $analysistask \"\
$samtoolsbin sort -@ $cores -n -o \${outputDirectory}/$stem.name.bam  \$input ; \
java -Xmx6g -jar ${PICARDBASE}/picard.jar SamToFastq INPUT=\${outputDirectory}/$stem.name.bam \
  FASTQ=\${outputDirectory}/${stem}_R1.fastq \
  SECOND_END_FASTQ=\${outputDirectory}/${stem}_R2.fastq \
  UNPAIRED_FASTQ=\${outputDirectory}/${stem}_unpaired.fastq  \
  INCLUDE_NON_PF_READS=TRUE TMP_DIR=\${NGS_TMP_DIR} VERBOSITY=WARNING  \
  VALIDATION_STRINGENCY=SILENT ; \
$makepairedreadsbin --input \${outputDirectory}/${stem}_unpaired.fastq  \
  --output1 \${outputDirectory}/${stem}_R1.fastq \
  --output2 \${outputDirectory}/${stem}_R2.fastq ; \
$pigzbin \${outputDirectory}/${stem}_R1.fastq ; \
$pigzbin \${outputDirectory}/${stem}_R2.fastq ; \
$pigzbin \${outputDirectory}/${stem}_unpaired.fastq ;\
rm \${outputDirectory}/$stem.name.bam \
\" 
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

