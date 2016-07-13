#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
inputBam=$1 # this is the normal
inputBamTumor=$2

echo "This script uses GNU paralled to create the seqz files"
echo "in this version only human is assumed"

analysistask=56

stem=$(fileStem $inputBamTumor)

step="Sequenza"
step=${step}".human"
initiateJob $stem $step $1


ref=${humanGenomeDir}/genome.fa
gcfile=${humanGenomeDir}/ExonCapture/hg19.gc50Base.txt.gz # this is the gc file for sequenza
inputIdx=$(echo $inputBam| sed 's/bam$/bai/')
inputIdxTumor=$(echo $inputBamTumor| sed 's/bam$/bai/')
cores=$(fullcores) # they are used by the pileup section
memory=5000


header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-08-19 10:49:41 -0700 (Wed, 19 Aug 2015) $ $Revision: 1628 $
source $scriptDir/../lib/shared.sh 
initiateJob $stem $step $1


inputBam=\$(stage.pl --operation out --type file  $inputBam)
inputIdx=\$(stage.pl --operation out --type file  $inputIdx)

inputBamTumor=\$(stage.pl --operation out --type file  $inputBamTumor)
inputIdxTumor=\$(stage.pl --operation out --type file  $inputIdxTumor)

outputDirectory=\$( setOutput \$inputBamTumor $step )

analyze() {
  /celgene/software/sequenza/sequenza-2.1.2/sequenza/exec/sequenza-utils.py bam2seqz -n \${inputBam} -t \${inputBamTumor} -F ${ref} -gc ${gcfile} -C \$1 |  gzip > \${outputDirectory}/\$1.seqz.gz ; echo \"Output in \${outputDirectory}/\$1.seqz.gz\"
}
export -f analyze
export inputBam
export inputBamTumor
export outputDirectory


celgeneExec.pl \
 -o \${outputDirectory}/${stem}.seqz.gz \
 -D \${inputBam},\${inputBamTumor} \
 --metadatastring analyze='/celgene/software/sequenza/sequenza-2.1.2/sequenza/exec/sequenza-utils.py bam2seqz -n \${inputBam} -t \${inputBamTumor} -F ${ref} -gc ${gcfile} -C \$1 | gzip > \${outputDirectory}/\$1.seqz.gz'\
 --analysistask=$step \"\
parallel -j${cores} analyze chr{} :::  {1..22} X Y ; \
gunzip -c \${outputDirectory}/chr{{1..22},{X,Y}}.seqz.gz | gzip > \${outputDirectory}/${stem}.seqz.gz ; \
rm \${outputDirectory}/chr{{1..22},{X,Y}}.seqz.gz \
\"

#celgeneExec.pl --analysistask=$step \"\
#$sequenzabin -n \${inputBam} -t \${inputBamTumor} -o \${outputDirectory}.qcstats -G ${gcfile} -F ${ref} -c $cores \
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


