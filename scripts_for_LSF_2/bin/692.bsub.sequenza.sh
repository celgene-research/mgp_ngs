#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
inputseqz=$1

echo "This script uses the home brew script run_sequenza.R "
echo "to run sequenza"
echo "Inputs is seq.gz file that is created previously"
echo "in this version only human is assumed"

analysistask=56

stem=$(fileStem $inputseqz)

step="Sequenza"
step=${step}".human"
initiateJob $stem $step $1


cores=$(fullcores) # they are used by the pileup section
memory=$(fullmemory)

# for WES datasets window is set to 50. For WGS it is better to change to 200
window=50 

header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-08-19 10:49:41 -0700 (Wed, 19 Aug 2015) $ $Revision: 1628 $

initiateJob $stem $step $1


inputseqz=\$(stage.pl --operation out --type file  $inputseqz)

outputDirectory=\$( dirname \$inputseqz )



celgeneExec.pl --analysistask=$step \"\
$sequenzabin\
 -s \${inputseqz}\
 -o \${outputDirectory}/${stem}.qcstats\
 -p $stem\
 -c $cores\
 -w $window  \
\"

if [ \$? != 0 ] ; then
	echo "Failed to execute command"
	exit 1
fi 
ingestDirectory \${outputDirectory} yes
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 

closeJob
" > ${stem}.${step}.$( getStdSuffix ).bsub

bsub < ${stem}.${step}.$( getStdSuffix ).bsub

