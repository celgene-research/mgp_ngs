#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh

analysistask=62

step="cuffquant"
inputBAM=$1
checkfile $inputBAM
index=$(echo $inputBAM|sed 's/bam$/bai/');
stem=$(fileStem $inputBAM )


strandness=$( ngs-sampleInfo.pl $inputBAM stranded )
if [ $strandness == "NONE" ]; then
	libraryType="fr-unstranded"
fi
if [ $strandness == "REVERSE" ] ; then
	libraryType="fr-firststrand"
fi

refgenome=$(ngs-sampleInfo.pl $inputBAM reference_genome)
if [ $refgenome == 'Homo_sapiens' ] ; then
		reference=${humanChromosomesDir}/contents
		inputGFF=${humanAnnotationDir}/gencode.annotation.gtf
		maskFile=${humanAnnotationDir}/gencode.mask.gtf
		step=$step.human
fi
if [ $refgenome == 'Rattus_norvegicus' ] ;then
	echo "This script runs only for human genome"
	exit
	#reference=${ratAnnotationDir}/Rattus_norvegicus.Rnor_5.0.74.gtf
	#geneFeature="gene_id" #the gtf file does not have gene_name anyway
fi

cores=4
memory=6000
export NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR
header=$(bsubHeader $stem $step $memory $cores)
echo \
	"$header


#$Date: 2015-06-01 18:05:20 -0700 (Mon, 01 Jun 2015) $ $Revision: 1528 $


source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step

inputBAM=\$( stage.pl --operation out --type file  $inputBAM )
inputIndex=\$(stage.pl --operation out --type file  $index )
inputGFF=$inputGFF
maskFile=$maskFile
reference=$reference

outputDirectory=\$( setOutput \$inputBAM ${step}-transcriptCounts/)


celgeneExec.pl --analysistask $analysistask \"\
$cuffquant -p $cores \
  \${inputGFF} \
  --output-dir \${outputDirectory}/tmp \
  --library-type $libraryType -G   \
  --min-isoform-fraction 0.05  -M \${maskFile} \
  --multi-read-correct  \${inputBAM} ; \
mv \${outputDirectory}/tmp \${outputDirectory}/${stem}.cufflinks ; \
mv \${outputDirectory}/${stem}.cufflinks/genes.fpkm_tracking \${outputDirectory}/${stem}.cufflinks/${stem}.genes.fpkm_tracking ; \
mv \${outputDirectory}/${stem}.cufflinks/isoforms.fpkm_tracking \${outputDirectory}/${stem}.cufflinks/${stem}.isoforms.fpkm_tracking 
\"

if [ \$? ne 0 ] ; then
	echo \"Failed to run command\"
	exit 1
fi 

ingestDirectory \$outputDirectory
if [ \$? != 0 ] ; then
	echo \"Failed to ingest data\"
	exit 1
fi 
	
closeJob	
	
	" > ${stem}.${step}.bsub
	
	bsub < ${stem}.${step}.bsub

