#!/bin/bash
# simple script that indexes a vcf file. It runs bgzip and tabix on an uncompressed vcf file
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh
input=$1


analysistask=52
step="CompressTabix"


export NGS_LOG_DIR=${NGS_LOG_DIR}/${step}
cores=1
#necessary adjustment due to limitations in storage space on AWS instances

memory=10000
stem=$(fileStem $input)

mkdir -p $NGS_LOG_DIR

header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#$Date: 2015-09-15 17:31:31 -0700 (Tue, 15 Sep 2015) $ $Revision: 1644 $
source $scriptDir/../lib/shared.sh

initiateJob $stem $step $1

input=\$( stage.pl --operation out --type file  $input )
if [ \$input == "FAILED"  ] ; then
        echo \"Could not transfer \$input\"
        exit 1
fi

outputDirectory=\$( setOutput \$input VCF-indexed )


celgeneExec.pl --analysistask ${analysistask} \"\
zcat \$input |  bgzip -c \$input > \${outputDirectory}/\${stem}.vcf.gz ; \
tabix -p vcf \${outputDirectory}/\${stem}.vcf.gz \"


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

" > ${stem}.${step}.$( getStdSuffix ).bsub

bsub < ${stem}.${step}.$( getStdSuffix ).bsub
#rm $$.tmp

