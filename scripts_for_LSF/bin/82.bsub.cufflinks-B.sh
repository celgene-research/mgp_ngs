#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh

analysistask=62

step="cufflinks"
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
if [ $strandness == "FORWARD" ] ; then
	libraryType="fr-secondstrand"
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


#$Date: 2015-06-10 17:41:49 -0700 (Wed, 10 Jun 2015) $ $Revision: 1600 $


source $scriptDir/../lib/shared.sh 
initiateJob $stem $step $1

inputBAM=\$( stage.pl --operation out --type file  $inputBAM )
inputIndex=\$(stage.pl --operation out --type file  $index )
inputGFF=$inputGFF
maskFile=$maskFile
reference=$reference

outputDirectory=\$( setOutput \$inputBAM ${step}-transcriptCounts/)


celgeneExec.pl --analysistask $analysistask \"\
$cufflinks -p $cores \
  --output-dir \${outputDirectory}/tmp \
  --library-type $libraryType -G \${inputGFF}  \
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

ingestDirectory \$outputDirectory yes
if [ \$? != 0 ] ; then
	echo \"Failed to ingest data\"
	exit 1
fi 
	
closeJob	
	
	" > ${stem}.${step}.$( getStdSuffix ).bsub
	
	bsub < ${stem}.${step}.$( getStdSuffix ).bsub

