#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1
analysistask=97
step="XenograftDecontamination"
stem=$(fileStem $input)
checkfile $input



export NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
cores=4
#necessary adjustment due to limitations in storage space on AWS instances

memory=20000
header=$(bsubHeader $stem $step $memory $cores)


mkdir -p $NGS_LOG_DIR

echo \
"$header

#$Date: 2015-08-14 13:02:55 -0700 (Fri, 14 Aug 2015) $ $Revision: 1624 $
source $scriptDir/../lib/shared.sh

initiateJob $stem $step $1

set -e


input=\$( stage.pl --operation out --type file  $input )
if [ \$input == "FAILED"  ] ; then
	echo \"Could not transfer \$input\"
	exit 1
fi

newDir=\$( lastDir \$input | sed 's%bamfiles%bamQC%')
outputDirectory=\$( setOutput \$input \$newDir/${step} )
newDir=\$( lastDir \$input | sed 's%bamfiles.*%XFbamfiles%')
outputDirectoryBam=\$( setOutput \$input \$newDir )

celgeneExec.pl --analysistask ${analysistask} \"\
$samtoolsbin view -h \$input | \
$xenograft -i - -o - --no_host --no_both --stats \${outputDirectory}/$stem.$step.qcstats | \
$samtoolsbin view -bhS - > \${outputDirectoryBam}/${stem}.bam ; \
$samtoolsbin sort -@ $cores -m 3800M  \${outputDirectoryBam}/${stem}.bam  \${outputDirectoryBam}/${stem}.coord ; \
$samtoolsbin index \${outputDirectoryBam}/${stem}.coord.bam ; mv \${outputDirectoryBam}/${stem}.coord.bam.bai \${outputDirectoryBam}/${stem}.coord.bai ; \
$samtoolsbin sort -@ $cores -n -m 3800M  \${outputDirectoryBam}/${stem}.bam  \${outputDirectoryBam}/${stem}.name \"
 if [ \$? != 0 ] ; then
	echo "Failed to run command"
	exit 1
fi 

runQC-bam.pl --logfile \$MASTER_LOGFILE \
--inputbam $input \
--outputfile \${outputDirectory}/$stem.${step}.qcstats \
--reuse --qcStep Xenograft
if [ \$? != 0 ] ; then
	echo "Failed to update database"
	exit 1
fi 


ingestDirectory  \$outputDirectory
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 
ingestDirectory  \$outputDirectoryBam
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 

closeJob 
" > ${stem}.${step}.${suffix}.bsub

bsub < ${stem}.${step}.${suffix}.bsub
#rm $$.tmp

