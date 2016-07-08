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
stranded=$(ngs-sampleInfo.pl $input1 stranded)
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


transcriptsIndex=${humansalmonidx}

# end humansalmonidxof command arguments
##########################

cores=$(fullcores)
memory=16000
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

set +e # specifically used for salmon which dumps a core after it finishes
ulimit -c 0

input1=\$( stage.pl --operation out --type file  $input1 )
#input1unz=\$( echo \$input1 | sed 's/.gz//' )
library=\"\"
if [ \"$paired_end\" == \"1\" ]; then
	library=\"I\"
	input2=\$( stage.pl --operation out --type file  $input2 )
	#input2unz=\$( echo \$input2 | sed 's/.gz//' )
	#unzipCmd=\"$pigzbin -d \$input1 ; $pigzbin -d \$input2 \"
	readCmd=\"-1 <(gunzip -c \$input1) -2 <(gunzip -c \$input2)\"
else
	library=\"I\"
	unzipCmd=\"$pigzbin -d \$input1 \"
	readCmd=\"-r <(gunzip -c \$input1) \"
fi
if [ \"$stranded\" == \"REVERSE\" ]; then
	library=\$library\"SR\"
fi
if [ \"$stranded\" == \"NONE\" ]; then
	library=\$library\"U\"
fi
if [ \"$stranded\" == \"FORWARD\" ]; then
	library=\$library\"SF\"
fi

outputDirectory=\$( setOutput \$input1 ${step}-transcriptCountsFastq )

# no_bias_correct is used to avoid core dumps that happen frequently
#\$unzipCmd ; \


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

