#!/bin/bash

echo "This script is used to merge fastq files"
echo "That appears in multiple pieces in the same directory"
echo "Provide the filenames as input"
echo "and the _first_ argument will be the stem filename (without the fq part and the compressed extension"


scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh

stem=$1
shift # disgards the first argument (which is stored as stem)
inputDirectory=$@
step="mergeFastq"
analysistask=$step

mkdir -p $NGS_LOG_DIR

memory=2000
cores=1
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header


#$Date: 2015-10-15 17:44:21 -0700 (Thu, 15 Oct 2015) $ $Revision: 1719 $

source $scriptDir/../lib/shared.sh

initiateJob $stem $step $1
set -e


filestr1=\"\"
for i in "$inputDirectory" ;do
	i=\$( stage.pl --type file --operation out \${i} )
	filestr1="\${filestr1} \${i}"
done



outputDirectory=\$( setOutput \$i ${step} )

celgeneExec.pl --analysistask $analysistask \"\
bzcat \$filestr > \${outputDirectory}/$stem.fq ; \
gzip \${outputDirectory}/$stem.R1.fq \
\"
if [ \$? != 0 ] ; then
	echo \"Failed to run command\"
	exit 1
fi 


ingestDirectory \$outputDirectory
if [ \$? != 0 ] ; then
	echo \"Failed to ingest data\"
	exit 1
fi 

closeJob

"> $stem.$step.bsub


bash $stem.$step.bsub
#bsub < $stem.$step.bsub
#rm $$.tmp
