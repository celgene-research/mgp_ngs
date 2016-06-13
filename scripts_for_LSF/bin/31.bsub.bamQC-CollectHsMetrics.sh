#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1

checkfile $input

analysistask=58
step="CalculateHsMetrics"

index=$(echo $input|sed 's/bam$/bai/');

exptype=$(ngs-sampleInfo.pl $input experiment_type)
if [ "$exptype" != "DNA-Seq_exome_sequencing_WES" ]; then
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

stem=$(fileStem $input)
strand=$( ngs-sampleInfo.pl $input stranded )
initiateJob $stem $step $1
#####
# check if exome set baitsfile and captureKit

exomeSet=$(ngs-sampleInfo.pl $input bait_set)
case  "${exomeSet}" in
"Nextera_Rapid_Capture_v1.2_Illumina" )
		baitsfile=${humanGenomeDir}/ExonCapture/nexterarapidcapture_exome_targetedregions_v1.2.intervals.bed
	;;
"SureSelect_Human_All_exon_v1_38Mb_Agilent" )
	baitsfile=${humanGenomeDir}/ExonCapture/S0274956_Covered.intervals.bed
	;;
"SureSelect_Human_All_exon_v2_44Mb_Agilent" )
	baitsfile=${humanGenomeDir}/ExonCapture/S0293689_Covered.intervals.bed
	;;
"SureSelect_Human_All_exon_v3_50_Mb_Agilent" )
	baitsfile=${humanGenomeDir}/ExonCapture/S02972011_Covered.intervals.bed
	;;
"SureSelect_Human_All_exon_v4_51Mb_Agilent" )
	baitsfile=${humanGenomeDir}/ExonCapture/S03723314_Covered.intervals.bed
	;;
"SureSelect_Human_All_exon_v4+UTRs_71Mb_Agilent" )
	baitsfile=${humanGenomeDir}/ExonCapture/S03723424_Covered.intervals.bed
	;;
"SureSelect_Human_All_exon_v5+UTRs_75Mb_Agilent" )
	baitsfile=${humanGenomeDir}/ExonCapture/S04380219_Covered.intervals.bed
	;;
"SureSelect_Human_All_exon_v5_50Mb_Agilent" )
	baitsfile=${humanGenomeDir}/ExonCapture/S04380110_Covered.intervals.bed
	;;
"SureSelect_Human_All_exon_v6+COSMIC_64Mb_Agilent" )
	baitsfile=${humanGenomeDir}/ExonCapture/S07604715_Covered.intervals.bed
	;;
"SureSelect_Human_All_exon_v6_58Mb_Agilent" )
	baitsfile=${humanGenomeDir}/ExonCapture/S07604514_Covered.intervals.bed
	;;
"SureSelect_Human_All_exon_v6+UTRs_58Mb_Agilent" )
	baitsfile=${humanGenomeDir}/ExonCapture/S07604624_Covered.intervals.bed
	;;
"Agilent_50_Mb_V5_with_extra_content" )
	baitsfile=${humanGenomeDir}/ExonCapture/morgan.exomeplus.v5.padded.bed
	;;
"Agilent_50_Mb_v3_with_extra_content" )
	baitsfile=${humanGenomeDir}/ExonCapture/morgan.exomeplus.v3.padded.bed
	;;
* )
	echo "Cannot recognize exome capture kit"
	;;
esac
captureKit=${exomeSet}
#mkdir -p bamQC

cores=2

memory=6000


mkdir -p $NGS_LOG_DIR

header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-09-17 17:46:09 -0700 (Thu, 17 Sep 2015) $ $Revision: 1651 $
source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step $1

input=\$( stage.pl --operation out --type file  $input )
inputIndex=\$(stage.pl --operation out --type file  $index )
genomefile=$genomefile
genomefileIndex=$genomefile.fai
baitsfile=$baitsfile

newDir=\$( lastDir \$input | sed 's%bamfiles%bamQC%')
outputDirectory=\$( setOutput \$input \$newDir/${step} )



celgeneExec.pl --analysistask ${analysistask} \"\
java -Xmx${memory}m -jar ${PICARDBASE}/picard.jar CollectHsMetrics \
  VERBOSITY=WARNING \
  INPUT=\$input \
  TMP_DIR=\${NGS_TMP_DIR}	\
  BI=\${baitsfile} \
  TI=\${baitsfile} \
  N=\'$captureKit\' \
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

" > ${stem}.${step}.${suffix}.bsub

bsub < ${stem}.${step}.${suffix}.bsub

