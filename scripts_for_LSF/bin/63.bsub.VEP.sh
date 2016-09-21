#!/bin/bash

# this script is using SICER to call peaks from chipseq datasets
#
# it can be used to either call broad or sharp peaks
# it will ask the db for the type of ChIPseq experiment and adjust accordingly



scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
inputVCF=$1


checkfile $inputVCF

stem1=$(fileStem $inputVCF)
step="VEP"
executable=$(echo $vepbin | rev | cut -d ' ' -f 1 | rev)

analysistask=38

cores=$(fullcores) #VEP uses a lot of memory (~10GB/fork). We request for all the cores, to get the full node, but we use only 2 forks.
memory=$(fullmemory)

initiateJob $stem $step $1
header=$(bsubHeader $stem $step $memory $cores)

echo \
"$header

#$Date: 2015-10-05 17:46:45 -0700 (Mon, 05 Oct 2015) $ $Revision: 1690 $

source $scriptDir/../lib/shared.sh 
initiateJob $stem $step $1





inputVCF=\$( stage.pl --operation out --type file  ${inputVCF} )


####################
if [ \$inputVCF == \"FAILED\"  ] ; then
	echo \"Could not transfer \$inputVCF \"
	exit 1
fi

outputDirectory=\$( setOutput \$inputVCF ${step} )



celgeneExec.pl \
--executable ${executable} \
--analysistask ${step} \"\
$vepbin  \
-i \${inputVCF} \
--cache \
--offline \
--merged \
--everything \
--force_overwrite \
-o \${outputDirectory}/${stem} \
--fork 2
 ; \
\"



ingestDirectory \$outputDirectory yes
if [ \$? -ne 0 ] ; then
	echo \"Failed to ingest data\"
	exit 1
fi 


closeJob
"> ${stem}.${step}.$( getStdSuffix ).bsub

bsub < ${stem}.${step}.$( getStdSuffix ).bsub
