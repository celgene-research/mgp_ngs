#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1
input2=$( getSecondReadFile $input)
analysistask=48


checkfile $input
checkfile $input2

step="FastQC"
stem=$(fileStem $input)
NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
memory=8000
cores=2


mkdir -p $NGS_LOG_DIR
header=$(bsubHeader $stem $step $memory $cores)
echo "$header

#$Date: 2015-06-01 18:04:39 -0700 (Mon, 01 Jun 2015) $ $Revision: 1527 $
source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step

input=\$( stage.pl --operation out --type file  $input )
input2=\$( stage.pl --operation out --type file  $input2)


outputDirectory=\$( setOutput \$input fastqQC/${step} )
output=\${outputDirectory}/${stem}.${step}.qcstats
mkdir -p \${outputDirectory}/tmp

celgeneExec.pl --analysistask ${analysistask} \"\
$fastqcbin \
  --outdir \${outputDirectory}/tmp \
  --quiet --nogroup \
  --threads 2 \
  --format fastq \${input} \${input2} ;\
mv \${outputDirectory}/tmp \${output} \" 

cd \${output}
for z in *.zip; do unzip -o \$z; done

runQC-fastq.pl --logfile \$MASTER_LOGFILE --inputfq \${input},\${input2} --outputfile \${output} --reuse --qcStep FastQC
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

