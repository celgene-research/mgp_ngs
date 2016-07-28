#!/bin/bash
scriptDir=$( dirname $0 ); source $scriptDir/../lib/shared.sh

inputNormalBAM=$1
inputTumorBAM=$2
stem=$(fileStem $inputTumorBAM )
step="GATK.Mutect2"
analysistask=$step

initiateJob $stem $step $1
genomeDatabase=${humanGenomeDir}/genome.fa

exomeSet=$(ngs-sampleInfo.pl $inputTumorBAM bait_set)
case  "${exomeSet}" in
"Nextera_Rapid_Capture_v1.2_Illumina" )
		baitsfile=${humanGenomeDir}/ExonCapture/nexterarapidcapture_exome_targetedregions_v1.2.intervals.bed
	;;
"SureSelect_Human_All_exon_v1_38Mb_Agilent" )
	baitsfile=${humanGenomeDir}/ExonCapture/S0274956_Covered.intervals.bed
	;;
"SureSelect_Human_All_exon_v2_44Mb_Agilent" )
	baitsfile=${humanGenomeDir}/ExonCapture/S0293689_Covered.intervals.bed
	;;
"SureSelect_Human_All_exon_v3_50_Mb_Agilent" )
	baitsfile=${humanGenomeDir}/ExonCapture/S02972011_Covered.intervals.bed
	;;
"SureSelect_Human_All_exon_v4_51Mb_Agilent" )
	baitsfile=${humanGenomeDir}/ExonCapture/S03723314_Covered.intervals.bed
	;;
"SureSelect_Human_All_exon_v4+UTRs_71Mb_Agilent" )
	baitsfile=${humanGenomeDir}/ExonCapture/S03723424_Covered.intervals.bed
	;;
"SureSelect_Human_All_exon_v5+UTRs_75Mb_Agilent" )
	baitsfile=${humanGenomeDir}/ExonCapture/S04380219_Covered.intervals.bed
	;;
"SureSelect_Human_All_exon_v5_50Mb_Agilent" )
	baitsfile=${humanGenomeDir}/ExonCapture/S04380110_Covered.intervals.bed
	;;
"SureSelect_Human_All_exon_v6+COSMIC_64Mb_Agilent" )
	baitsfile=${humanGenomeDir}/ExonCapture/S07604715_Covered.intervals.bed
	;;
"SureSelect_Human_All_exon_v6_58Mb_Agilent" )
	baitsfile=${humanGenomeDir}/ExonCapture/S07604514_Covered.intervals.bed
	;;
"SureSelect_Human_All_exon_v6+UTRs_58Mb_Agilent" )
	baitsfile=${humanGenomeDir}/ExonCapture/S07604624_Covered.intervals.bed
	;;
"Agilent_50_Mb_V5_with_extra_content" )
	baitsfile=${humanGenomeDir}/ExonCapture/morgan.exomeplus.v5.padded.intervals.bed
	;;
"Agilent_50_Mb_v3_with_extra_content" )
	baitsfile=${humanGenomeDir}/ExonCapture/morgan.exomeplus.v3.padded.intervals.bed
	;;
* )
	echo "Cannot recognize exome capture kit"
	;;
esac
captureKit=${exomeSet}

memory=28000
experimentType=$(ngs-sampleInfo.pl $inputNormalBAM experiment_type);
cores=$(fullcores)
header=$(bsubHeader $stem $step $memory $cores)
echo \
"$header

source $scriptDir/../lib/shared.sh

initiateJob $stem $step $1

indexNormal=\$( echo $inputNormalBAM | sed 's/bam$/bai/' ) 
indexNormal=\$( stage.pl --operation out  --type file \$indexNormal )
inputNormalBAM=\$(stage.pl --operation out --type file  $inputNormalBAM )
indexTumor=\$( echo $inputTumorBAM | sed 's/bam$/bai/' ) 
indexTumor=\$( stage.pl --operation out  --type file \$indexTumor )
inputTumorBAM=\$(stage.pl --operation out --type file  $inputTumorBAM )

outputDirectory=\$( setOutput \$inputTumorBAM ${step} )

analyze() {
java -Xmx6g -jar ${gatkbin} \
-T MuTect2 \
-R ${genomeDatabase} \
-I:normal \${inputNormalBAM} \
-I:tumor \${inputTumorBAM} \
--dbsnp ${dbsnp} \
--cosmic ${cosmiccoding} \
--dontUseSoftClippedBases \
--output_mode EMIT_VARIANTS_ONLY \
-L \${outputDirectory}/intervals.bed \
-L \$1 \
-isr INTERSECTION \
-o \${outputDirectory}/${stem}.\$1.vcf 
}
export -f analyze
export inputNormalBAM
export inputTumorBAM
export outputDirectory



# first create the intervals
# second run ContEst
# finally run Mutect2
	
celgeneExec.pl --analysistask $analysistask \
-D \${inputNormalBAM},\${inputTumorBAM} \
--metadatastring analyze='java -Xmx${memory}m -jar ${gatkbin} \
-T MuTect2 \
-R ${genomeDatabase} \
-I:normal \${inputNormalBAM} \
-I:tumor \${inputTumorBAM} \
--dbsnp ${dbsnp} \
--cosmic ${cosmiccoding} \
--dontUseSoftClippedBases \
--output_mode EMIT_VARIANTS_ONLY \
-L \${outputDirectory}/intervals.bed \
-L \$1 \
-o \${outputDirectory}/${stem}.\$1.vcf ' \"\
grep -v ^@ $baitsfile > \${outputDirectory}/intervals.bed ; \
parallel -j${cores} analyze chr{} :::  {1..22} X Y ; \
$bcftoolsbin concat \${outputDirectory}/${stem}.chr{{1..22},{X,Y}}.vcf -o \${outputDirectory}/${stem}.vcf;
rm \${outputDirectory}/${stem}.chr{{1..22},{X,Y}}.vcf\"
if [ \$? != 0 ] ; then
	echo \"Failed to run command\"
	exit 1
fi 


ingestDirectory \$outputDirectory
if [ \$? != 0 ] ; then
	echo \"Failed to ingest data\"
	exit 1
fi 


closeJob
"> ${stem}.${step}.$( getStdSuffix ).bsub

bsub < ${stem}.${step}.$( getStdSuffix ).bsub
#rm $$.tmp

