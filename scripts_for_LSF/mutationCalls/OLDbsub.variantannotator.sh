#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh

inputVCF=$1
analysistask=59
#snpeffGenomeVersion=GRCh37.64
output=$(basename $inputVCF| sed 's/.gz//' | sed 's/.vcf//' | sed 's/.bcf//')
output=${output}_vannot.vcf

snpsiftBin="java -Xmx8g -jar ${NGS_APPLICATION_DIR}/snpEff/LATEST/SnpSift.jar "

gatkdbSNP=$GATK_HOME/reference/dbsnp_137.celgene.vcf
gatkCOSMICCoding=/opt/Medussa2/usr/data/Genomes/Homo-sapiens/GRCh37.p12/Variants/CodingMuts_v68.vcf
gatkCOSMICNonCoding=/opt/Medussa2/usr/data/Genomes/Homo-sapiens/GRCh37.p12/Variants/NonCodingVariants_v68.vcf
snpsiftdbNSFP=/opt/Medussa2/Applications/snpEff/LATEST/dbNSFP/dbNSFP2.3.txt.gz
snpsiftPhastCons=/opt/Medussa2/Applications/snpEff/LATEST/phastCons/
memory=8000
cores=4
echo \
"
#BSUB -L /bin/bash
#BSUB -e $output.bsub.stderr
#BSUB -o $output.bsub.stdout
#BSUB -J $$.$output.snpeff.bsub                # name of the job
#BSUB -n $cores
#BSUB -R \"span[ptile=$cores]\"
#BSUB -R \"hname!=USSDGSPNGSAPP01\"
#BSUB -R \"rusage[mem=$memory]\"
#BSUB -M $memory
#BSUB -q \"normal\"


celgeneExec.pl --analysistask $analysistask \"$snpsiftBin annotate -id $gatkdbSNP $inputVCF | $snpsiftBin annotate -id $gatkCOSMICCoding - | $snpsiftBin annotate -id $gatkCOSMICNonCoding - | $snpsiftBin dbnsfp -v $snpsiftdbNSFP  -f SIFT_score,Polyphen2_HDIV_score,Polyphen2_HVAR_score,SIFT_pred,Polyphen2_HVAR_pred,Polyphen2_HDIV_pred,GERP++_NR,GERP++_RS,29way_logOdds,1000Gp1_AF,1000Gp1_AFR_AF,1000Gp1_EUR_AF,1000Gp1_AMR_AF,1000Gp1_ASN_AF,MutationTaster_score,MutationTaster_pred - | $snpsiftBin phastCons $snpsiftPhastCons - > ${output}\"

" > $$.$output.snpsift.bsub

bsub < $$.$output.snpsift.bsub

