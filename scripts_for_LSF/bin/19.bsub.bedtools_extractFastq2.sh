#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1
analysistask=75
step="ExtractFastqBed"
stem=$( fileStem $input )


cores=$(fullcores)
memory=$(fullmemory)

initiateJob $stem $step $1
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
$samtoolsbin sort -n \$input -@ $cores \${outputDirectory}/$stem.name.bam ; \
$bedtoolsbin bamtofastq -i \${outputDirectory}/$stem.name.bam \
  -fq \${outputDirectory}/${stem}_R1.fastq \
  -fq2 \${outputDirectory}/${stem}_R2.fastq; \
$makepairedreadsbin --input \${outputDirectory}/${stem}_unpaired.fastq  \
  --output1 \${outputDirectory}/${stem}_R1.fastq \
  --output2 \${outputDirectory}/${stem}_R2.fastq ; \
gzip \${outputDirectory}/${stem}_R1.fastq ; \
gzip \${outputDirectory}/${stem}_R2.fastq ; \
rm \${outputDirectory}/$stem.name.bam\" 
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

