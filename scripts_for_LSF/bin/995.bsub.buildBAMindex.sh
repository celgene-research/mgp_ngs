#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1

checkfile $input

analysistask=52
step="BuildBamIndex"


NGS_CORE_FACTOR=2
cores=1
#necessary adjustment due to limitations in storage space on AWS instances

memory=10000
stem=$(fileStem $input)
initiateJob $stem $step $1
mkdir -p $NGS_LOG_DIR

header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-08-14 13:02:55 -0700 (Fri, 14 Aug 2015) $ $Revision: 1624 $
source $scriptDir/../lib/shared.sh

initiateJob $stem $step $1
set -e

input=\$( stage.pl --operation out --type file  $input )
if [ \$input == "FAILED"  ] ; then
	echo \"Could not transfer \$input\"
	exit 1
fi


outputDirectory=\$( setOutput \$input "bamfiles" )

bb=\$(basename \$input)
celgeneExec.pl --analysistask ${analysistask} \"\
mv \$input \${outputDirectory}/\${bb} ; \
java -Xmx${memory}m -jar ${PICARDBASE}/picard.jar BuildBamIndex VERBOSITY=WARNING INPUT=\${outputDirectory}/\${bb} \
  TMP_DIR=\${NGS_TMP_DIR}  VALIDATION_STRINGENCY=SILENT \"
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

" > ${stem}.${step}.${suffix}.bsub

bsub < ${stem}.${step}.${suffix}.bsub
#rm $$.tmp

