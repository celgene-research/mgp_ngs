#!/bin/bash

# this script is using BWA mem to do alignment of reads on the human genome
#
# it can be used to either map paired reads or single reads.
# BWA-mem is an algorithm that performs well for reads > 70bp
# for shorter reads a script using bwa aln, or bowtie2 would be preferable



scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input1=$1
checkfile $input1

input2=$( getSecondReadFile $input1)
stem=$(fileStem $input1)
step="BWAmem"

analysistask=38
paired_end=$(ngs-sampleInfo.pl $input1 paired_end)
 
refdatabase=$( ngs-sampleInfo.pl $input1 xenograft )
hostgenome=$(ngs-sampleInfo.pl $input1 host_genome)
refgenome=$(ngs-sampleInfo.pl $input1 reference_genome)

if [ $refdatabase == '1' ] ; then
	echo "$input1 is a xenograft sample of $refgenome tissue on $hostgenome" 
	if [ "$hostgenome" == "Mus_musculus" -a "$refgenome" == "Homo_sapiens" ] ; then
		genomeDatabase=${human_mouseBWAidx}
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
		genomeDatabase=${humanBWAidx}
		step=${step}.human
		memory=46000
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

 

echo \
"$header

#$Date: 2015-06-01 18:02:35 -0700 (Mon, 01 Jun 2015) $ $Revision: 1524 $

source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step



input1=\$( stage.pl --operation out --type file  $input1 )
if [ \"$paired_end\" == \"1\" ];then
	input2=\$( stage.pl --operation out --type file  $input2 )
fi

# we no longer need this since the script will be dependent on a step that stages the human genome
#genomeDatabase=\$(stage.pl --operation out --type directory $database directory out )

####################

genomeDatabase=$genomeDatabase


####################
if [ \$input1 == \"FAILED\" -o \$input2 == \"FAILED\" -o \$genomeDatabase == \"FAILED\" ] ; then
	echo \"Could not transfer \$input1\"
	exit 1
fi

outputDirectory=\$( setOutput \$input1 ${step}-bamfiles )

"> ${stem}.${step}.bsub




echo -n "\
celgeneExec.pl --analysistask ${analysistask} \"\
$bwabin mem \
  -t $cores \
  -R '@RG\tID:$stem\tSM:$stem\tPL:ILLUMINA\tLB:$stem\tPU:$stem' \
  -M \$genomeDatabase/genome.fa  " >> ${stem}.${step}.bsub
if [ "$paired_end" == "1" ]; then
echo -n " \$input1 \$input2 " >>  ${stem}.${step}.bsub
else
echo -n " \$input1 " >>  ${stem}.${step}.bsub
fi


if [ "$refdatabase" == "1" ] ;then
echo -n " -a | $filterBamAlnQuality --input - --output - --stats \${outputDirectory}/${stem}.qcstats " >> ${stem}.${step}.bsub
fi
echo -n " | $samtoolsbin view -Sbh -F 4 - > \${outputDirectory}/${stem}.bam ; \
$samtoolsbin sort -@ $cores -m 1G \${outputDirectory}/${stem}.bam  \${outputDirectory}/${stem}.coord ; \
$samtoolsbin index  \${outputDirectory}/${stem}.coord.bam ; mv \${outputDirectory}/${stem}.coord.bam.bai \${outputDirectory}/${stem}.coord.bai ; \
$samtoolsbin sort -n -@ $cores -m 1G \${outputDirectory}/${stem}.bam  \${outputDirectory}/${stem}.name ; \
rm \${outputDirectory}/${stem}.bam \"\
">> ${stem}.${step}.bsub



echo "\

ingestDirectory \$outputDirectory
if [ \$? -ne 0 ] ; then
	echo \"Failed to ingest data\"
	exit 1
fi 


closeJob
">> ${stem}.${step}.bsub

bsub < ${stem}.${step}.bsub
