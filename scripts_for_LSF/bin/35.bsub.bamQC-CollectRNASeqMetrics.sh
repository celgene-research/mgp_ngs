#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1

checkfile $input

analysistask=58
step="CollectRNASeqMetrics"

index=$(echo $input|sed 's/bam$/bai/');

refgenome=$(ngs-sampleInfo.pl $input reference_genome)
refdatabase=$( ngs-sampleInfo.pl $input xenograft )
hostgenome=$(ngs-sampleInfo.pl $input host_genome)
if [ -z "$refgenome" ]; then echo "Could not find reference genome. Exiting";exit;fi


if [ $refdatabase == '1' ] ; then
	echo "$input is a xenograft sample of $refgenome tissue on $hostgenome" 
	if [ "$hostgenome" == "Mus_musculus" -a "$refgenome" == "Homo_sapiens" ] ; then
		genomefile=${human_mouseGenomeDir}/genome.fa
		ribosomal_intervals=${human_mouseAnnotationDir}/genes.ribosomal.intervals
		annotationfile=${human_mouseAnnotationDir}/genes.refFlat.txt
		step=$step".xenograft"
	else
		echo "Cannot find database for host genome $hostgenome"
		exit
	fi
	#exit
else
	if [ $refgenome == 'Homo_sapiens' ] ; then
	
		ribosomal_intervals=${humanAnnotationDir}/gencode.ribosomal.intervals
		annotationfile=${humanAnnotationDir}/gencode.refFlat.txt
		genomefile=${humanGenomeDir}/genome.fa
		step=$step".human"
	fi

	if [ $refgenome == 'Rattus_norvegicus' ] ;then
		ribosomal_intervals=${ratAnnotationDir}/Rattus_norvegicus.Rnor_5.0.74.ribosomal.intervals
		annotationfile=${ratAnnotationDir}/Rattus_norvegicus.Rnor_5.0.74.refFlat.txt
		genomefile=${ratGenomeDir}/genome.fa
		step=$step."human"
	fi
fi


if [ -n "$2" -a -n "$3" -a -n "$4" ] ; then
	echo "User provided custom reference genome"
genomefile=$2
ribosomal_intervals=$3
annotationfile=$4
fi


strand=$( ngs-sampleInfo.pl $input stranded )
if [ "$strand" == 'REVERSE' ]; then
	strand='SECOND_READ_TRANSCRIPTION_STRAND'
fi
if [ "$strand" == 'FORWARD' ]; then
	strand='FIRST_READ_TRANSCRIPTION_STRAND'
fi


NGS_LOG_DIR=${NGS_LOG_DIR}/${step}

cores=$(fullcores)

memory=32000
stem=$(fileStem $input)

mkdir -p $NGS_LOG_DIR

header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#BSUB -E \"$scriptDir/../lib/stageReference.sh $step\"
#$Date: 2015-08-14 13:02:55 -0700 (Fri, 14 Aug 2015) $ $Revision: 1624 $
source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step $1

input=\$( stage.pl --operation out --type file  $input )
inputIndex=\$(stage.pl --operation out --type file  $index )
genomefile=$genomefile
genomefileIndex=$genomefile.fai
annotationfile=$annotationfile
ribosomal_intervals=$ribosomal_intervals

newDir=\$( lastDir \$input | sed 's%bamfiles%bamQC%')
outputDirectory=\$( setOutput \$input \$newDir/${step} )




celgeneExec.pl --analysistask ${analysistask} \"\
java -Xmx${memory}m -jar ${PICARD_BASE}/picard.jar CollectRnaSeqMetrics \
 VERBOSITY=WARNING \
 INPUT=\$input \
 TMP_DIR=\${NGS_TMP_DIR} \
 REF_FLAT=\${annotationfile} \
 RIBOSOMAL_INTERVALS=\${ribosomal_intervals} \
 LEVEL=ALL_READS  REFERENCE_SEQUENCE=\${genomefile} \
 CHART=\${outputDirectory}/$stem.${step}.pdf \
 O=\${outputDirectory}/$stem.${step}.qcstats \
 STRAND_SPECIFICITY=$strand \
 VALIDATION_STRINGENCY=SILENT \"
if [ \$? != 0 ] ; then
	echo "Failed to execute command"
	exit 1
fi  
runQC-bam.pl --logfile \$MASTER_LOGFILE --inputbam \$input --outputfile \${outputDirectory}/$stem.${step}.qcstats --reuse --qcStep CollectRNASeqMetrics
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
" > ${stem}.${step}.bsub

bsub < ${stem}.${step}.bsub
#rm $$.tmp

