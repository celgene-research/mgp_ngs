#!/bin/bash

echo "This script is used to merge fastq files that are in multiple pieces in the same directory. It currently assumes bz2 compression"
echo "Provide the filenames as input"
echo "and the _first_ argument will be the stem filename (without the fq part and the compressed extension"
echo "Since the input files can be coming from variable locations using the NGS_PROCESSED_DIRECTORY to set the final destination on the cloud  is recommended"
echo "The resulting consolidated file will be compressed by gzip"


scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh

stem=$1
shift # disgards the first argument (which is stored as stem)
inputDirectory=$@
step="mergeFastq"
analysistask=$step

initiateJob $stem $step $1

memory=2000
cores=1
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header


#$Date: 2015-10-15 17:44:21 -0700 (Thu, 15 Oct 2015) $ $Revision: 1719 $

source $scriptDir/../lib/shared.sh

initiateJob $stem $step $1


filestr1=\"\"
for i in "$inputDirectory" ;do
	i=\$( stage.pl --type file --operation out \${i} )
	filestr1=\"\${filestr1} \${i}\"
	extension=\${filestr1##*.}
done
uncompressBin=\"cat\"
if [ \"\$extension\" == \"bz2\" ] ; then uncompressBin=\"bzcat\" ; fi
if [ \"\$extension\" == \"gz\" ] ; then uncompressBin=\"gunzip -c\" ;  fi

outputDirectory=\$( setOutput \$i ${step} )

celgeneExec.pl --analysistask $analysistask \"\
\$uncompressBin \$filestr1 | \
gzip > \${outputDirectory}/$stem.fq.gz \
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

"> ${stem}.${step}.$( getStdSuffix ).bsub


#bash ${stem}.${step}.$( getStdSuffix ).bsub
bsub < ${stem}.${step}.$( getStdSuffix ).bsub
#rm $$.tmp