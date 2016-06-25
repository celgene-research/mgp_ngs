#!/bin/bash

# this script is using macs2 to call peaks from chipseq datasets
#
# it can be used to either call broad or sharp peaks
# it will ask the db for the type of ChIPseq experiment and adjust accordingly



scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
inputTag=$1
inputControl=$2

if [ -z "$inputControl" ] ; then 
	echo "Input to this script is two files. The tag and input bam files. One of the two is missing. Aborting !"
	exit 1
fi

checkfile $inputTag
checkfile $inputControl
inputTagIndex=$(echo $inputTag | sed 's/bam$/bai/')
inputControlIndex=$(echo $inputControl | sed 's/bam$/bai/')

stem1=$(fileStem $inputTag)
stem2=$(fileStem $inputControl)
stem=tag.${stem1}.cntr.${stem2}
step="MACS2"

analysistask=38

cores=1 #MACS does not need many cores, but when run many instances on the same machine there are crashes.
memory=3000

initiateJob $stem $step $1
header=$(bsubHeader $stem $step $memory $cores)

peaktype=$( ngs-sampleInfo.pl $inputTag antibody_target )
display=$(ngs-sampleInfo.pl $inputTag display_name)
controlDisplay=$(ngs-sampleInfo.pl $inputControl display_name)
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

#$Date: 2015-10-05 17:46:45 -0700 (Mon, 05 Oct 2015) $ $Revision: 1690 $

source $scriptDir/../lib/shared.sh 
initiateJob $stem $step $1





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
outputDirectory2=\$( setOutput \$inputTag ${step}-bedgraph )

celgeneExec.pl --analysistask ${analysistask} \"\
$macs2bin callpeak \
 --treatment \${inputTag} \
 --control \${inputControl} \
 --name $stem \
 --outdir \${outputDirectory}/${stem}.macs2 \
 --gsize 2.7e9 \
 --mfold 5 80 \
 --bw 200 \
 --bdg --SPMR \
 --keep-dup auto\
$commandArguments ; \
$macs2bin bdgcmp \
 -t \${outputDirectory}/${stem}.macs2/${stem}_treat_pileup.bdg \
 -c \${outputDirectory}/${stem}.macs2/${stem}_control_lambda.bdg  \
 -o \${outputDirectory}/${stem}.macs2/${stem}_FE.bdg -m FE ; \
$macs2bin bdgcmp \
 -t \${outputDirectory}/${stem}.macs2/${stem}_treat_pileup.bdg \
 -c \${outputDirectory}/${stem}.macs2/${stem}_control_lambda.bdg  \
 -o \${outputDirectory}/${stem}.macs2/${stem}_LR.bdg -m logLR -p 0.00001 \
\"

touch \${outputDirectory}/${stem}.macs2/${display}-${controlDisplay}-${peaktype}

chromInfo=\${outputDirectory}/${stem}.macs2/chromInfo.txt
$samtoolsbin view -H \$inputTag | grep '^@SQ' | cut -f2,3 | sed 's%SN:%%' | sed 's%LN:%%' > \$chromInfo

ingestDirectory \$outputDirectory yes
if [ \$? -ne 0 ] ; then
	echo \"Failed to ingest data\"
	exit 1
fi 


closeJob
"> ${stem}.${step}.$( getStdSuffix ).bsub

bsub < ${stem}.${step}.$( getStdSuffix ).bsub
