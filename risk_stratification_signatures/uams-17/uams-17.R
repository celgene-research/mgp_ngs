library(Biobase)
library(GEOquery)
library(biomaRt)

uams.17.eset <- function(eset,already.log2.transformed=FALSE) {
  
  coefficients <- c(0.283,-0.296,-0.208,+0.314,-0.287,+0.251,+0.193,+0.269,+0.375,+0.158,+0.316,+0.232,-0.251,-0.23,-0.402,+0.191,+0.148)
  names(coefficients) <- c("200638_s_at","1557277_a_at","200850_s_at","201897_s_at","202729_s_at","203432_at","204016_at","205235_s_at","206364_at","206513_at","211576_s_at","213607_x_at","213628_at","218924_s_at","219918_s_at","220789_s_at","242488_at")
  
  training <- log2(exprs(suppressMessages(suppressWarnings(getGEO(GEO='GSE2658')[[1]])))[names(coefficients),])
  
  cutoff <- 1.5
  
  data <- exprs(eset[intersect(names(coefficients),featureNames(eset)),])
  training <- training[match(rownames(data),rownames(training)),]
  
  if(!already.log2.transformed) {
    data <- log2(data)
  }
  trainingMeans <- rowMeans(training)
  trainingSDs <- apply(training,1,sd)
  data <- t((data - trainingMeans) / trainingSDs)
  
  available <- match(names(coefficients),featureNames(eset))
  if(any(is.na(available))) {
    warning(paste('The following probesets are missing: ',paste(names(coefficients)[is.na(available)],collapse=', ')))
  }
  available <- na.exclude(available);
  
  raw.score <- data[,available] %*% coefficients[available]
  data.frame(ID=sampleNames(eset),raw.score=raw.score,high.risk=round(raw.score,digits=1) > cutoff)
}

# assumes that mapping is a data.frame with 2 columns: INDEX and GENE
# INDEX = any type of ID (e.g., ENTREZID)
# GENE = Official gene symbol
uams.17.gene <- function(inmatrix,mapping,already.log2.transformed=FALSE) {
  if(nrow(inmatrix) != nrow(mapping)) {
    inter <- intersect(rownames(inmatrix),mapping$INDEX);
    inmatrix <- inmatrix[match(inter,rownames(inmatrix)),];
    mapping <- mapping[match(inter,mapping$INDEX),]
  }
  if(length(intersect(rownames(inmatrix),mapping$INDEX)) == 0) {
    rownames(inmatrix) <- mapping$INDEX
  }
  probesets <- c("200638_s_at","1557277_a_at","200850_s_at","201897_s_at","202729_s_at","203432_at","204016_at","205235_s_at","206364_at","206513_at","211576_s_at","213607_x_at","213628_at","218924_s_at","219918_s_at","220789_s_at","242488_at")
  ensembl = useMart("ensembl",dataset="hsapiens_gene_ensembl")
  bm <- getBM(attributes=c('affy_hg_u133_plus_2', 'hgnc_symbol'), 
                 filters = 'affy_hg_u133_plus_2', 
                 values = probesets, 
                 mart = ensembl)
  bm <- bm[order(bm$affy_hg_u133_plus_2),]
  # The CKS1BP3 gene is never referred to in the patent or manuscript so
  # we will ignore it from our calculations
  # See: https://www.google.com/patents/US20080187930
  bm <- bm[!(bm$hgnc_symbol %in% c('','CKS1BP3')),]
  inmat <- apply(
    inmatrix[na.exclude(match(bm$hgnc_symbol,mapping$GENE)),!is.na(colnames(inmatrix))],
    c(1:2),
    as.numeric);
  rownames(inmat) <- bm$affy_hg_u133_plus_2[match(
    mapping$GENE[match(rownames(inmat),mapping$INDEX)],bm$hgnc_symbol)]
  eset <- ExpressionSet(assayData = inmat)
  uams.17.eset(eset,already.log2.transformed=already.log2.transformed)
}

uams.17.entrez <- function(inmatrix,already.log2.transformed=FALSE) {
  ensembl = useMart("ensembl",dataset="hsapiens_gene_ensembl")
  bm <- getBM(attributes=c('entrezgene', 'hgnc_symbol'), 
              filters = 'entrezgene', 
              values = rownames(inmatrix), 
              mart = ensembl)
  names(bm) <- c('INDEX','GENE');
  uams.17.gene(inmatrix,bm,already.log2.transformed=already.log2.transformed)
}