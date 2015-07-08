#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh

inputFas=$1 # input file to be used as a reference for annotating the chromosomes


exonerateBin=exonerate


for ref in `ls ${humanChromosomesDir}*.fa`
do
	chromosome=$( basename $ref | sed 's/.fa//')
	cores=1
	memory=8000
	
	echo \
"#BSUB -J $chromosome[1-1000]
#BSUB -L /bin/bash
#BSUB -e $chromosome.%I.exonerate.bsub.stderr
#BSUB -o $chromosome.%I.exonerate.bsub.stdout
#BSUB -R \"rusage[mem=$memory]\"
#BSUB -n $cores
#BSUB -R \"span[ptile=$cores]\"
#BSUB -R \"hname!=USSDGSPNGSAPP01\"
#BSUB -q \"idle\"

output=$chromosome.\$LSB_JOBINDEX.exonerate.gff
celgeneExec.pl  \"$exoneratebin \
  --model est2genome --showtargetgff yes \
  --showvulgar no --showalignment no --querychunkid \$LSB_JOBINDEX \
  --querychunktotal 1000   $inputFas $ref  > \$output\"

cat \$output | filterExonerateOutput.sh | gzip > \$output.gz
	" >$$.$chromosome.exonerate.bsub
	
	#bsub <$$.$chromosome.exonerate.bsub

done

