#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh

step="Salmon-fastq"
input1=$1
analysistask=38


checkfile $input1

analysistask=50
input2=$( getSecondReadFile $input1)
stem=$(fileStem $input1)
output=$stem


transcriptsIndex=${humansalmonidx}
step=$step.human

initiateJob $stem $step $1


paired_end=$(ngs-sampleInfo.pl $input1 paired_end)

# the library type for salmon (per http://sailfish.readthedocs.org/en/latest/salmon.html)
#first part
#I = inward
#O = outward
#M = matching
# second part
#S = stranded
#U = unstranded
# third part (if second part == S)
#F = read 1 (or single-end read) comes from the forward strand
#R = read 1 (or single-end read) comes from the reverse strand


transcriptsIndex=${ humansalmonidx }

# end humansalmonidxof command arguments
##########################

cores=$(fullcores)
memory=16000
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#BSUB -E \"$scriptDir/../lib/stageReference.sh $step\"
#$Date: 2015-08-14 13:02:55 -0700 (Fri, 14 Aug 2015) $ $Revision: 1624 $


source $scriptDir/../lib/shared.sh 
initiateJob $stem $step $1

input1=\$( stage.pl --operation out --type file  $input1 )
input1unz=\$( echo \$input1 | sed 's/.gz//' )

if [ \"$paired_end\" == \"1\" ]; then
	library="ISR"
	input2=\$( stage.pl --operation out --type file  $input2 )
	input2unz=\$( echo \$input2 | sed 's/.gz//' )
	unzipCmd=\"$pigzbin -d \$input1 ; $pigzbin -d $input2 \"
	readCmd=\"-1 \$input1unz -2 \$input2unz\"
else
	library="IU"
	unzipCmd=\"$pigzbin -d \$input1 \"
	readCmd=\"-r \$input1unz \"
fi



outputDirectory=\$( setOutput \$input1 ${step}-transcriptCountsFastq )

# no_bias_correct is used to avoid core dumps that happen frequently

celgeneExec.pl --analysistask ${analysistask} \"\

$salmonbin quant -i ${transcriptsIndex} \
  --libType '\$library' \
  \$readCmd \
  --output \${outputDirectory}/$stem.$step.salmon \
  --threads $cores --useVBOpt\
  --numBootstraps 100 \"


ingestDirectory \$outputDirectory yes
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 

closeJob

"\
> ${stem}.${step}.$( getStdSuffix ).bsub

bsub < ${stem}.${step}.$( getStdSuffix ).bsub
#bash $jobName

#rm $$.tmp

