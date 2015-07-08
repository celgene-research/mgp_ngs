#!/bin/bash
inputVCF=$1
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
analysistask=59
step="VariantFilter"

#snpeffGenomeVersion=GRCh37.64


snpsiftBin=$snpsiftbin
filterFile=$2


if [ ! -e $filterFile -a "$filterFile" != "tranche" ] ;then
	echo "Cannot find filter file $filterFile "
	exit 
fi

memory=4000
cores=1
NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
stem=$(fileStem $input)

mkdir -p $NGS_LOG_DIR
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#BSUB -E \"$scriptDir/../lib/stageReference.sh $step\"
#$Date: 2015-06-02 14:40:34 -0700 (Tue, 02 Jun 2015) $ $Revision: 1552 $
source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step

"> $output.$step.bsub

if [ $filterFile == "tranche" ] ;then
echo \
"
trancheThresh=\$( $scriptDirectory/tranche.sh $inputVCF)
celgeneExec.pl --analysistask $analysistask \"cat ${inputVCF} | $snpsiftBin filter \\\"(VQSLOD> \$trancheThresh)\\\"  > ${output}\"
	
">> $output.$step.bsub
else
echo \
" 
celgeneExec.pl --analysistask $analysistask \"cat ${inputVCF} | $snpsiftBin filter -e $filterFile > ${output}\"

" >> $output.$step.bsub
fi

echo \
"
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 

closeJob

" >> $output.$step.bsub
bsub < $output.$step.bsub

