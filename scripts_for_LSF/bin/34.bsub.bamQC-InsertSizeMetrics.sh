#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1

checkfile $input

analysistask=58
step="InsertSize"

index=$(echo $input|sed 's/bam$/bai/');
refgenome=$(ngs-sampleInfo.pl $input reference_genome)
paired=$(ngs-sampleInfo.pl  $input paired_end )
hostgenome=$(ngs-sampleInfo.pl $input host_genome)
refdatabase=$( ngs-sampleInfo.pl $input xenograft )
if [ "$paired" == "0" ] ; then echo "This is not a paired end sequencing experiment"; exit ;fi 
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

if [ -n "$2" ] ; then
	echo "User provided custom reference genome"
genomefile=$2
fi

cores=$(fullcores)

memory=16000
stem=$(fileStem $input)


initiateJob $stem $step $1
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


newDir=\$( lastDir \$input | sed 's%bamfiles%bamQC%')
outputDirectory=\$( setOutput \$input \$newDir/${step} )




celgeneExec.pl --analysistask ${analysistask} \"\
java -Xmx${memory}m -jar ${PICARD_BASE}/picard.jar CollectInsertSizeMetrics \
VERBOSITY=WARNING \
INPUT=\$input \
TMP_DIR=\${NGS_TMP_DIR}	\
LEVEL=ALL_READS  \
REFERENCE_SEQUENCE=\${genomefile} \
H=\${outputDirectory}/$stem.${step}.pdf \
O=\${outputDirectory}/$stem.${step}.qcstats \
VALIDATION_STRINGENCY=SILENT \"
 if [ \$? != 0 ] ; then
	echo "Failed to execute command"
	exit 1
fi 
runQC-bam.pl --logfile \$MASTER_LOGFILE --inputbam \$input --outputfile \${outputDirectory}/$stem.${step}.qcstats --reuse --qcStep CollectInsertSize
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

