#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1
input2=$( getSecondReadFile $input)
analysistask=48


checkfile $input
readPE=$(ngs-sampleInfo.pl  $input paired_end )
if [ "$readPE" == "1" ] ; then
checkfile $input2
fi


step="FastQC"
stem=$(fileStem $input)
NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
memory=8000
cores=2


mkdir -p $NGS_LOG_DIR
header=$(bsubHeader $stem $step $memory $cores)
echo "$header

#$Date: 2015-10-05 18:23:18 -0700 (Mon, 05 Oct 2015) $ $Revision: 1691 $
source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step

input=\$( stage.pl --operation out --type file  $input )
if [ \"${readPE}\" == \"1\" ]; then
	input2=\$( stage.pl --operation out --type file  $input2)
fi



outputDirectory=\$( setOutput \$input fastqQC/${step} )
output=\${outputDirectory}/${stem}.${step}.qcstats
mkdir -p \${outputDirectory}/tmp

if [ \"${readPE}\" == \"1\" ]; then
celgeneExec.pl --analysistask ${analysistask} \"\
$fastqcbin \
  --outdir \${outputDirectory}/tmp \
  --quiet --nogroup \
  --threads 2 \
  --format fastq \${input} \${input2} ;\
mv \${outputDirectory}/tmp \${output} \"
else
celgeneExec.pl --analysistask ${analysistask} \"\
$fastqcbin \
  --outdir \${outputDirectory}/tmp \
  --quiet --nogroup \
  --threads 2 \
  --format fastq \${input} ;\
mv \${outputDirectory}/tmp \${output} \"
	
	
fi 

cd \${output}
for z in *.zip; do unzip -o \$z; done


if [ \"${readPE}\" == \"1\" ]; then
runQC-fastq.pl --logfile \$MASTER_LOGFILE --inputfq \${input},\${input2} --outputfile \${output} --reuse --qcStep FastQC
else
runQC-fastq.pl --logfile \$MASTER_LOGFILE --inputfq \${input},\${input} --outputfile \${output} --reuse --qcStep FastQC
fi
if [ \$? != 0 ] ; then
	echo "Failed to update database"
	exit 1
fi 
rm \${output}/*.zip # remove the zipped files fastqc creates since they are also extracted

ingestDirectory \${outputDirectory} yes
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 
rm -rf \${outputDirectory} 

closeJob
" > ${stem}.${step}.bsub

bsub < ${stem}.${step}.bsub
#rm $$.tmp

