#/bin/sh


# UAMS
mkdir /mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/UAMS/manta.human_1469059025/manta.human_1469059025_merged
find /mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/UAMS/manta.human_1469059025 -name "somaticSV.vcf.gz" -type f >/mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/UAMS/manta.human_1469059025/manta.human_1469059025_merged/file_list_somatic.txt
cat /mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/UAMS/manta.human_1469059025/manta.human_1469059025_merged/file_list_somatic.txt | xargs vcf-merge >/mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/UAMS/manta.human_1469059025/manta.human_1469059025_merged/merged_somatic.vcf

find /mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/UAMS/manta.human_1469059025 -name "candidateSmallIndels.vcf.gz" -type f >/mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/UAMS/manta.human_1469059025/manta.human_1469059025_merged/file_list_indel.txt
cat /mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/UAMS/manta.human_1469059025/manta.human_1469059025_merged/file_list_indel.txt | xargs vcf-merge >/mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/UAMS/manta.human_1469059025/manta.human_1469059025_merged/merged_indel.vcf

find /mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/UAMS/manta.human_1469059025 -name "diploidSV.vcf.gz" -type f >/mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/UAMS/manta.human_1469059025/manta.human_1469059025_merged/file_list_diploid.txt
cat /mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/UAMS/manta.human_1469059025/manta.human_1469059025_merged/file_list_diploid.txt | xargs vcf-merge >/mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/UAMS/manta.human_1469059025/manta.human_1469059025_merged/merged_diploid.vcf

find /mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/UAMS/manta.human_1469059025 -name "candidateSV.vcf.gz" -type f >/mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/UAMS/manta.human_1469059025/manta.human_1469059025_merged/file_list_candidatesv.txt
cat /mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/UAMS/manta.human_1469059025/manta.human_1469059025_merged/file_list_candidatesv.txt | xargs vcf-merge >/mnt/celgene.rnd.combio.mmgp.external/SeqData/WES/ProcessedData/UAMS/manta.human_1469059025/manta.human_1469059025_merged/merged_candidatesv.vcf
