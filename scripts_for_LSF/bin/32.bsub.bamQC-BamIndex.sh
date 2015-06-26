#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1
analysistask=58
step="BamIndex"

checkfile $input

index=$(echo $input|sed 's/bam$/bai/');

NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
cores=4
memory=16000
stem=$(fileStem $input)

mkdir -p $NGS_LOG_DIR

header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-06-01 18:04:39 -0700 (Mon, 01 Jun 2015) $ $Revision: 1527 $
source $scriptDir/../lib/shared.sh

initiateJob $stem $step
set -e

input=\$( stage.pl --operation out --type file  $input )
index=\$( stage.pl --operation out --type file  $index );


newDir=\$( lastDir \$input | sed 's%bamfiles%bamQC%')
outputDirectory=\$( setOutput \$input \$newDir/${step} )




celgeneExec.pl --analysistask ${analysistask} \"\
java -Xmx${memory}m -jar ${PICARD_BASE}/picard.jar BamIndexStats \
  VERBOSITY=WARNING INPUT=\$input \
  TMP_DIR=\${NGS_TMP_DIR}	\
  VALIDATION_STRINGENCY=SILENT >\
 \${outputDirectory}/$stem.${step}.qcstats \"
  if [ $? != 0 ] ; then
	echo "Failed to run command"
	exit 1
fi 

runQC-bam.pl --logfile \$MASTER_LOGFILE --inputbam \${input} --outputfile \${outputDirectory}/$stem.${step}.qcstats --reuse --qcStep BamIndex
if [ $? != 0 ] ; then
	echo "Failed to update database"
	exit 1
fi 
ingestDirectory \$outputDirectory
if [ $? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 
closeJob
" > ${stem}.${step}.bsub

bsub < ${stem}.${step}.bsub
#rm $$.tmp

