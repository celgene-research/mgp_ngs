inputBAM=$1
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
analysistask=55
output=$(basename $inputBAM| sed 's/.bam//')
step="cufflinksAssembleTranscripts"
stem=$(fileStem $inputBAM)


maskFile=${humanAnnotationDir}/gencode.CURRENT.mask.gtf
NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
strandness=$( ngs-sampleInfo.pl $inputBAM stranded )
if [ $strandness == "NONE" ]; then
	libraryType="fr-unstranded"
fi
if [ $strandness == "REVERSE" ] ; then
	libraryType="fr-secondstrand"
fi

for ref in `ls ${humanChromosomesDir}/*.fa`
do
	chromosome=$( basename $ref | sed 's/.fa//')
	cores=1
	memory=3000
	echo \
"
#BSUB -L /bin/bash
#BSUB -e ${NGS_LOG_DIR}/$step.$stem.$chromosome.bsub.stderr
#BSUB -o ${NGS_LOG_DIR}/$step.$stem.$chromosome.bsub.stdout
#BSUB -J $step.$stem.$chromosome.bsub                # name of the job
#BSUB -n $cores
#BSUB -R \"span[ptile=$cores]\"
#BSUB -M $memory
#BSUB -E \"$scriptDir/../lib/stageReference.sh $step\"
#$Date: 2015-06-01 18:05:20 -0700 (Mon, 01 Jun 2015) $ $Revision: 1528 $
source $scriptDir/../lib/shared.sh

initiateJob $stem $step

	inputBAM=\$( stage.pl --operation out --type file  $inputBAM )
	maskFile=\$(stage.pl --operation out --type file $maskFile )
	
if [ \$inputBAM == "FAILED"  ] ; then
	echo \"Could not transfer \$inputBAM\"
	exit 1
fi


outputDirectory=\$( setOutput \$input $step )
bamfile=${outputDirectory}/bamfiles/${stem}-${chromosome}.bam
	celgeneExec.pl --analysistask $analysistask \"\
$samtoolsbin view -bh \$inputBAM $chromosome > \$bamfile ; \
$cufflinksbin -p $cores \
   --output-dir ${outputDirectory}/$chromosome --mask-file \$maskFile \
   --library-type $libraryType --min-isoform-fraction 0.05  --multi-read-correct  \$bamfile\"
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
	
	" > $step.$stem.$chromosome.bsub 
	
	bsub < $step.$stem.$chromosome.bsub 

done
