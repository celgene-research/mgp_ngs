#!/bin/bash

# this script is using macs2 to call peaks from chipseq datasets
#
# it can be used to either call broad or sharp peaks
# it will ask the db for the type of ChIPseq experiment and adjust accordingly



scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
inputBedGraph=$1
checkfile $inputBedGraph
chromInfo=$(dirname $inputBedGraph)/chromInfo.txt
stem=$(fileStem $inputBedGraph)

step="peak-wig"

analysistask=38

cores=2 #MACS does not need many cores, but when run many instances on the same machine there are crashes.
memory=3000
initiateJob $stem $step $1
header=$(bsubHeader $stem $step $memory $cores)



echo \
"$header

#$Date: 2015-08-19 10:49:41 -0700 (Wed, 19 Aug 2015) $ $Revision: 1628 $

source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step $1





inputBedGraph=\$( stage.pl --operation out --type file  ${inputBedGraph} )
chromInfo=\$( stage.pl --operation out --type file $chromInfo )

####################
if [ \$inputBedGraph == \"FAILED\"  ] ; then
	echo \"Could not transfer \$inputBedGraph  \"
	exit 1
fi

outputDirectory=\$( setOutput \$inputBedGraph ${step} )
export LC_COLLATE=C 

celgeneExec.pl --analysistask ${analysistask} \"\
$bedtoolsbin slop -i \${inputBedGraph} -g \${chromInfo} -b 0 | \
$bedClipbin stdin /\${chromInfo} stdout | \
sort -T \${outputDirectory}  -k1,1 -k2,2n  > \${outputDirectory}/${stem}.bdg.clip ; \
$bedGraphToBigWigbin \${outputDirectory}/${stem}.bdg.clip \${chromInfo} \${outputDirectory}/${stem}.bigwig \
\"


ingestDirectory \$outputDirectory yes
if [ \$? -ne 0 ] ; then
	echo \"Failed to ingest data\"
	exit 1
fi 


closeJob
"> ${stem}.${step}.bsub

bsub < ${stem}.${step}.bsub
