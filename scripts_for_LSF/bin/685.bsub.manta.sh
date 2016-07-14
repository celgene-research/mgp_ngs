#!/bin/bash

inputsample=$1
inputcontrol=$2

echo "This script is running the manta pipeline"
echo "it requires as input the sample file and if available the control file "
echo "This version of the script assumes Whole Genome Sequencing and not Exome. "
echo " This corresponds to the Tumor Normal analysis example configuration in the manta web site"


scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
analysistask=59
step="manta.human"
stem=$(fileStem $inputsample)


nameinputsample=$(stage.pl --name $inputsample )
if [ -z "$inputcontrol" ]; then
	echo "Please provided control as well"
	exit
fi
stemB=$(fileStem $inputcontrol)
stem=${stem}-${stemB}

nameinputcontrol=$(stage.pl --name $inputcontrol )

initiateJob $stem $step $1
memory=16000
cores=$(fullcores)


# first we create the config file per http://bioinfo-out.curie.fr/projects/freec/tutorial.html
reference=${humanGenomeDir}/genome.fa
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-10-01 15:43:49 -0700 (Thu, 01 Oct 2015) $ $Revision: 1676 $
source $scriptDir/../lib/shared.sh 
initiateJob $stem $step $1

inputsampleidx=\$( echo $inputsample | sed 's/bam$/bai/' ) 
inputsample=\$( stage.pl --operation out --type file  $inputsample)
inputsampleidx=\$( stage.pl --operation out --type file  \$inputsampleidx)
if [ -n \"$inputcontrol\" ]; then
	inputcontrolidx=\$( echo $inputcontrol | sed 's/bam$/bai/' ) 
	inputcontrol=\$( stage.pl --operation out --type file  $inputcontrol)
	inputcontrolidx=\$( stage.pl --operation out --type file  $inputcontrolidx)
	
fi

if [ \$inputsample == \"FAILED\" ]; then
	echo \"Could not transfer \$inputsample\"
	exit 1
fi
outputDirectory=\$( setOutput \$inputsample ${step} )


celgeneExec.pl --analysistask $analysistask \"\
\$configmantabin \
--normalBam \$inputcontrol \
--tumorBam \$inputsample \
--referenceFasta $reference \
--runDir \${outputDirectory}/$stem \
\"


if [ \$? != 0 ] ; then
	echo "Failed to run command"
	exit 1
fi 

ingestDirectory \$outputDirectory yes
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 

closeJob

" >${stem}.${step}.$( getStdSuffix ).bsub
bsub < ${stem}.${step}.$( getStdSuffix ).bsub
