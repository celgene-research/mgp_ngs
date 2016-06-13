#!/bin/bash
inputVCF=$1
filterFile=$2
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
analysistask=59
step="VariantFilter"
stem=$(fileStem $inputVCF)

if [ ! -e $filterFile -a "$filterFile" != "tranche" ] ;then
	echo "Cannot find filter file $filterFile "
	exit 
fi

memory=4000
cores=1

initiateJob $stem $step $1

header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-10-01 15:43:49 -0700 (Thu, 01 Oct 2015) $ $Revision: 1676 $
source $scriptDir/../lib/shared.sh 
set -e
initiateJob $stem $step $1

inputVCF=\$( stage.pl --operation out --type file  $inputVCF )

if [ \$inputVCF == \"FAILED\" ]; then
	echo \"Could not transfer \$inputVCF\"
	exit 1
fi
outputDirectory=\$( setOutput \$inputVCF ${step} )


"> ${stem}.${step}.${suffix}.bsub

if [ $filterFile == "tranche" ] ;then
echo \
"
trancheThresh=\$( $scriptDirectory/tranche.sh $inputVCF)
celgeneExec.pl --analysistask $analysistask \"\
zcat \${inputVCF} | \
java -Xmx${memory}m -jar $snpsiftbin filter \\\"(VQSLOD> \$trancheThresh)\\\"  \
> \${outputDirectory}/${stem}.${step}.vcf ; \
bgzip \${outputDirectory}/${stem}.${step}.vcf  ; \
tabix -p vcf \${outputDirectory}/${stem}.${step}.vcf.gz \
\"
	
">> ${stem}.${step}.${suffix}.bsub
else
echo \
" 
celgeneExec.pl --analysistask $analysistask \"\
zcat \${inputVCF} | \
java -Xmx${memory}m -jar $snpsiftbin filter -e $filterFile \
> \${outputDirectory}/${stem}.${step}.vcf ; \
bgzip \${outputDirectory}/${stem}.${step}.vcf  ; \
tabix -p vcf \${outputDirectory}/${stem}.${step}.vcf.gz \
\"

" >> ${stem}.${step}.${suffix}.bsub
fi

echo \
"
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

" >> ${stem}.${step}.${suffix}.bsub
bsub < ${stem}.${step}.${suffix}.bsub
