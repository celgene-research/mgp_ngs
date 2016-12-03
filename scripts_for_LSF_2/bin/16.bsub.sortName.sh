#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1

checkfile $input 
analysistask=52
step="SortName"



export NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
cores=1
#necessary adjustment due to limitations in storage space on AWS instances

memory=10000
stem=$(fileStem $input)

mkdir -p $NGS_LOG_DIR

header=$(bsubHeader $stem $step $memory $cores)

echo \
"$header

#$Date: 2015-08-14 13:02:55 -0700 (Fri, 14 Aug 2015) $ $Revision: 1624 $
source $scriptDir/../lib/shared.sh

initiateJob $stem $step $1



input=\$( stage.pl --operation out --type file  $input )
if [ \$input == "FAILED"  ] ; then
	echo \"Could not transfer \$input\"
	exit 1
fi

newDir=\$( lastDir \$input | sed 's%bamfiles%bamfiles-SortByReadname%'|| sed 's%SortByCoordinate%%')
outputDirectory=\$( setOutput \$input \$newDir )

celgeneExec.pl --analysistask ${analysistask} \"\
java -Xmx${memory}m -jar ${PICARDBASE}/picard.jar SortSam VERBOSITY=WARNING INPUT=\$input \
  TMP_DIR=\${NGS_TMP_DIR} SORT_ORDER=queryname O=\${outputDirectory}/$stem.name.bam VALIDATION_STRINGENCY=SILENT \"
 if [ \$? != 0 ] ; then
	echo "Failed to run command"
	exit 1
fi 


ingestDirectory  \$outputDirectory
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 

closeJob 
" > ${stem}.${step}.$( getStdSuffix ).bsub

bsub < ${stem}.${step}.$( getStdSuffix ).bsub
#rm $$.tmp
