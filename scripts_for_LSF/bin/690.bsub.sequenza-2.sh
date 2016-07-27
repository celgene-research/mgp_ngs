#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
inputPileup=$1 # this is the normal
inputPileupTumor=$2

echo "This script uses GNU paralled to create the seqz files"
echo "in this version only human is assumed"
echo "As input it expects a pileup.gz file indexed with tabix"

analysistask=56

stem=$(fileStem $inputPileupTumor)

step="Sequenza"
step=${step}".human"
initiateJob $stem $step $1


ref=${humanGenomeDir}/genome.fa
gcfile=${humanGenomeDir}/ExonCapture/hg19.gc50Base.txt.gz # this is the gc file for sequenza
inputIdx=${inputPileup}.tbi
inputIdxTumor=${inputPileupTumor}.tbi
cores=$(fullcores) # they are used by the pileup section
memory=5000


header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-08-19 10:49:41 -0700 (Wed, 19 Aug 2015) $ $Revision: 1628 $
source $scriptDir/../lib/shared.sh 
initiateJob $stem $step $1


inputPileup=\$(stage.pl --operation out --type file  $inputPileup)
inputIdx=\$(stage.pl --operation out --type file  $inputIdx)

inputPileupTumor=\$(stage.pl --operation out --type file  $inputPileupTumor)
inputIdxTumor=\$(stage.pl --operation out --type file  $inputIdxTumor)

outputDirectory=\$( setOutput \$inputPileupTumor $step )

analyze() {
/celgene/software/sequenza/sequenza-2.1.2/sequenza/exec/sequenza-utils.py pileup2seqz \
-n <($tabixbin \${inputPileup} \$1) \
-t <($tabixbin \${inputPileupTumor} \$1) \
-gc ${gcfile} |\
gzip > \${outputDirectory}/\$1.seqz.gz ; echo \"Output in \${outputDirectory}/\$1.seqz.gz\"
}
export -f analyze
export inputPileup
export inputPileupTumor
export outputDirectory


celgeneExec.pl \
 -o \${outputDirectory}/${stem}.seqz.gz \
 -D \${inputPileup},\${inputPileupTumor} \
 --metadatastring analyze='/celgene/software/sequenza/sequenza-2.1.2/sequenza/exec/sequenza-utils.py pileup2seqz \
-n <($tabixbin \${inputPileup} $1) \
-t <($tabixbin \${inputPileupTumor} $1) \
-gc ${gcfile} |\
gzip > \${outputDirectory}/\$1.seqz.gz ; echo \"Output in \${outputDirectory}/\$1.seqz.gz\"'\
 --analysistask=$step \"\
parallel -j${cores} analyze chr{} :::  {1..22} X Y ; \
gunzip -c \${outputDirectory}/chr{{1..22},{X,Y}}.seqz.gz | gzip > \${outputDirectory}/${stem}.seqz.gz ; \
rm \${outputDirectory}/chr{{1..22},{X,Y}}.seqz.gz \
\"

#celgeneExec.pl --analysistask=$step \"\
#$sequenzabin -n \${inputPileup} -t \${inputPileupTumor} -o \${outputDirectory}.qcstats -G ${gcfile} -F ${ref} -c $cores \
#\"

if [ \$? != 0 ] ; then
	echo "Failed to execute command"
	exit 1
fi 
ingestDirectory \${outputDirectory}
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 

closeJob
" > ${stem}.${step}.$( getStdSuffix ).bsub

bsub < ${stem}.${step}.$( getStdSuffix ).bsub


