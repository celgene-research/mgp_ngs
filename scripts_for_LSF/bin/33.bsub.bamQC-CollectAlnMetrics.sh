#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1

checkfile $input

analysistask=58
step="CalculateAlnMetrics"

index=$(echo $input|sed 's/bam$/bai/');
hostgenome=$(ngs-sampleInfo.pl $input host_genome)
refdatabase=$( ngs-sampleInfo.pl $input xenograft )
refgenome=$(ngs-sampleInfo.pl $input reference_genome)

if [ -z "$refgenome" ]; then echo "Could not find reference genome. Exiting";exit;fi
if [ $refdatabase == '1' ] ; then
	echo "$input is a xenograft sample of $refgenome tissue on $hostgenome" 
	if [ "$hostgenome" == "Mus_musculus" -a "$refgenome" == "Homo_sapiens" ] ; then
		genomefile=${human_mouseGenomeDir}/genome.fa
		step=${step}".xenograft"
	else
		echo "Cannot find database for host genome $hostgenome"
		exit
	fi
	#exit
else
	if [ $refgenome == 'Homo_sapiens' ] ; then
		genomefile=${humanGenomeDir}/genome.fa
		step=${step}".human"
		
	fi

	if [ $refgenome == 'Rattus_norvegicus' ] ;then
		genomefile=${ratGenomeDir}/genome.fa
		step=${step}".rat"
		
	fi
fi




NGS_LOG_DIR=${NGS_LOG_DIR}/${step}

cores=$(fullcores)

memory=16000
stem=$(fileStem $input)

mkdir -p $NGS_LOG_DIR

header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#BSUB -E \"$scriptDir/../lib/stageReference.sh $step\"
#$Date: 2015-06-01 18:04:39 -0700 (Mon, 01 Jun 2015) $ $Revision: 1527 $
source $scriptDir/../lib/shared.sh

initiateJob $stem $step
set -e

input=\$( stage.pl --operation out --type file  $input )
inputIndex=\$(stage.pl --operation out --type file  $index )
genomefile=$genomefile
genomefileIndex=$genomefile.fai


newDir=\$( lastDir \$input | sed 's%bamfiles%bamQC%')
outputDirectory=\$( setOutput \$input \$newDir/${step} )





celgeneExec.pl --analysistask ${analysistask} \"\
java -Xmx${memory}m -jar ${PICARD_BASE}/picard.jar CollectAlignmentSummaryMetrics \
 VERBOSITY=WARNING \
 INPUT=\$input \
 TMP_DIR=\${NGS_TMP_DIR} \
 REFERENCE_SEQUENCE=\${genomefile}  \
 O=\${outputDirectory}/$stem.${step}.qcstats \
 VALIDATION_STRINGENCY=SILENT \"

if [ $? != 0 ] ; then
	echo "Failed to run command"
	exit 1
fi 
runQC-bam.pl --logfile \$MASTER_LOGFILE  --inputbam \$input --outputfile \${outputDirectory}/$stem.${step}.qcstats --reuse --qcStep CollectAlnSummary
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

