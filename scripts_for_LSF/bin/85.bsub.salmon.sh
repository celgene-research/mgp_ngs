#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh

step="Salmon-bam.human"
inputBAM=$1
analysistask=38


checkfile $inputBAM

stem=$(fileStem $inputBAM)
output=$stem


transcripts=${humanrsemidx}/genome.fa.idx.fa
step=$step.human

export NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR



paired_end=$(ngs-sampleInfo.pl $inputBAM paired_end)

# the library type for salmon (per http://sailfish.readthedocs.org/en/latest/salmon.html)
#first part
#I = inward
#O = outward
#M = matching
# second part
#S = stranded
#U = unstranded
# third part (if second part == S)
#F = read 1 (or single-end read) comes from the forward strand
#R = read 1 (or single-end read) comes from the reverse strand

if [ $paired_end == "1" ]; then
	library="ISR"
else
	library="IU"
fi

# end of command arguments
##########################

cores=$(fullcores)
memory=16000
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#BSUB -E \"$scriptDir/../lib/stageReference.sh $step\"
#$Date: 2015-08-14 13:02:55 -0700 (Fri, 14 Aug 2015) $ $Revision: 1624 $


source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step

transcripts=$transcripts
inputBAM=\$( stage.pl --operation out --type file  $inputBAM )



outputDirectory=\$( setOutput \$inputBAM ${step}-transcriptCounts )

# no_bias_correct is used to avoid core dumps that happen frequently

celgeneExec.pl --analysistask ${analysistask} \"\
$salmonbin quant -t \${transcripts} \
  --libType '$library' \
  --alignments \${inputBAM} \
  --output \${outputDirectory}/$stem.$step.salmon \
  --threads $cores\
  --numBootstraps 100 \"


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

