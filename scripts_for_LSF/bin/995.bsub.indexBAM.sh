#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1



cores=1
#necessary adjustment due to limitations in storage space on AWS instances
step="IndexBAM"
memory=10000
stem=$(fileStem $input)
initiateJob $stem $step $1
mkdir -p $NGS_LOG_DIR

header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-08-14 13:02:55 -0700 (Fri, 14 Aug 2015) $ $Revision: 1624 $
source $scriptDir/../lib/shared.sh


set -e

input=\$( stage.pl --operation out --type file  $input )
inputidx=\$( echo \$input | sed 's/bam/bai/ )
if [ \$input == "FAILED"  ] ; then
	echo \"Could not transfer \$input\"
	exit 1
fi
# we want the bai file to be in the same directory as the bam file
outputDirectory=\$( basename \$input )


celgeneExec.pl --analysistask ${analysistask} \"\
$samtoolsbin index -b \$input \$inputidx ;\
rm \$input\"
 if [ \$? != 0 ] ; then
	echo "Failed to run command"
	exit 1
fi 

inputidx2=\$(stage.pl --operation in --type file \$inputidx)
closeJob

" > ${stem}.${step}.bsub

bsub < ${stem}.${step}.bsub
#rm $$.tmp

