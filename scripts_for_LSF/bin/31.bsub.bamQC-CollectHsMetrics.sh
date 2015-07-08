#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1

checkfile $input

analysistask=58
step="CalculateHsMetrics"

index=$(echo $input|sed 's/bam$/bai/');

exptype=$(ngs-sampleInfo.pl $input experiment_type)
if [ "$exptype" != "DNA-Seq exome sequencing (WES)" ]; then
	echo "This script is suggested to be used for exome data"
	exit 1
fi


refgenome=$(ngs-sampleInfo.pl $input reference_genome)
if [ -z "$refgenome" -o "$refgenome" == "" ]; then echo "Could not find reference genome. Exiting";exit;fi

if [ $refgenome == 'Homo_sapiens' ] ; then

	#ribosomal_intervals=${humanAnnotationDir}/gencode.ribosomal.intervals
	#annotationfile=${humanAnnotationDir}/gencode.refFlat.txt
	genomefile=${humanGenomeDir}/genome.fa
	step=${step}".human"
fi
if [ $refgenome == 'Rattus_norvegicus' ] ;then
	#ribosomal_intervals=${ratAnnotationDir}/Rattus_norvegicus.Rnor_5.0.74.ribosomal.intervals
	#annotationfile=${ratAnnotationDir}/Rattus_norvegicus.Rnor_5.0.74.refFlat.txt
	genomefile=${ratGenomeDir}/genome.fa
	step=${step}".rat"
fi


strand=$( ngs-sampleInfo.pl $input stranded )
NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
#####
# check if exome set baitsfile and captureKit
baitsfile=${humanAnnotationDir}/../nexterarapidcapture_exome_targetedregions_v1.2.intervals
captureKit='Nextera_rapid_capture_v1.2'
#mkdir -p bamQC

cores=2

memory=2000
stem=$(fileStem $input)

mkdir -p $NGS_LOG_DIR

header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#BSUB -E \"$scriptDir/../lib/stageReference.sh $step\"
#$Date: 2015-06-01 18:04:39 -0700 (Mon, 01 Jun 2015) $ $Revision: 1527 $
source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step

input=\$( stage.pl --operation out --type file  $input )
inputIndex=\$(stage.pl --operation out --type file  $index )
genomefile=$genomefile
genomefileIndex=$genomefile.fai
baitsfile=$baitsfile

newDir=\$( lastDir \$input | sed 's%bamfiles%bamQC%')
outputDirectory=\$( setOutput \$input \$newDir/${step} )




celgeneExec.pl --analysistask ${analysistask} \"\
java -Xmx${memory}m -jar ${PICARD_BASE}/picard.jar CalculateHsMetrics \
  VERBOSITY=WARNING \
  INPUT=\$input \
  TMP_DIR=\${NGS_TMP_DIR}	\
  BI=\${baitsfile} \
  TI=\${baitsfile} \
  N=$captureKit \
  METRIC_ACCUMULATION_LEVEL=ALL_READS  \
  REFERENCE_SEQUENCE=\${genomefile} \
  PER_TARGET_COVERAGE=\${outputDirectory}/${stem}.${step}.trgcov.qstats \
  O=\${outputDirectory}/$stem.${step}.qcstats \
  VALIDATION_STRINGENCY=SILENT \"
 if [ \$? != 0 ] ; then
	echo "Failed to execute command"
	exit 1
fi 
runQC-bam.pl --logfile \$MASTER_LOGFILE \
 --inputbam $input \
 --outputfile \${outputDirectory}/$stem.${step}.qcstats \
 --reuse --qcStep CaptureHsMetrics \
 --captureKit $captureKit
if [ \$? != 0 ] ; then
	echo "Failed to update database"
	exit 1
fi 
ingestDirectory \$outputDirectory
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 

closeJob

" > ${stem}.{$step}.bsub

bsub < ${stem}.${step}.bsub
#rm $$.tmp

