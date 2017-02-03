s3 <- "s3://celgene.rnd.combio.mmgp.external"
system(paste("aws s3 cp",
             file.path(s3,
             "ClinicalData/OriginalData/DFCI",
             "DFCI_RNASeqTransferMap.xlsx"),
             "/tmp/",
             sep = " "))

df <- readxl::read_excel("/tmp/DFCI_RNASeqTransferMap.xlsx")
samples <- c(df$File_R1, df$File_R2)
inv <- system('aws s3 ls s3://celgene.rnd.combio.mmgp.external.datadrop/dfci/ | sed  -r \'s/[ \t]+/ /g\' | cut -d \" \" -f 4 ', intern = T)

any(duplicated(inv))
any(duplicated(samples))

# sample names not in s3
samples[!(samples %in% inv)]

# s3 files not on sample list
inv[!(inv %in% samples)]

df$SampleID[duplicated(df$SampleID)]
