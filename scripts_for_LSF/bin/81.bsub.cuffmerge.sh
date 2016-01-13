#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
cufflinksDir=$1
cufflinksDir=$( readlink -f $cufflinksDir )
analysistask=57


step="cuffmerge"
NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
# NOTE: Each process has to run inside a separate directory. 
# Cuffmerge is storing a file tmp_meta_asm in the working directory which makes it impossible to parallelize
wd=$PWD
listDir=$wd/lists  # store the files with the list of transcript.gtf
referenceDir=$wd/referenceGTF # store the GTF files that will be created in the staging phase
humanGenomeAnnotation=${humanGenomeDir}/Annotation/gencode.CURRENT.annotation.gtf
mkdir -p $listDir
mkdir -p $referenceDir


for ref in `ls ${humanGenomeDir}/Chromosomes/*.fa`
do
chromosome=$( basename $ref | sed 's/.fa//')
memory=3000	
cores=$(fullcores)

baseDir=$wd/$chromosome.cuffmerge
mkdir -p $baseDir

inputList=$listDir/$chromosome.list
find $cufflinksDir | grep ${chromosome} | grep transcripts.gtf > $inputList

referencegtf=$referenceDir/${chromosome}.gtf

cd $baseDir
memory=16000
cores=2
header=$(bsubHeader $stem $step $memory $cores)
echo "Submitting job for chromosome $chromosome"

echo \
"$header

#BSUB -E \"$scriptDir/../lib/stageReference.sh $step\"
#$Date: 2015-06-01 18:05:20 -0700 (Mon, 01 Jun 2015) $ $Revision: 1528 $

source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step $1


celgeneExec.pl --analysistask ${analysistask} \"\
$filterBin $humanGenomeAnnotation $referencegtf $chromosome\"

celgeneExec.pl --derivedfromlist $inputList --analysistask ${analysistask} \"\
$cuffmergebin -o results.cuffmerge --ref-gtf $referencegtf --num-threads $cores --ref-sequence ${humanChromosomesDir} $inputList\"
		
" > $$.$chromosome.cuffmerge.bsub
		
bsub < $$.$chromosome.cuffmerge.bsub
cd ..
done
