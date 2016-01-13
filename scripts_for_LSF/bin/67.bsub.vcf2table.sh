#!/bin/bash

# This script uses the SNPSift extractfields command to extract certain fields from a vcf file.
# if you need to extract a different set of information please refer to snpsift documentation and replace the 
# corresponding section in this script (line 42)
inputVCF=$1
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
analysistask=59
step="ExtractFields"
stem=$(fileStem $inputVCF)


memory=4000
cores=1
NGS_LOG_DIR=${NGS_LOG_DIR}/${step}


mkdir -p $NGS_LOG_DIR
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


celgeneExec.pl --analysistask $analysistask \"\
echo -n 'CHROM	POS	ID	REF	ALT	GENE	HGVS_P	IMPACT	dbNSFP_SIFT_pred	dbNSFP_Polyphen2_HDIV_pred	dbNSFP_MutationTaster_pred	CLNSIG	BIOTYPE	NMD	LOF	' > \${outputDirectory}/${stem}.${step}.tbl ; \
zgrep '^#CHROM' \$inputVCF | cut -f 10-99999 >> \${outputDirectory}/${stem}.${step}.tbl ; \
zcat \$inputVCF | \
$SNPEFF_BASE/scripts/vcfEffOnePerLine.pl   | \
java -jar $snpsiftbin extractFields -e '.' - \
CHROM POS ID REF ALT 'ANN[*].GENE' 'ANN[*].HGVS_P' 'ANN[*].IMPACT' dbNSFP_SIFT_pred dbNSFP_Polyphen2_HDIV_pred dbNSFP_MutationTaster_pred  CLNSIG 'ANN[*].BIOTYPE' 'NMD[*].PERC' 'LOF[*].PERC' 'GEN[*].GT' \
>> \${outputDirectory}/${stem}.${step}.tbl 
\"


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

" >$stem.$step.bsub
bsub < $stem.$step.bsub
