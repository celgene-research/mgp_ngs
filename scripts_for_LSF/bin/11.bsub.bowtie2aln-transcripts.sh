#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh

# map reads to transcripts.
# the transcript were created by rsem and have 125 polyA tag at teh end
# regarding orientation of mapping (i.e. --nofw see http://likit.github.io/tag/rnaseq.html)

step="bowtie2-transcripts"
input1=$1
analysistask=38
input2=$( getSecondReadFile $input1)

checkfile $input1
checkfile $input2

stem=$(fileStem $input1)
output=$stem



database=${humanrsemidx}/genome.fa
step=$step.human


commandarguments=""
paired_end=$(ngs-sampleInfo.pl $input1 paired_end)
strandness=$( ngs-sampleInfo.pl $input1 stranded )
#if [ $strandness == "REVERSE" ]; then
#	commandarguments=${commandarguments}" --strand-specific"
#fi
#if [ $paired_end == "1" ]; then
#	commandarguments=${commandarguments}" --paired-end "
#fi

# end of command arguments
##########################

cores=$( fullcores )
memory=16000
export NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header


#$Date: 2015-05-22 12:23:19 -0700 (Fri, 22 May 2015) $ $Revision: 1473 $


source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step

database=$database
input1=\$( stage.pl --operation out --type file  $input1 )

if [ "$paired_end" == "1" ] ; then
input2=\$( stage.pl --operation out --type file  $input2 )
fi

outputDirectory=\$( setOutput \$input1 ${step}-bamfiles )




celgeneExec.pl --analysistask ${analysistask} \"\
$bowtie2bin --quiet \
-q  \
--phred33 \
--sensitive \
--dpad 0 \
--gbar 99999999 \
--mp 1,1 \
--np 1  \
--score-min L,0,-0.1 \
-I 1 \
-X 1000 \
--no-mixed \
--no-discordant \
--nofw \
-p $cores \
-k 200  \
-x \${database} \
-1 \${input1} \
-2 \${input2} | \
$samtoolsbin view -Sbh -F 4 - > \${outputDirectory}/${stem}.tmp.bam ; \
$samtoolsbin sort -@ $cores -m 2G -n \${outputDirectory}/${stem}.tmp.bam  \${outputDirectory}/${stem}-${step}\
\"
rm \${outputDirectory}/${stem}.tmp.bam


ingestDirectory \$outputDirectory 
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

