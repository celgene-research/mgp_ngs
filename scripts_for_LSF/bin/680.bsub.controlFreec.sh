#!/bin/bash
inputcontrol=$1
inputsample=$2


echo "This script is running the controlFreec"
echo "it requires as input the sample file and if available the control file "
echo "This version of the script assumes Whole Genome Sequencing and not Exome. "



scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
analysistask=59
step="controlFreec.human"
stem=$(fileStem $inputsample)


nameinputsample=$(stage.pl --name $inputsample )
if [ -n "$inputsample" ]; then
	echo "User provided control as well"
	stemB=$(fileStem $inputcontrol)
	stem=${stem}-${stemB}
	
	nameinputcontrol=$(stage.pl --name $inputcontrol )
else
	$inputsample=$inputcontrol 
fi
initiateJob $stem $step $1
memory=54000
cores=$(fullcores)

seqtype=$(ngs-sampleInfo.pl $inputsample experiment_type) # decide if WES or WGS
freecMappability=$(dirname $freecbin)/../hg19/out100m1_hg19.gem
freecSNPs=$(dirname $freecbin)/../hg19_snp142.SingleDiNucl.1based.txt
freecBAF=$(dirname $freecbin)/../hg19_snp142.SingleDiNucl.1based.bed
encoding=$(ngs-sampleInfo.pl $inputsample encoding_base)
paired_end=$(ngs-sampleInfo.pl $inputsample paired_end)
if [ $paired_end == "1" ]; then
	mateorientation="FR"
else
	mateorientation="0"
fi

configTemplate="680.template.controlFreec.WGS-NT.txt"


mkdir -p $NGS_LOG_DIR
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-10-01 15:43:49 -0700 (Thu, 01 Oct 2015) $ $Revision: 1676 $
source $scriptDir/../lib/shared.sh 
initiateJob $stem $step $1

inputsample=\$( stage.pl --operation out --type file  $inputsample)
if [ -n \"$inputcontrol\" ]; then
	inputcontrol=\$( stage.pl --operation out --type file  $inputcontrol)
fi

if [ \$inputsample == \"FAILED\" ]; then
	echo \"Could not transfer \$inputsample\"
	exit 1
fi
outputDirectory=\$( setOutput \$inputsample ${step} )




source ${scriptDir}/${configTemplate} > \$outputDirectory/${stem}-${step}.config

celgeneExec.pl --metadatastring config=${stem}-${step}.config --analysistask $analysistask \"\
\$freecbin -conf \${outputDirectory}/${stem}-${step}.config \
\"


if [ \$? != 0 ] ; then
	echo "Failed to run command"
	exit 1
fi 

ingestDirectory \$outputDirectory
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 

closeJob

" >${stem}.${step}.$( getStdSuffix ).bsub
bsub < ${stem}.${step}.$( getStdSuffix ).bsub
