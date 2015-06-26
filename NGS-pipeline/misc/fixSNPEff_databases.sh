#!/bin/bash

# go to the directory where the genome version has been extracted
# and modify some of the files that are there to reflect the differences beteween the public version of the software
# and the version that Celgene uses

snpeffDir=$1

cd ${snpeffDir}

for i in motif.bin nextProt.bin  pwms.bin snpEffectPredictor.bin 
do 
	echo $i;  
	zcat $i | sed 's/MT/M/' | gzip -c > $i.gz
	mv $i $i.bak 
	mv $i.gz $i
done




