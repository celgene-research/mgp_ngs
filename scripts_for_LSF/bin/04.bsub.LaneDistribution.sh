#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1
input2=$( getSecondReadFile $input)
analysistask=48
binary=${NGS_BINARIES_DIR}/getLibraryDistribution.pl
checkfile $input
checkfile $input2

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

#$Date: 2015-06-01 18:04:39 -0700 (Mon, 01 Jun 2015) $ $Revision: 1527 $
source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step

input=\$( stage.pl --operation out --type file  $input )
input2=\$( stage.pl --operation out --type file  $input2)


outputDirectory=\$( setOutput \$input fastqQC/${step} )


output1=\${outputDirectory}/${stem}.${step}.qcstats
output2=\${outputDirectory}/${stem}.${step}_R2.qcstats


celgeneExec.pl --analysistask ${analysistask} \"$binary \${input} \${output1} \" 

runQC-fastq.pl --logfile \$MASTER_LOGFILE  --inputfq \${input},\${input2} --outputfile \${output1} --reuse --qcStep LaneDistribution
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

