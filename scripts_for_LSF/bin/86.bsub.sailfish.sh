#!/bin/bash

# use this script to run sailfish from fastq files. 
# the script is using the latest 'kallisto' like sailfish interface
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh

step="Sailfish"
input1=$1
analysistask=38
input2=$( getSecondReadFile $input1)

checkfile $input1
checkfile $input2

stem=$(fileStem $input1)
output=$stem


database=${humanDir}/SailFishIndex_0.7.6
step=$step.human

export NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR



paired_end=$(ngs-sampleInfo.pl $input1 paired_end)
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
initiateJob $stem $step $1

database=$database
input1=\$( stage.pl --operation out --type file  $input1 )
input2=\$( stage.pl --operation out --type file  $input2 )


outputDirectory=\$( setOutput \$input1 ${step}-transcriptCounts )

# sailfish needs to find libsailfish_core.so which comes with teh sailfish distribution
dd=\$( dirname \$( dirname $sailfishbin ))
export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\${dd}/lib
 
# no_bias_correct is used to avoid core dumps that happen frequently

celgeneExec.pl --analysistask ${analysistask} \"\
$pigzbin -c -d -p $cores \$input1 > \${outputDirectory}/1.fq ; \
$pigzbin -c -d -p $cores \$input2 > \${outputDirectory}/2.fq ; \
$sailfishbin quant --index \$database \
  -l '$library' \
  -1 \${outputDirectory}/1.fq -2 \${outputDirectory}/2.fq  \
  -o \${outputDirectory}/$stem.$step.sfish \
  --numThreads $cores  \
  --useVBOpt \
  --numBootstraps 100  ; \
rm \${outputDirectory}/*.fq \"


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

