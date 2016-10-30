source('uams-70.R')
library(GEOquery)
library(survival)

dataset <- suppressWarnings(getGEO(GEO='GSE57317')[[1]])
scores <- uams.70.eset(dataset,already.log2.transformed = F)
gep70.score <- as.numeric(gsub(pattern = 'gep70 score: ',replacement = '',as.character(dataset[['characteristics_ch1.5']])))
if(sum(gep70.score-round(scores$raw.score,digits=4)) < 10^(-4)) {
  message('GEP70 scores match paper')
}