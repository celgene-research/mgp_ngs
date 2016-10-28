library(Biobase)
library(biomaRt)

uams.5.eset <- function(eset,already.log2.transformed=FALSE) {
  probesets <- c('204033_at','200916_at','204023_at','202345_s_at','201231_s_at')
  cutoff <- 10.68
  if(already.log2.transformed) {
    raw.score <- apply(exprs(eset[featureNames(eset) %in% probesets,]),2,mean)
  } else {
    raw.score <- apply(log2(exprs(eset[featureNames(eset) %in% probesets,])),2,mean)
  }
  data.frame(ID=sampleNames(eset),raw.score=raw.score,high.risk=round(raw.score,digits=2) > cutoff)
}

# assumes that mapping is a data.frame with 2 columns: INDEX and GENE
# INDEX = any type of ID (e.g., ENTREZID)
# GENE = Official gene symbol
uams.5.gene <- function(inmatrix,mapping,already.log2.transformed=FALSE) {
  if(nrow(inmatrix) != nrow(mapping)) {
    inter <- intersect(rownames(inmatrix),mapping$INDEX);
    inmatrix <- inmatrix[match(inter,rownames(inmatrix)),];
    mapping <- mapping[match(inter,mapping$INDEX),]
  }
  if(length(intersect(rownames(inmatrix),mapping$INDEX)) == 0) {
    rownames(inmatrix) <- mapping$INDEX
  }
  genes <- c('TRIP13','TAGLN2','RFC4','FABP5','ENO1')
  probesets <- c('204033_at','200916_at','204023_at','202345_s_at','201231_s_at')
  available <- mapping[['INDEX']][match(toupper(genes),toupper(mapping[['GENE']]))];
  if(any(is.na(available))) {
    warning(paste('The following genes are missing from the supplied dataset: ',paste(genes[is.na(available)],collapse=', ')))
  }
  inmatrix <- inmatrix[na.exclude(available),]
  rownames(inmatrix) <- probesets[!is.na(available)];
  inmat <- apply(inmatrix,c(1:2),as.numeric)
  inmat <- inmat[,!is.na(colnames(inmat))]
  eset <- ExpressionSet(assayData = inmat)
  uams.5.eset(eset=eset,already.log2.transformed=already.log2.transformed)
}

uams.5.entrez <- function(inmatrix,already.log2.transformed=FALSE) {
  ensembl = useMart("ensembl",dataset="hsapiens_gene_ensembl")
  bm <- getBM(attributes=c('entrezgene', 'hgnc_symbol'), 
              filters = 'entrezgene', 
              values = rownames(inmatrix), 
              mart = ensembl)
  names(bm) <- c('INDEX','GENE');
  uams.5.gene(inmatrix,bm,already.log2.transformed=already.log2.transformed)
}