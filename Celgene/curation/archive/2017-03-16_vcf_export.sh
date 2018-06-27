#!/bin/bash

# 2017-03-16 export Kostas' unprocessed vcf files for MMRF delivery to Daniel Auclair
# capture a filtered list of s3 files we want
aws s3 ls s3://celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/MMRF/ --recursive | grep -E -e ".*Mutect2_1.*MarkDuplicates.*vcf$" -e "Strelka_1.*MarkDuplicates.*all.somatic.*vcf$" >vcf.inventory

# download from s3 into Mutec2 or Strelka directories, edit Strelka names to be non-generic
cat vcf.inventory | sed -r 's/\s+/ /g' | cut -d" " -f4 | xargs -n1 -I{} sh -c 'f={}; aws s3 cp s3://celgene.rnd.combio.mmgp.external/{} /scratch/tmp/drozelle/mmrf.vcf/`echo {} | grep -o -e "Strelka" -e "GATK.Mutect2"`/`basename ${f/\/results\//.}`'

# example output
# download: s3://celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/MMRF/Strelka_1474326574/MMRF_1016_1_BM_CD138pos_T1_KBS5U_L02999.MarkDuplicates.mdup.seqvar/results/all.somatic.indels.vcf
# to
# ../../scratch/tmp/drozelle/mmrf.vcf/Strelka/MMRF_1016_1_BM_CD138pos_T1_KBS5U_L02999.MarkDuplicates.mdup.seqvar.all.somatic.indels.vcf
