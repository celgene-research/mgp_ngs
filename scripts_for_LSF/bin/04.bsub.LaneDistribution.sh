#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1

analysistask=48
binary=${NGS_BINARIES_DIR}/getLibraryDistribution.pl
checkfile $input
readPE=$(ngs-sampleInfo.pl  $input paired_end )
if [ "$readPE" == "1" ] ; then
input2=$( getSecondReadFile $input)
checkfile $input2
fi
#for step in MarkDuplicates CollectAlnSummary CollectInsertSize CollectRNASeqMetrics BamIndex LibraryComplexity
step="LaneDistribution"
stem=$(fileStem $input)

memory=8000
cores=1
NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-10-05 18:26:37 -0700 (Mon, 05 Oct 2015) $ $Revision: 1692 $
source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step

input=\$( stage.pl --operation out --type file  $input )
if [ \"${readPE}\" == \"1\" ]; then
	input2=\$( stage.pl --operation out --type file  $input2)
fi

outputDirectory=\$( setOutput \$input fastqQC/${step} )


output1=\${outputDirectory}/${stem}.${step}.qcstats
if [ \"${readPE}\" == \"1\" ]; then
	output2=\${outputDirectory}/${stem}.${step}_R2.qcstats
fi



celgeneExec.pl --analysistask ${analysistask} \"$binary \${input} \${output1} \" 


if [ \"${readPE}\" == \"1\" ]; then
runQC-fastq.pl --logfile \$MASTER_LOGFILE --inputfq \${input},\${input2} --outputfile \${output} --reuse --qcStep LaneDistribution
else
runQC-fastq.pl --logfile \$MASTER_LOGFILE --inputfq \${input},\${input} --outputfile \${output} --reuse --qcStep LaneDistribution
fi
if [ \$? != 0 ] ; then
	echo "Failed to update database"
	exit 1
fi 

ingestDirectory \$outputDirectory
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 
rm -rf \$outputDirectory

closeJob
" > ${stem}.${step}.bsub

bsub < ${stem}.${step}.bsub
#rm $$.tmp

