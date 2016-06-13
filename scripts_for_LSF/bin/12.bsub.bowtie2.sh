#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh

# script that runs bowtie2 to align reads to the human genome
# it is suggested to use this script for reads < 75 bp
# it uses the local alignment mode (for sensitivity)
#    searchs for 10 alignment (-k 10) 
#    and filters the output to keep only the best alignments (using the AS field)
# at the end the produced bam files are sorted by coord and name

step="Bowtie2"
input1=$1

analysistask=38


checkfile $input1
paired_end=$(ngs-sampleInfo.pl $input1 paired_end)
if [ "$paired_end" == "1" ] ; then
	input2=$( getSecondReadFile $input1)
	checkfile $input2
fi

stem=$(fileStem $input1)


 
refdatabase=$( ngs-sampleInfo.pl $input1 xenograft )
hostgenome=$(ngs-sampleInfo.pl $input1 host_genome)
refgenome=$(ngs-sampleInfo.pl $input1 reference_genome)

if [ $refdatabase == '1' ] ; then
	echo "$input1 is a xenograft sample of $refgenome tissue on $hostgenome" 
	if [ "$hostgenome" == "Mus_musculus" -a "$refgenome" == "Homo_sapiens" ] ; then
		genomeDatabase=${human_mouseBowtie2idx}/genome
		memory=60000
		step=${step}.xenograft
	else
		echo "Cannot find database for host genome $hostgenome"
		exit
	fi
	#exit
else
	
	if [ $refgenome == 'Homo_sapiens' ] ; then
		genomeDatabase=${humanBowtie2idx}/genome
		step=${step}.human
		memory=46000
	fi
	

fi

## do some sanity check
if [ -z "$refgenome" -o "$refgenome" == "" ]; then
	echo "Cannot find the reference genome [$refgenome] associated with $input1"
	exit 1
fi


initiateJob $stem $step $1

# end of command arguments
##########################
sample_id=$(ngs-sampleInfo.pl $input1 sample_id )
if [ $sample_id == "NA" ]; then
	sample_id=0
fi
memory=$(fullmemory)
cores=$(fullcores)


header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header


#$Date: 2015-06-04 13:44:36 -0700 (Thu, 04 Jun 2015) $ $Revision: 1585 $
source $scriptDir/../lib/shared.sh
initiateJob $stem $step $1

database=$genomeDatabase
input1=\$( stage.pl --operation out --type file  $input1 )
if [ \"$paired_end\" == \"1\" ] ; then
	input2=\$( stage.pl --operation out --type file  $input2 )
	commandarguments=\" -1 \$input1  -2 \$input2 \"
else 
	
	commandarguments=\" -U \$input1 \"
fi

if [ \"\$genomeDatabase\" == \"FAILED\" -o \"\$input1\" == \"FAILED\" -o \"\$input2\" == \"FAILED\" ] ; then
	echo "Could not transfer either \$database or \$input1 or \$input2"
	exit 1
fi

outputDirectory=\$( setOutput \$input1 ${step}-bamfiles )

# not that samtools is using the -q 30 filter to keep only good alignments ( MAPQ >30)
celgeneExec.pl --analysistask ${analysistask} \"\
$bowtie2bin --quiet -k20 --sensitive-local -p $cores  -x \$database \$commandarguments  | \
$filterBamAlnQuality --input - --output - --stats \${outputDirectory}/${stem}.qcstats | \
$samtoolsbin view -Sbh - >  \${outputDirectory}/${stem}.bam  ; \
$samtoolsbin sort -@ $cores -m 3G \${outputDirectory}/${stem}.bam  \${outputDirectory}/${stem}.coord ; \
$samtoolsbin index \${outputDirectory}/${stem}.coord.bam ; \
mv \${outputDirectory}/${stem}.coord.bam.bai \${outputDirectory}/${stem}.coord.bai\"

if [ \$? -ne 0 ] ; then
	echo \"Failed to execute command\"
	exit 1
fi 

ingestDirectory \$outputDirectory
if [ \$? -ne 0 ] ; then
	echo \"Failed to ingest data\"
	exit 1
fi 

closeJob
"\
> ${stem}.${step}.${suffix}.bsub

bsub < ${stem}.${step}.${suffix}.bsub
#bash $jobName

#rm $$.tmp

