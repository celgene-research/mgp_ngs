#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1
reads=$2
index=$(echo $input|sed 's/bam$/bai/');
echo "This script uses the picard tools downsample  subsample a bam file to a requested number of reads"

# get the number of sequenced reads for the sample
seqreads=$( ngs-sampleInfo.pl $input pf_reads_aligned )
seqreads=$( echo $seqreads | cut -d ',' -f 1 )
if [ $(echo "$reads<=1" | bc) == "1" ] ; then
	echo "User supplied probability directly"
	probability=$reads
else 
	probability=$( echo $reads/$seqreads | bc -l )
	echo "User requested to sample $reads reads"
	if [ $( echo "$probability > 1" | bc -l ) == "1" ] ; then
		echo "Probability is $probability which is greater than 1, will change it to 1"
		probability="1"
	fi
fi
#echo "The file comes from $seqreads sequenced reads and to downsample it to $reads reads we will set the probability of extraction to $probability"


echo "The file comes from $seqreads sequenced reads and to downsample it to the requested number of reads we will set the probability of extraction to $probability"

checkfile $input

analysistask=52
step="Subsample"

cores=2 # to ensure better balance of cpu and disk
#necessary adjustment due to limitations in storage space on AWS instances

memory=1000
stem=$(fileStem $input)
initiateJob $stem $step $1

header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-08-14 13:02:55 -0700 (Fri, 14 Aug 2015) $ $Revision: 1624 $

initiateJob $stem $step $1

input=\$( stage.pl --operation out --type file  $input )
index=\$( stage.pl --operation out --type file  $index )
if [ \$input == "FAILED"  ] ; then
	echo \"Could not transfer \$input\"
	exit 1
fi

newDir=\$( lastDir \$input | sed 's%bamfiles%bamfile%' | sed 's%bamfile%bamSubsample%' )

outputDirectory=\$( setOutput \$input \$newDir )


celgeneExec.pl --analysistask ${step} \"\
java -Xmx${memory}m -jar ${PICARDBASE}/picard.jar DownsampleSam \
 VERBOSITY=WARNING \
 INPUT=\$input \
 TMP_DIR=\${NGS_TMP_DIR} \
 O=\${outputDirectory}/$stem.coord.bam \
 CREATE_INDEX=TRUE \
 PROBABILITY=${probability} \
 VALIDATION_STRINGENCY=SILENT \"
 if [ \$? != 0 ] ; then
	echo "Failed to run command"
	exit 1
fi 

ingestDirectory \$outputDirectory
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 
closeJob

" > ${stem}.${step}.$( getStdSuffix ).bsub
bsub < ${stem}.${step}.$( getStdSuffix).bsub
#rm $$.tmp

