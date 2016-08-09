#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh

inputNormalBAM=$1
inputTumorBAM=$2
stem=$(fileStem $inputTumorBAM )
step="Strelka"
analysistask=$step

initiateJob $stem $step $1
genomeDatabase=${humanGenomeDir}/genome.fa


memory=28000
cores=$(fullcores)
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

source $scriptDir/../lib/shared.sh

initiateJob $stem $step $1
inputNormalBAM=\$(stage.pl --operation out --type file  $inputNormalBAM )
indexNormal=\$( echo $inputNormalBAM | sed 's/bam$/bai/' ) 
indexNormal=\$( stage.pl --operation out  --type file \$indexNormal )
inputTumorBAM=\$(stage.pl --operation out --type file  $inputTumorBAM )
indexTumor=\$( echo $inputTumorBAM | sed 's/bam$/bai/' ) 
indexTumor=\$( stage.pl --operation out  --type file \$indexTumor )


outputDirectory=\$( setOutput \$inputTumorBAM ${step} )



# first create the intervals
# second run ContEst
# finally run Mutect2
	
celgeneExec.pl --analysistask $analysistask  \"\
$strelkabin \
 --normal=\${inputNormalBAM} \
 --tumor=\${inputTumorBAM} \
 --ref=$genomeDatabase \
 --config=$strelkaini \
 --output-dir=\${outputDirectory}/${stem}.seqvar ; \
make -C \${outputDirectory}/${stem}.seqvar -j ${cores} \
\"
if [ \$? != 0 ] ; then
	echo \"Failed to run command\"
	exit 1
fi 


ingestDirectory \$outputDirectory yes
if [ \$? != 0 ] ; then
	echo \"Failed to ingest data\"
	exit 1
fi 


closeJob
"> ${stem}.${step}.$( getStdSuffix ).bsub

bsub < ${stem}.${step}.$( getStdSuffix ).bsub
#rm $$.tmp

