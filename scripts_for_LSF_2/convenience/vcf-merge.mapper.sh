#!/bin/bash

listOffiles="$@"

mkdir $NGS_LOG_DIR/vcf-merge -p
echo "error files will be in 
# first we create a list of framgent coordinates

rm chunk.$$ -rf
for c in `/celgene/software/NGS-pipeline/misc/fragmentCoordinates.pl 100`; do 
	o=$(echo $c| sed 's/:/-/')
	bsub -o $NGS_LOG_DIR/vcf-merge/$o.stdout -e $NGS_LOG_DIR/vcf-merge/$o.stderr  celgeneExec.pl "vcf-merge -r $c "$@" > $o.vcf"
	echo ${o}.vcf >> chunk.$$
done



