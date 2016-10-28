source('uams-17.R')
library(GEOquery)
library(survival)

dataset <- suppressWarnings(getGEO(GEO='GSE2658')[[1]])
scores <- uams.17.eset(dataset,already.log2.transformed = F)
os <- as.numeric(gsub(pattern = '.*SURTIM=(\\d+\\.?\\d*) .*',replacement = '\\1',as.character(pData(dataset)[['characteristics_ch1.2']])))
censoring <- as.numeric(gsub(pattern = '.*SURIND=(\\d) .*',replacement = '\\1',as.character(pData(dataset)[['characteristics_ch1']])))
cox <- coxph(Surv(os,event=censoring)~scores$high.risk)
print(summary(cox))
if(summary(cox)$logtest[['pvalue']] < 0.0001) {
  message('Logrank p-value matches paper')
}