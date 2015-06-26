#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh

step="Sailfish"
input1=$1
analysistask=38
input2=$( getSecondReadFile $input1)

checkfile $input1
checkfile $input2

stem=$(fileStem $input1)
output=$stem


database=${humanDir}/SailFishIndex
step=$step.human

export NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR



paired_end=$(ngs-sampleInfo.pl $input1 paired_end)
if [ $paired_end == "1" ]; then
	library="T=PE:O=><:S=AS"
else
	library="T=SE:S=A"
fi

# end of command arguments
##########################

cores=$(fullcores)
memory=16000
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#BSUB -E \"$scriptDir/../lib/stageReference.sh $step\"
#$Date: 2015-06-01 18:05:20 -0700 (Mon, 01 Jun 2015) $ $Revision: 1528 $


source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step

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
$sailfishbin quant --index \$database --libtype '$library' -1 \${outputDirectory}/1.fq -2 \${outputDirectory}/2.fq  -o \${outputDirectory}/$stem.$step.sfish -p $cores  --no_bias_correct ; \
rm \${outputDirectory}/*.fq \"


ingestDirectory \$outputDirectory yes
if [ $? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 

closeJob

"\
> ${stem}.${step}.bsub

bsub < ${stem}.${step}.bsub
#bash $jobName

#rm $$.tmp

