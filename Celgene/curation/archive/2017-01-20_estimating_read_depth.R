
df <- data.frame(
name  = c("NM99_170_007MR_05_2013_TTAGGC_L004_R1_001.fastq.gz",
          "NM99_170_007MR_05_2013_TTAGGC_L004_R2_001.fastq.gz",
          "NM99_172_001XX_08_2013_TTAGGC_L006_R1_001.fastq.gz",
          "NM99_172_001XX_08_2013_TTAGGC_L006_R2_001.fastq.gz"),
lines = c(84113672, 84113672,344976104,344976104),
bytes  = c(1022357012, 1059983583,4348752308, 4438603256)
)

df[['reads']] <- df$lines / 4
df[['bytes.per.read']]   <- df$bytes / df$reads

mean.bytes.per.read <- mean(df$bytes.per.read)


sizes <- data.frame(
  bytes = scan("~/size", what = numeric(), skip = 1),
  stringsAsFactors = F
)

sizes[['reads']] <- sizes$bytes / mean.bytes.per.read
sizes[['group']] <- 1

library(ggplot2)
ggplot(sizes, aes(factor(group), reads)) + geom_boxplot()

summary(sizes$reads)


test.bytes <- 769192
test.bytes / mean.bytes.per.read
