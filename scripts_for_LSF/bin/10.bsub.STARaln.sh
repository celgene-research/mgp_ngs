#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh

######################
# if library is unstranded allow the following command
# as argument for STAR, which is needed for processing with cufflinks
#
# --outSAMstrandField intronMotif
#
# no argument is needed for stranded
# it is also recommended to remove non cancnical splice junctions for cufflinks
#
#--outFilterIntronMotifs RemoveNoncanonicalUnannotated
#
######################

# if we want the output to be for other purposes except for cufflinks we can use the arguments
# --outSAMmode Full --outSAMattributes All
#############################################

# the way STAR runs produces chimeric.out.junction file which can be furhter processed with
# the bioconductor chimera package to predict fusion genes.
# the command arguments responsible follow:
# --chimSegmentMin 15 --chimJunctionOverhangMin 15
#############################################

# Kostas Mar 8 2015
# added parameters for fusion detection; STAR results can be analyzed which ChimeraScan
# according to SBG the following parameters are suggested for optimal fusion detection
# chimSegmentMin 20
# chimScoreDropMax 20
# chimScoreSeparation 10
# chimScorJunctionNonGTAG -1 
# sjdbOverhang 100
# seedSearchStartLmax 30 (25 for reads >100)
# The following parameters should be adjusted when analyzing single-end data: 
# - outFilterScoreMinOverLread 0 - 
# outFilterMatchNminOverLread 0 - 
# outFilterMatchNmin 50 (to allow output of short alignments)

step="STARaln"
input1=$1


checkfile $input1

analysistask=50
input2=$( getSecondReadFile $input1)
stem=$(fileStem $input1)



##########################
# set up of LSF related parameters




########################
# set command arguments 
# switch that decides if the output will be cufflinks compatible or not, Switch to 0 for non-cufflinks output, 1 for cufflinks output
cufflinks=0

additionalCommand=" --outSAMmode Full --outSAMattributes All "
if [ $cufflinks == '1' ]; then
	additionalCommand=" "
fi 

# setup the strand arguments
paired=$(ngs-sampleInfo.pl  $input1 paired_end )
strandness=$( ngs-sampleInfo.pl $input1 stranded )
strandoption=" "
if [ $strandness == "NONE" ]; then
	strandoption=" --outSAMstrandField intronMotif "
fi

#setup the reference database argument depending if the sample is a xenograft
refdatabase=$( ngs-sampleInfo.pl $input1 xenograft )
hostgenome=$(ngs-sampleInfo.pl $input1 host_genome)
refgenome=$(ngs-sampleInfo.pl $input1 reference_genome)

memory=55000
if [ $refdatabase == '1' ] ; then
	echo "$input1 is a xenograft sample of $refgenome tissue on $hostgenome" 
	if [ "$hostgenome" == "Mus_musculus" -a "$refgenome" == "Homo_sapiens" ] ; then
		database=${human_mouseSTARidx}
	# until the cluster nodes have enough memory we cannot allow to run this operation on a single cluster node
	# Feb 4 2014. Cluster nodes now have enough memory
		memory=60000
		analysistask=51
		step=${step}.xenograft
	else
		echo "Cannot find database for host genome $hostgenome"
		exit
	fi
	#exit
else
	
	if [ $refgenome == 'Homo_sapiens' ] ; then
		database=${humanSTARidx}
		step=${step}.human
		memory=34000
	fi

	if [ $refgenome == 'Rattus_norvegicus' ] ;then
		database=${ratSTARidx}
		step=${step}.rat
	fi
fi





## do some sanity check
if [ -z "$refgenome" -o "$refgenome" == "" ]; then
	echo "Cannot find the reference genome [$refgenome] associated with $input1"
	exit 1
fi

export NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
mkdir -p $NGS_LOG_DIR
cores=$(fullcores)

header=$(bsubHeader $stem $step $memory $cores)

# end of command arguments
##########################




echo \
"$header

#BSUB -E \"$scriptDir/../lib/stageReference.sh $step\"
#$Date: 2015-08-14 13:02:55 -0700 (Fri, 14 Aug 2015) $ $Revision: 1624 $
source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step

database=$database
input1=\$( stage.pl --operation out --type file  $input1 )

if [ "$paired" == "1" ] ; then 
	input2=\$( stage.pl --operation out --type file  $input2 )
	inputcmd=\"--readFilesIn \$input1 \$input2\"
else
	inputcmd=\"--readFilesIn \$input1\"
fi
	

if [ \$database == "FAILED" -o \$input1 == "FAILED" -o \$input2 == "FAILED" ] ; then
	echo "Could not transfer either \$reference or \$input1 or \$input2"
	exit 1
fi

outputDirectory=\$( setOutput \$input1 ${step}-bamfiles )


celgeneExec.pl --analysistask ${analysistask} \"\
$starbin \
 --genomeDir \$database $additionalCommand \$inputcmd \
 --readFilesCommand zcat \
 --runThreadN $cores \
 --genomeLoad NoSharedMemory \
 --outStd SAM \
 --outSAMunmapped Within \
 --outFileNamePrefix \${outputDirectory}/${stem} \
 --outSAMattrRGline ID:$stem PL:illumina   PU:$stem   SM:$stem \
 --clip3pAdapterSeq AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGTAGATCTCGGTGGTCGCCGTATCATT  \
 --clip3pAdapterMMp 0.1 $strandoption \
 --chimSegmentMin 15 \
 --chimJunctionOverhangMin 15 \
 --chimScoreMin 0 \
 --chimScoreDropMax 20 \
 --chimScoreSeparation 10 \
 --chimScoreJunctionNonGTAG -1 \
 --quantMode TranscriptomeSAM --quantTranscriptomeBan Singleend \
 --outTmpDir \${outputDirectory}/TMP/ |\
$samtoolsbin view -bSh - > \${outputDirectory}/${stem}Aligned.out.bam ; \
$samtoolsbin sort -@ $cores -m 1G \${outputDirectory}/${stem}Aligned.out.bam  \${outputDirectory}/${stem}.coord ; \
$samtoolsbin index  \${outputDirectory}/${stem}.coord.bam ; mv \${outputDirectory}/${stem}.coord.bam.bai \${outputDirectory}/${stem}.coord.bai ; \
$samtoolsbin sort -n -@ $cores -m 1G \${outputDirectory}/${stem}Aligned.out.bam  \${outputDirectory}/${stem}.name \"

if [ \$? != 0 ] ; then
	echo "Failed to run command"
	closeJob
	exit 1
fi 

ingestDirectory \$outputDirectory
if [ \$? != 0 ] ; then
	echo "Failed to ingest data"
	exit 1
fi 
rm -rf \$outputDirectory

closeJob

"\
> ${stem}.${step}.bsub

bsub < ${stem}.${step}.bsub
#bash $jobName

#rm $$.tmp

