#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1

checkfile $input

analysistask=53
geneFeature=$2 # feature from gtf file to use as gene identifier in the output

step="htseqGeneCount"
index=$(echo $input|sed 's/bam$/bai/');




cores=2

memory=4000
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
refgenome="Homo_sapiens"
if [ -n $geneFeature ] ; then
geneFeature="gene_name"
fi

if [ $refgenome == 'Homo_sapiens' ] ; then
		reference=${humanAnnotationDir}/gencode.annotation.gtf
		step=$step.human
fi

if [ $refgenome == 'Rattus_norvegicus' ] ;then
	reference=${ratAnnotationDir}/Rattus_norvegicus.Rnor_5.0.74.gtf
	geneFeature="gene_id" #the gtf file does not have gene_name anyway
	step=$step.rat
fi

export NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR

## do some sanity check
if [ "$refgenome" == "NA" -o -z "$strandness" ]; then
	echo "Cannot find the reference genome [$refgenome] or strandness [$strandness] associated with $input"
	exit 1
fi




htseqCountBin=htseq-count
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#BSUB -E \"$scriptDir/../lib/stageReference.sh $step\"
#$Date: 2015-08-14 13:02:55 -0700 (Fri, 14 Aug 2015) $ $Revision: 1624 $

source $scriptDir/../lib/shared.sh

initiateJob $stem $step


input=\$( stage.pl --operation out --type file  $input )
#inputIndex=\$(stage.pl --operation out --type file  $index )
reference=$reference

if [  \"\$input\" == \"FAILED\" ] ; then
	echo "Could not transfer either \$reference or \$input"
	exit 1
fi

outputDirectory=\$( setOutput \$input $step )




#in htseq 0.6.1 although sorting by position is supported
# it seems to have bugs so we need to sort by name first
# Although htseq can now read from bam files I prefer to first
# read the bam file with samtools view, so as to apply any filters
# that would crash htseq ( e.g. remove xenograft related filters)

# TODO
# it remains to be tested if the duplicates need to be removed from the 
# bam file (or filtered out) for counting


celgeneExec.pl --analysistask ${analysistask} \" \
 $samtoolsbin view \${input} |  \
 cut -f 1-14 | \
 $htseqCountBin -t exon  ${strandoption} -i $geneFeature - \${reference} >\
  \${outputDirectory}/${stem}.htseq-count \"

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
" > ${stem}.${step}.bsub

bsub < ${stem}.${step}.bsub
#rm $$.tmp

