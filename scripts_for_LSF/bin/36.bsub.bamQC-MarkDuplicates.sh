#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1

checkfile $input

analysistask=60
step="MarkDuplicates"
index=$(echo $input|sed 's/bam$/bai/');

NGS_LOG_DIR=${NGS_LOG_DIR}/${step}


cores=$(fullcores) 

memory=55000
stem=$(fileStem $input)
echo "File stem set to [$stem]"
mkdir -p $NGS_LOG_DIR

header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-06-01 18:04:39 -0700 (Mon, 01 Jun 2015) $ $Revision: 1527 $
source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step

input=\$( stage.pl --operation out --type file  $input )
inputIndex=\$(stage.pl --operation out  --type file $index  )


newDir=\$( lastDir \$input | sed 's%bamfiles%bamQC%')
outputDirectory=\$( setOutput \$input \$newDir/${step} )
newDir=\$( lastDir \$input | sed 's%bamfiles%bamfile-Mdup%')
outputDirectoryBam=\$( setOutput \$input \$newDir )





celgeneExec.pl --analysistask ${analysistask} \"java -Xmx${memory}m -jar ${PICARD_BASE}/picard.jar MarkDuplicates VERBOSITY=WARNING INPUT=\$input TMP_DIR=\${NGS_TMP_DIR} M=\${outputDirectory}/${stem}.${step}.qcstats CREATE_INDEX=TRUE AS=TRUE O=\${outputDirectoryBam}/${stem}.${step}.mdup.bam VALIDATION_STRINGENCY=SILENT \"
 if [ \$? != 0 ] ; then
	echo "Failed to execute command"
	exit 1
fi 
runQC-bam.pl --logfile \$MASTER_LOGFILE --inputbam \$input --outputfile \${outputDirectory}/${stem}.${step}.qcstats --reuse --qcStep MarkDuplicates
if [ \$? != 0 ] ; then
	echo "Failed to update database"
	exit 1
fi 
ingestDirectory \$outputDirectory
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 
rm -rf \${outputDirectory} 

ingestDirectory \${outputDirectoryBam}
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 

closeJob

" > ${stem}.${step}.bsub

bsub < ${stem}.${step}.bsub
#rm $$.tmp

