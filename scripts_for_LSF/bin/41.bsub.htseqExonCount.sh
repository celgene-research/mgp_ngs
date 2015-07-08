#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1
analysistask=54
checkfile $input
step="htseqExonCount"
index=$(echo $input|sed 's/bam$/bai/');




stem=$(fileStem $input)

strandness=$( ngs-sampleInfo.pl $input stranded )
strandoption=" -s yes "
if [ $strandness == "NONE" ]; then 
	strandoption=" -s no "
fi
if [ $strandness == "REVERSE" ] ; then
	strandoption=" -s reverse "
fi
if [ $strandness == "FORWARD" ] ; then
	strandoption=" -s yes "
fi

refgenome=$(ngs-sampleInfo.pl $input  reference_genome)
if [ -n $geneFeature ] ; then
geneFeature="gene_name"
fi

if [ $refgenome == 'Homo_sapiens' ] ; then
		reference=${humanAnnotationDir}/gencode.flattened.gff
		step=$step.human
fi
if [ $refgenome == 'Rattus_norvegicus' ] ;then
	echo "This script runs only for human genome"
	exit
	#reference=${ratAnnotationDir}/Rattus_norvegicus.Rnor_5.0.74.gtf
	#geneFeature="gene_id" #the gtf file does not have gene_name anyway
	step=$step.rat
fi

export NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR

cores=2

memory=4000

dexseqcountbin=dexseq_count.py
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#BSUB -E \"$scriptDir/../lib/stageReference.sh $step\"
#$Date: 2015-06-08 17:37:49 -0700 (Mon, 08 Jun 2015) $ $Revision: 1594 $


source $scriptDir/../lib/shared.sh

initiateJob $stem $step

input=\$( stage.pl --operation out --type file  $input )
inputIndex=\$(stage.pl --operation out --type file  $index )
reference=$reference

outputDirectory=\$( setOutput \$input $step )

celgeneExec.pl --analysistask ${analysistask} \"\
$samtoolsbin view -F 4 \${input} | \
cut -f 1-14 | \
$dexseqcountbin $strandoption -p yes \${reference} -  \${outputDirectory}/${stem}.htXseq-count \"
if [ \$? != 0 ] ; then
	echo "Failed to run command"
	exit 1
fi 
ingestDirectory \$outputDirectory
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 
closeJob

" > ${stem}.bsub

bsub < ${stem}.bsub
#rm $$.tmp

