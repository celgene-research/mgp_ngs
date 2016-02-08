#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh

step="Bowtie2.ERCC"
input1=$1
analysistask=38
input2=$( getSecondReadFile $input1)

checkfile $input1
checkfile $input2

stem=$(fileStem $input1)

database=${ercc_bowtieidx}

initiateJob $stem $step $1


# end of command arguments
##########################
sample_id=$(ngs-sampleInfo.pl $input1 sample_id )
if [ $sample_id == "NA" ]; then
	sample_id=0
fi
memory=24000
cores=4


header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#BSUB -E \"$scriptDir/../lib/stageReference.sh $step\"
#$Date: 2015-06-01 18:05:20 -0700 (Mon, 01 Jun 2015) $ $Revision: 1528 $
source $scriptDir/../lib/shared.sh
initiateJob $stem $step $1

database=$database
input1=\$( stage.pl --operation out --type file  $input1 )
input2=\$( stage.pl --operation out --type file  $input2 )


if [ \$database == "FAILED" -o \$input1 == "FAILED" -o \$input2 == "FAILED" ] ; then
	echo "Could not transfer either \$database or \$input1 or \$input2"
	exit 1
fi

outputDirectory=\$( setOutput \$input1 ${step}-bamfiles )

celgeneExec.pl --analysistask ${analysistask} \"\
$bowtie2bin --no-unal --very-fast -p $cores  -x \$database/spikes -1 \$input1  -2 \$input2  | \
$samtoolsbin view -Sbh - >  \${outputDirectory}/${stem}.bam  ;\
$samtoolsbin sort -@ $cores -m 3G \${outputDirectory}/${stem}.bam  \${outputDirectory}/${stem}.coord ;\
$samtoolsbin index \${outputDirectory}/${stem}.coord.bam ; \
mv \${outputDirectory}/${stem}.coord.bam.bai \${outputDirectory}/${stem}.coord.bai\"

if [ \$? != 0 ] ; then
	echo "Failed to execute command"
	exit 1
fi 
spike-control.R -b \${outputDirectory}/${stem}.coord.bam -s $sample_id -o \${outputDirectory}/${stem}.pdf -t \${outputDirectory}/${stem}.tbl
if [ \$? != 0 ] ; then
	echo "Failed to update database"
	exit 1
fi 
ingestDirectory \$outputDirectory
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 

closeJob
"\
> ${stem}.${step}.bsub

bsub < ${stem}.${step}.bsub
#bash $jobName

#rm $$.tmp

