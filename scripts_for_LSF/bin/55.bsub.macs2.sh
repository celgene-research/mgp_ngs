#!/bin/bash

# this script is using macs2 to call peaks from chipseq datasets
#
# it can be used to either call broad or sharp peaks
# it will ask the db for the type of ChIPseq experiment and adjust accordingly



scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
inputTag=$1
inputControl=$2
checkfile $inputTag
checkfile $inputControl
inputTagIndex=$(echo $inputTag | sed 's/bam$/bai/')
inputControlIndex=$(echo $inputControl | sed 's/bam$/bai/')

stem=$(fileStem $inputTag)
step="MACS2"

analysistask=38

 
export NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR
cores=$(fullcores) #MACS does not need many cores, but when run many instances on the same machine there are crashes.
memory=3000
header=$(bsubHeader $stem $step $memory $cores)

peaktype=$( ngs-sampleInfo.pl $inputTag antibody_target )

# This by no means is a comprehensive list
# it is being built as we get more ChIP-Seq experiments
# from https://sites.google.com/site/anshulkundaje/projects/encodehistonemods
# narrow indicates peaks that are narrow e.g. TF
# broad indicates peaks that are broad
# gapped are broad peaks with at least one narrow peak
case "$peaktype" in
"H3K4me3" )
# narrow peak around TSS => active chromatin
	peaktype="narrow"
;;
"H3K4me2" )
	peaktype="narrow"
;;
"H3K4me1" )
	peaktype="narrow"
;;
"H3K9ac" )
	peaktype="narrow"
;;
"H3K27ac" )
	peaktype="narrow"
;;
"H3K27me3" )
# broad domain across the body of genes => inhibition ot transcription
# sharp peak around TSS for bivalent genes
	peaktype="broad"
;; 
"H3K36me3" )
	peaktype="broad"
;; 
"H3K79me2" )
	peaktype="broad"
;;
"H3K9me3" )
	peaktype="broad"
;;
"H3K9me1" )
	peaktype="broad"
;;
esac

if [ "$peaktype" == "broad" ]; then
	commandArguments=" --qvalue 0.1 --broad --broad-cutoff 0.1"
elif [ "$peaktype" == "narrow" ] ;then
	commandArguments=" --qvalue 0.01  --call-summits"
fi
echo \
"$header

#$Date: 2015-06-01 18:02:35 -0700 (Mon, 01 Jun 2015) $ $Revision: 1524 $

source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step





inputTag=\$( stage.pl --operation out --type file  ${inputTag} )
inputTagIndex=\$( stage.pl --operation out --type file  $inputTagIndex )
inputControl=\$( stage.pl --operation out --type file  ${inputControl} )
inputControlIndex=\$( stage.pl --operation out --type file  $inputControlIndex )



####################
if [ \$inputTag == \"FAILED\" -o \$inputControl == \"FAILED\"  ] ; then
	echo \"Could not transfer \$inputTag or \$inputControl \"
	exit 1
fi

outputDirectory=\$( setOutput \$inputTag ${step}-peaks )


celgeneExec.pl --analysistask ${analysistask} \"\
$macs2bin callpeak \
 --treatment \${inputTag} \
 --control \${inputControl} \
 --name $stem \
 --outdir \${outputDirectory}/${stem} \
 --gsize 2.7e9 \
 --mfold 5 80 \
 --bw 200 \
 --bdg \
 --keep-dup auto\
$commandArguments \"

chromInfo=\${outputDirectory}/${stem}/chromInfo.txt
$samtoolsbin view -H \$inputTag | grep '^@SQ' | cut -f2,3 | sed 's%SN:%%' | sed 's%LN:%%' > \$chromInfo

ingestDirectory \$outputDirectory yes
if [ \$? -ne 0 ] ; then
	echo \"Failed to ingest data\"
	exit 1
fi 


closeJob
"> ${stem}.${step}.bsub

bsub < ${stem}.${step}.bsub
