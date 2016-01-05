#!/bin/bash

# use this script to generate a tags directory used with HOMER (http://homer.salk.edu/homer/ngs/index.html)
# The input of the script is a bam file (preferably a file with marked duplicates)
# The output of the script will be in the bamQC directory

scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
inputBAM=$1
analysistask=48

index=$(echo $inputBAM|sed 's/bam$/bai/');

checkfile $inputBAM

step="HomerQC"
stem=$(fileStem $inputBAM)
NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
memory=8000
cores=2
genomeVersion="hg19"

mkdir -p $NGS_LOG_DIR
header=$(bsubHeader $stem $step $memory $cores)
echo "$header

#$Date: 2015-10-16 16:10:53 -0700 (Fri, 16 Oct 2015) $ $Revision: 1722 $
source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step

inputBAM=\$( stage.pl --operation out --type file  $inputBAM )
inputIndex=\$(stage.pl --operation out --type file  $index )



newDir=\$( lastDir \$inputBAM | sed 's%bamfiles%bamQC%')
outputDirectory=\$( setOutput \$inputBAM \$newDir/${step} )
output=\${outputDirectory}/${stem}.${step}.qcstats
mkdir -p \${outputDirectory}/tmp

celgeneExec.pl --analysistask ${analysistask} \"
makeTagDirectory  \
	\${outputDirectory}/tmp \
	-format sam \
	-genome ${genomeVersion} \
	-checkGC \
	\$inputBAM ; \
mv \${outputDirectory}/tmp \${output} \" 


runQC-bam.pl --logfile \$MASTER_LOGFILE --inputbam \$inputBAM --outputfile \${outputDirectory}/$stem.${step}.qcstats --reuse --qcStep Homer
if [ \$? != 0 ] ; then
	echo "Failed to update database"
	exit 1
fi 


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

