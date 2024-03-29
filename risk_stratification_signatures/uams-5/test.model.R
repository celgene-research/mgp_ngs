source('uams-5.R')
library(GEOquery)
library(survival)

dataset <- suppressWarnings(getGEO(GEO='GSE57317')[[1]])
scores <- uams.5.eset(dataset)
os <- as.numeric(gsub(pattern = 'OS time: ',replacement = '',as.character(pData(dataset)[['characteristics_ch1.6']])))
censoring <- as.numeric(gsub(pattern = 'os censored: ',replacement = '',as.character(pData(dataset)[['characteristics_ch1.7']])))
cox <- coxph(Surv(os,event=censoring)~scores$high.risk)
print(cox)
if(summary(cox)$logtest[['pvalue']] < 0.0001) {
  message('Logrank p-value matches paper')
}