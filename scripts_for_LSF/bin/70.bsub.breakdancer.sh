#!/bin/bash

### COMMANDS THAT WORKED
celgeneExec.pl "/ngs/tools/breakdancer/breakdancer-1.1.2/perl/bam2cfg.pl -q 1 G144-p16.nodup.name.BWAmem.human.coord.Realign.Recalibrate.bam  G179-p16.nodup.name.BWAmem.human.coord.Realign.Recalibrate.bam G166-p18.nodup.name.BWAmem.human.coord.Realign.Recalibrate.bam  NHNP-p2.nodup.name.BWAmem.human.coord.Realign.Recalibrate.bam > br.cfg "
celgeneExec.pl "/ngs/tools/breakdancer/breakdancer-1.1.2/cpp/breakdancer-max  -d br.ctx br.cfg > br.ctx"

exit
### IGNORE REST OF SCRIPT


scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1
analysistask=95
binarycfg=${NGS_BINARIES_DIR}/bam2cfg.pl
binarybrk=${NGS_BINARIES_DIR}/breakdancer-max


NGS_TMP_DIR_ORIGINAL=${NGS_TMP_DIR}
NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
step="IndelBrkd"
stem=$(fileStem $input).${step}

memory=8000
cores=1


mkdir -p $NGS_LOG_DIR

echo \
"
#BSUB -L /bin/bash
#BSUB -e $NGS_LOG_DIR/$stem.bsub.stderr
#BSUB -o $NGS_LOG_DIR/$stem.bsub.stdout
#BSUB -J $stem.bsub                # name of the job
#BSUB -n $cores
#BSUB -R \"span[ptile=$cores]\"
#BSUB -R \"hname!=USSDGSPNGSAPP01\"
#BSUB -M $memory
#BSUB -q \"normal\"

# stage the input files in a stable location. This way other instances of the scripts will not have to recopy these files in the same place
export NGS_TMP_DIR=${NGS_TMP_DIR_ORIGINAL}
input=\$( stage.pl --operation out --type file  $input )



export NGS_TMP_DIR=${NGS_TMP_DIR_ORIGINAL}/${step}/$$
outputDirectory=\$(dirname \$input| sed 's%${NGS_TMP_DIR_ORIGINAL}%'\${NGS_TMP_DIR}'%' | sed 's%bamfiles%indelbrkd%'| sed 's%SRC%Processed%' | sed 's%GATK%CNV%' )

mkdir -p \$outputDirectory
export CELGENE_EXEC_LOGFILE=${NGS_LOG_DIR}/${stem}.celgeneExec.log
if [ -e \$CELGENE_EXEC_LOGFILE ] ; then
	rm \$CELGENE_EXEC_LOGFILE
fi
dir

celgeneExec.pl --analysistask ${analysistask} \"$binarycfg -q -1 -g -h -v 2 \${input} > \${outputDirectory}/${stem}.cfg ; $binarybrk -q 10 -d $stem.ctx \${outputDirectory}/${stem}.cfg > \${outputDirectory}/$stem.ctx \" 

ingestDirectory \${outputDirectory} yes
if [ \$? != 0 ] ; then
	echo \"Failed to ingest data\"
	exit 1
fi 
rm -rf \${outputDirectory} 

" > ${stem}.bsub

bsub < ${stem}.bsub
#rm $$.tmp

