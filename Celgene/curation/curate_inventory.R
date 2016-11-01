## drozelle@ranchobiosciencs.com
##

# The inventory script captures file paths of all bam files from SeqData/OriginalData
system('./s3_inventory.sh')

# put the new inventory sheet on S3, remove local files
system('aws s3 cp file_inventory.txt s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/Integrated/file_inventory.txt --sse')
system('rm file_inventory.txt')