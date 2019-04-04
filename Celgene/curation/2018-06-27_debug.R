



write_new_version(clinical, name = "curated.clinical", dir = 's3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/JointData')
s3_ls()
# grab it back and confirm the same row count
foo <- s3_get_table("curated.clinical.2018-07-10.txt") 

s3_put_table(clinical, "trash/demo.txt")

View(clinical[!clinical$Patient %in% bar$Patient, "Patient"])

baz <- s3_get_table("trash/demo.tsv")

s3_put_table(clinical)
a <- paste('aws s3 cp',
           "/tmp/drozelle/demo3.txt",
           "s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/JointData/curated.clinical",
           s3e$sse)

s3r:::aws_cli(a)
bar <- s3_get_table("curated.clinical") 

# replace and redo
s3_mv("curated.clinical.2018-07-10.txt", "trash/curated.clinical.2018-07-10.txt", allow.overwrite = T)
s3_mv("archive/curated.clinical.2017-08-08.txt", "curated.clinical.2017-08-08.txt")
s3_ls()

