#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh

# map reads from WGBS to genome.
# 

step="Bismark"
input1=$1
analysistask=38
input2=$( getSecondReadFile $input1)

checkfile $input1
checkfile $input2

stem=$(fileStem $input1)
output=$stem



database=${humanbismarkidx}
step=$step.human


commandarguments=""
paired_end=$(ngs-sampleInfo.pl $input1 paired_end)
strandness=$( ngs-sampleInfo.pl $input1 stranded )
if [ $strandness == "NONE" ]; then
	commandarguments=${commandarguments}" --non_directional"
fi
#if [ $paired_end == "1" ]; then
#	commandarguments=${commandarguments}" --paired-end "
#fi

# end of command arguments
##########################

cores=$( fullcores )
forks=$((cores/5))
memory=16000
initiateJob $stem $step $1

header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header


#$Date: 2015-08-19 10:49:41 -0700 (Wed, 19 Aug 2015) $ $Revision: 1628 $


source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step $1

database=$database
input1=\$( stage.pl --operation out --type file  $input1 )

if [ "$paired_end" == "1" ] ; then
input2=\$( stage.pl --operation out --type file  $input2 )
fi

outputDirectory=\$( setOutput \$input1 ${step} )



cd \${outputDirectory} 

celgeneExec.pl --analysistask ${analysistask} \"\
$bismarkbin \
${commandarguments} \
--fastq \
--multicore ${forks} \
--output_dir \${outputDirectory} \
--basename ${stem} \
\${database} \
-1 \${input1} \
-2 \${input2} \
\"



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

