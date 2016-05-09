#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh

step="Vannot"
inputVCF=$1
analysistask=46
#checkfile $inputVCF
#snpeffGenomeVersion=GRCh37.64
snpeffGenomeVersion=$snpeffgenomeversion
stem=$(fileStem $inputVCF)


snpeffBin=$snpeffbin
snpeffConfig=${snpeffconfig}
snpsiftBin=$snpsiftbin

dbSNP=${dbsnp}
COSMICCoding=${cosmiccoding}
COSMICNonCoding=${cosmicnoncoding}
clinvar=${clinvar}
uk10k=${uk10k}
exac=${exac}
gwasCatalog=${gwascatalog}
snpsiftdbNSFP=${humanVariantsDir}/dbNSFP2.8_variants.gz
snpsiftPhastCons=${SNPEFF_BASE}/../phastCons/
msigdb=$msigdb

initiateJob $stem $step $1
memory=30000
cores=2
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

#BSUB -E \"$scriptDir/../lib/stageReference.sh $step\"
#$Date: 2015-09-03 12:48:50 -0700 (Thu, 03 Sep 2015) $ $Revision: 1643 $
source $scriptDir/../lib/shared.sh

initiateJob $stem $step $1
set -e
inputVCF=\$( stage.pl --operation out --type file  $inputVCF)
COSMICCoding=$COSMICCoding
COSMICNonCoding=$COSMICNonCoding 
dbSNP=$dbSNP 
clinvar=$clinvar 
uk10k=$uk10k 
exac=$exac 
gwasCatalog=$gwasCatalog 
snpsiftdbNSFP=$snpsiftdbNSFP
snpsiftdbNSFP_idx=${snpsiftdbNSFP}.tbi
if [  \$inputVCF == "FAILED" ] ; then
	echo "Could not transfer either \$inputVCF"
	exit 1
fi


outputDirectory=\$( setOutput \$inputVCF $step )

# this script annotates a vcf file with 
# 1. SNPEFF annotation with severity of mutation
# 2. SNPEFF lof value
# 3. SNPEFF motif
# 4. next prot (domains of proteins) 
# 5. dbSNP id (from VCF file)
# 6. COSMIC id from Coding and non coding mutations (from VCF file)
# 7. clinvar clinical significance (from VCF file )       #### TODO
# 8. predicted effect of mutations from SIFT_score,Polyphen2_HDIV_score,Polyphen2_HVAR_score,SIFT_pred,Polyphen2_HVAR_pred,Polyphen2_HDIV_pred,GERP++_NR,GERP++_RS,29way_logOdds,MutationTaster_score,MutationTaster_pred
# 9. mutation frequences from 1000G project
# 10. mutations frequencis from ARIC project
# 11. mutations frequences from ESP6500 project
# 12. mutation frequences from the ExAC project from its vcf file  ############### TODO
# 13. mutation fequencies from the UK10K project from its vcf file ############### TODO
# 14. phastcons information

celgeneExec.pl --analysistask $analysistask \"\
java -Xmx8g -jar $snpsiftBin RmInfo \$inputVCF EFF ANN SNP HET HOM VARTYPE AN_AFR AN_AMR AN_EAS AN_FIN AN_NFE AN_OTH AN_SAS \
 Het_AFR Het_AMR Het_EAS Het_FIN Het_NFE Het_OTH Het_SAS Hom_AFR Hom_AMR Hom_EAS Hom_FIN Hom_NFE Hom_OTH Hom_SAS \
 AF_TWINSUK,AF_ALSPAC CLNSIG dbNSFP_1000Gp1_AF dbNSFP_1000Gp1_AFR_AF dbNSFP_1000Gp1_EUR_AF dbNSFP_1000Gp1_AMR_AF dbNSFP_1000Gp1_ASN_AF \
 dbNSFP_ESP6500_AA_AF dbNSFP_ESP6500_EA_AF \
 dbNSFP_GERP++_RS dbNSFP_SiPhy_29way_logOdds dbNSFP_MutationTaster_pred dbNSFP_Polyphen2_HDIV_score dbNSFP_ARIC5606_AA_AF \
 dbNSFP_SIFT_pred dbNSFP_Polyphen2_HVAR_score dbNSFP_MutationTaster_score dbNSFP_phastCons100way_vertebrate \
 dbNSFP_ARIC5606_EA_AF dbNSFP_Polyphen2_HDIV_pred dbNSFP_GERP++_NR dbNSFP_Polyphen2_HVAR_pred dbNSFP_SIFT_score MSigDb > \
\${outputDirectory}/0.tmp.vcf ; \
java -Xmx8g -jar $snpeffBin eff -c $snpeffConfig \
  -stats \${outputDirectory}/$stem.$step.stats.html \
  -v -nextProt \
  -dataDir $SNPEFF_BASE/data \
  -motif -lof $snpeffGenomeVersion \${outputDirectory}/0.tmp.vcf  >\
\$outputDirectory/1.tmp.vcf ; \
rm \${outputDirectory}/0.tmp.vcf ; \
java -Xmx3g -jar $snpsiftBin annotate -id \$dbSNP  \$outputDirectory/1.tmp.vcf > \$outputDirectory/1.tmp.dbsnp.vcf  ; \
java -Xmx3g -jar $snpsiftBin annotate -id \$COSMICCoding \$outputDirectory/1.tmp.dbsnp.vcf | \
java -Xmx3g -jar $snpsiftBin annotate -id \$COSMICNonCoding - > \$outputDirectory/1.tmp.cosmic.vcf ; \
java -Xmx3g -jar $snpsiftBin annotate -info CLNSIG \$clinvar \$outputDirectory/1.tmp.cosmic.vcf > \$outputDirectory/1.tmp.clinvar.vcf ; \
java -Xmx3g -jar $snpsiftBin varType \$outputDirectory/1.tmp.clinvar.vcf > \$outputDirectory/2.tmp.vcf ; \
rm  \$outputDirectory/1.tmp.*.vcf ; \
cat  \$outputDirectory/2.tmp.vcf | \
java -Xmx4g -jar $snpsiftBin annotate -info AF_TWINSUK,AF_ALSPAC \$uk10k - >\
\$outputDirectory/3.tmp.vcf ; \
rm  \$outputDirectory/2.tmp.vcf ; \
cat  \$outputDirectory/3.tmp.vcf | \
java -Xmx4g -jar $snpsiftBin annotate -info AN_AFR,AN_AMR,AN_EAS,AN_FIN,AN_NFE,AN_OTH,AN_SAS,\
Het_AFR,Het_AMR,Het_EAS,Het_FIN,Het_NFE,Het_OTH,Het_SAS,\
Hom_AFR,Hom_AMR,Hom_EAS,Hom_FIN,Hom_NFE,Hom_OTH,Hom_SAS \$exac - >  \
\$outputDirectory/4.tmp.vcf ; \
rm  \$outputDirectory/3.tmp.vcf ; \
cat  \$outputDirectory/4.tmp.vcf | \
java -Xmx4g -jar $snpsiftBin dbnsfp -db \$snpsiftdbNSFP -collapse \
 -f SIFT_score,Polyphen2_HDIV_score,Polyphen2_HVAR_score,\
SIFT_pred,Polyphen2_HVAR_pred,Polyphen2_HDIV_pred,\
GERP++_NR,GERP++_RS,\
MutationTaster_score,MutationTaster_pred,\
SiPhy_29way_logOdds,phastCons100way_vertebrate,\
1000Gp1_AF,1000Gp1_AFR_AF,1000Gp1_EUR_AF,1000Gp1_AMR_AF,1000Gp1_ASN_AF,\
ESP6500_AA_AF,ESP6500_EA_AF,ARIC5606_AA_AF,ARIC5606_EA_AF - >  \
\$outputDirectory/5.tmp.vcf ; \
rm  \$outputDirectory/4.tmp.vcf ; \
cat  \$outputDirectory/5.tmp.vcf | \
java -Xmx4g -jar $snpsiftBin gwasCat -db \$gwasCatalog - > \
\$outputDirectory/6.tmp.vcf ; \
rm \$outputDirectory/5.tmp.vcf ; \
cat  \$outputDirectory/6.tmp.vcf | \
java -Xmx4g -jar $snpsiftBin geneSets -v $msigdb - >  \
\${outputDirectory}/${stem}.${step}.vcf ;  \
rm \$outputDirectory/6.tmp.vcf ; \
bgzip \${outputDirectory}/${stem}.${step}.vcf  ; \
tabix -p vcf \${outputDirectory}/${stem}.${step}.vcf.gz \"

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
" > ${stem}.${step}.bsub

bsub < ${stem}.${step}.bsub

