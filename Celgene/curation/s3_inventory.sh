#!/bin/bash

##
##  Get bam file names and parse them into dataset specific columns
##  Return: ./file_inventory.txt
## 
##  Dan Rozelle, PhD
##  drozelle@ranchobiosciences.com
##  2016-10-21

#example filepaths
# RNA-Seq
# SeqData/RNA-Seq/OriginalData/MMRF/IA3/MMRF_1024_2_BM_CD138pos_T2_TSMRU_K03518.bam

# WES
# SeqData/WES/OriginalData/MMRF/IA3/MMRF_1024_2_BM_CD138pos_T2_KHS5U_L13428.bam
# SeqData/WES/OriginalData/DFCI/42_PD4283a/mapped_sample/HUMAN_37_pulldown_PD4283a.bam
# SeqData/WES/OriginalData/FMed/TRF017566.sorted.bam
# SeqData/WES/OriginalData/UAMS/_EGAR00001320990_EGAS00001001147_C25U8ACXX_1_466.bam

# WGS
# SeqData/WGS/OriginalData/MMRF/IA9/MMRF_1049_3_BM_CD138pos_T1_KHWGL_L12961.bam

# Output fields 
# Data_Type	  Study	  Phase	  Patient	Sample_Name	  Filename	  Path	  


# inventory mmrf sequencing files on S3
aws s3 ls s3://celgene.rnd.combio.mmgp.external/SeqData/RNA-Seq/OriginalData/ --recursive >file_inventory
aws s3 ls s3://celgene.rnd.combio.mmgp.external/SeqData/WES/OriginalData/ --recursive     >>file_inventory
aws s3 ls s3://celgene.rnd.combio.mmgp.external/SeqData/WGS/OriginalData/ --recursive     >>file_inventory

# filter for only appropriate bam files
grep "bam$" file_inventory | grep -v "ump.bam$" |

# parse path/filename into columns
awk '
BEGIN     { FS="/"; OFS="	"; 
			print "Sequencing_Type","Study","Study_Phase","Patient","Sample_Name","File_Name","File_Path"}
# trim leader details from ls row
{sub("^.*SeqData","SeqData"); path=$0;}

/MMRF/ {  file=$6; sub("\.bam","",$6);
          print $2, $4, $5, substr($6,1,9), substr($6,1,11), file, path  }

/DFCI/ {  patient=$5; sub("^.{3}","",patient); sample=patient; sub(".$","",patient); 
          file=$7; 
          print $2, $4, "", patient, sample, file, path  }

/FMed/ {  print $2, $4, "", substr($5,1,9), substr($5,1,9), $5, path }

/UAMS/ {  file=$5; sub("_E[A-Z0-9]+_","",$5); sub("E[A-Z0-9]+_","",$5); sub("\.bam","",$5);
          print $2,$4,"","","",$5,path  }

'  >file_inventory.txt

aws s3 cp file_inventory.txt s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/Integrated/file_inventory.txt --sse

rm ./file_inventory
rm ./file_inventory.txt

