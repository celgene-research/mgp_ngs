#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh

step="RSEM"
input1=$1
analysistask=38

checkfile $input1

stem=$(fileStem $input1)
output=$stem



database=${humanrsemidx}/genome.fa
step=$step.human


commandarguments=""
paired_end=$(ngs-sampleInfo.pl $input1 paired_end)
strandness=$( ngs-sampleInfo.pl $input1 stranded )
# the following lines are not needed since the stranded inofmration has already been used when the alignments were generated
#if [ $strandness == "REVERSE" ]; then
#	commandarguments=${commandarguments}" --strand-specific"
#fi
if [ $paired_end == "1" ]; then
	commandarguments=${commandarguments}" --paired-end "
fi

# end of command arguments
##########################

cores=$( fullcores )
memory=16000
export NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header


#$Date: 2015-08-14 13:02:55 -0700 (Fri, 14 Aug 2015) $ $Revision: 1624 $


source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step $1

database=$database
input1=\$( stage.pl --operation out --type file  $input1 )



outputDirectory=\$( setOutput \$input1 ${step}-transcriptCounts )

 
# the bam files that are used for this step come from the alignemnt of read to the transcripts (using bowtie2) and are
# sorted by name
# the rsem script convert-sam-for-rsem sorts the bam file and then calls rsem-scan-for-paired-end-reads
cd \$outputDirectory ;
celgeneExec.pl --analysistask ${analysistask} \"\
$rsemscanforpairedendreadsbin <($samtoolsbin view -h \${input1}) \${outputDirectory}/${stem}.bam ;\
$rsemcalculateexpressionbin  \
  --num-threads  $cores \
  --output-genome-bam \
  $commandarguments \
  --keep-intermediate-files \
  --time \
  --bam \
\${outputDirectory}/${stem}.bam  \$database $stem \
\"


ingestDirectory \$outputDirectory yes
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 

closeJob

"\
> ${stem}.${step}.bsub

bsub < ${stem}.${step}.bsub
#bash $jobName

#rm $$.tmp

