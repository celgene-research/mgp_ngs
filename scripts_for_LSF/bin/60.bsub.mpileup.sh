#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
inputBam=$1

echo "This script uses the samtools to create a pileup from a single bam file"
echo "which can be further used as input to a variety of subsequent steps"
echo "The output file is gzip compressed"

analysistask=56

stem=$(fileStem $inputBam)

step="mpileup"

initiateJob $stem $step $1
ref=${humanGenomeDir}/genome.fa
inputIdx=$(echo $inputBam| sed 's/bam$/bai/')
cores=$(fullcores) # simply because we want the full node for its disk space
memory=5000

header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-08-19 10:49:41 -0700 (Wed, 19 Aug 2015) $ $Revision: 1628 $
source $scriptDir/../lib/shared.sh 
initiateJob $stem $step $1


inputBam=\$(stage.pl --operation out --type file  $inputBam)
inputIdx=\$(stage.pl --operation out --type file  $inputIdx)
outputDirectory=\$( setOutput \$inputBam $step )


analyze() {
$samtoolsbin mpileup -f $ref \${inputBam}  |  gzip > \${outputDirectory}/\$1.pileup.gz ; echo \"Output in \${outputDirectory}/\$1.seqz.gz\"
}
export -f analyze
export inputBam
export outputDirectory


celgeneExec.pl \
-o \${outputDirectory}/${stem}.pileup.gz \
 -D \${inputBam} \
 --metadatastring analyze='\$samtoolsbin mpileup -f $ref \${inputBam}  |  gzip > \${outputDirectory}/\$1.pileup.gz ; echo \"Output in \${outputDirectory}/\$1.seqz.gz\"' \
 --analysistask=$step \"\
parallel -j${cores} analyze chr{} :::  {1..22} X Y ; \
gunzip -c \${outputDirectory}/chr{{1..22},{X,Y}}.seqz.gz | $bgzipbin > \${outputDirectory}/${stem}.mpileup.gz ; \
rm \${outputDirectory}/chr{{1..22},{X,Y}}.seqz.gz ; \
$tabixbin -s 1 -e 2 -b 2 \${outputDirectory}/${stem}.mpileup.gz \
\"


celgeneExec.pl --analysistask=$step \"\
$samtoolsbin mpileup  -f $ref \$inputBam | gzip > \${outputDirectory}/${stem}.pileup.gz\
\"

if [ \$? != 0 ] ; then
	echo "Failed to execute command"
	exit 1
fi 
ingestDirectory \$outputDirectory
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 

closeJob
" > ${stem}.${step}.$( getStdSuffix ).bsub

bsub < ${stem}.${step}.$( getStdSuffix ).bsub


