#!/bin/bash
inputcontrol=$1
inputsample=$2


echo "This script is running the breakdancer pipeline"
echo "it requires as input the sample file and if available the control file "


scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
analysistask=59
step="breakdancer"
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
	inputcontrolidx=\$( stage.pl --operation out --type file  \$inputcontrolidx)
	
fi

if [ \$inputsample == \"FAILED\" ]; then
	echo \"Could not transfer \$inputsample\"
	exit 1
fi
outputDirectory=\$( setOutput \$inputsample ${step} )

analyze() {
	if [ \"\$1\" == \"chrT\" ] ; then
		$breakdancermaxbin -t -q 10 -d $stem \${outputDirectory}/$stem.strvar/$stem.cfg > \${outputDirectory}/$stem.strvar/$stem.transchrom.ctx
	else
		$breakdancermaxbin -o \$1 -q 10 -d $stem \${outputDirectory}/$stem.strvar/$stem.cfg > \${outputDirectory}/$stem.strvar/$stem.\$1.ctx
	fi
}

export -f analyze
export outputDirectory

#breakdancer expects the bam index in a bam.bai file
ln \$inputsampleidx \$inputsample.bai
ln \$inputcontrolidx \$inputcontrol.bai

celgeneExec.pl --analysistask $analysistask \
--metadatastring analyze='if \[ \"\$1\" == \"chrT\" \] \; then\
		$breakdancermaxbin -t -q 10 -d $stem \${outputDirectory}/$stem.strvar/$stem.cfg > \${outputDirectory}/$stem.strvar/$stem.transchrom.ctx\
	else\
		$breakdancermaxbin -o \$1 -q 10 -d $stem \${outputDirectory}/$stem.strvar/$stem.cfg > \${outputDirectory}/$stem.strvar/$stem.\$1.ctx\
	fi'  \"\
mkdir -p \${outputDirectory}/$stem.strvar/ ; \
cd \${outputDirectory}/$stem.strvar/ ; \
perl $bam2cfgbin -g -h \$inputsample \$inputcontrol > \${outputDirectory}/$stem.strvar/$stem.cfg ; \
parallel -j${cores} analyze chr{} :::  {1..22} X Y T \
\"

# remove the workspace directory with temporary and working copies.
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
