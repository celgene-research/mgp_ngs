#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
inputDirectory=$@

analysistask=$step
step="MergeSamFiles"



stem=$( fileStem $1 )

echo "$0 <aligned bam files in a space separated list> "
echo "Currently (May 2016) picard tools has two tools to merge bam files"
echo "This script submits jobs that use the MergeSamFiles tool which "
echo "merges several bam files"


initiateJob $stem $step $1



cores=1 # this is done to provide lighter operations on the nodes
memory=6000

header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-09-15 17:31:31 -0700 (Tue, 15 Sep 2015) $ $Revision: 1644 $
source $scriptDir/../lib/shared.sh
initiateJob $stem $step $1
set -e


filestr1=\"\"
fn=\"\"
for i in "$inputDirectory" ;do
	i=\$( stage.pl --type file --operation out \${i} )
	fn=\${i}
	filestr1=\"\${filestr1} I=\${i} \"
done



outputDirectory=\$( setOutput \$fn $step )


celgeneExec.pl --analysistask $step \"\
java -Xmx6g -jar ${PICARDBASE}/picard.jar MergeSamFiles \
  \${filestr1} \
  OUTPUT=\${outputDirectory}/${stem}.coord.bam \
  SORT_ORDER=coordinate \
  VERBOSITY=WARNING  \
  VALIDATION_STRINGENCY=SILENT\
\" 
if [ \$? != 0 ] ; then
	echo \"Failed to execute command\"
	exit 1
fi 

ingestDirectory \$outputDirectory
if [ \$? != 0 ] ; then
	echo \"Failed to ingest data\"
	exit 1
fi 


closeJob
	"> $stem.$step.bsub

bsub < $stem.$step.bsub
#rm $$.tmp

