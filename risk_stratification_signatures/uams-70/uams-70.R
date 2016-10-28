library(Biobase)
library(GEOquery)
library(biomaRt)

uams.70.eset <- function(eset,already.log2.transformed=FALSE) {
  
  up<-c("202345_s_at","1555864_s_at","204033_at","206513_at","1555274_a_at","211576_s_at","204016_at","1565951_s_at","219918_s_at","201947_s_at","213535_s_at","204092_s_at","213607_x_at","208117_s_at","210334_x_at","204023_at","201897_s_at","216194_s_at","225834_at","238952_x_at","200634_at","208931_s_at","206332_s_at","220789_s_at","218947_s_at","213310_at","224523_s_at","201231_s_at","217901_at","226936_at","58696_at","200916_at","201614_s_at","200966_x_at","225082_at","242488_at","243011_at","201105_at","224200_s_at","222417_s_at","210460_s_at","200750_s_at","206364_at","201091_s_at","203432_at","221970_s_at","212533_at","213194_at","244686_at","200638_s_at","205235_s_at")
  down<-c("201921_at","227278_at","209740_s_at","227547_at","225582_at","200850_s_at","213628_at","209717_at","222495_at","1557277_a_at","1554736_at","218924_s_at","226954_at","202838_at","230192_at","48106_at","237964_at","202729_s_at","212435_at")
  cutoff <- 0.66;
  
  if(already.log2.transformed) {
    data <- exprs(eset[c(up,down),])
  } else {
    data <- log2(exprs(eset[c(up,down),]))
  }
  
  data_up<-t(data[up,])
  data_down<-t(data[down,])
  raw.score<-rowMeans(data_up)-rowMeans(data_down)
  data.frame(ID=sampleNames(eset),raw.score=raw.score,high.risk=round(raw.score,digits=2) > cutoff)
}

# assumes that mapping is a data.frame with 2 columns: INDEX and GENE
# INDEX = any type of ID (e.g., ENTREZID)
# GENE = Official gene symbol
uams.70.gene <- function(inmatrix,mapping,already.log2.transformed=FALSE) {
  if(nrow(inmatrix) != nrow(mapping)) {
    inter <- intersect(rownames(inmatrix),mapping$INDEX);
    inmatrix <- inmatrix[match(inter,rownames(inmatrix)),];
    mapping <- mapping[match(inter,mapping$INDEX),]
  }
  if(length(intersect(rownames(inmatrix),mapping$INDEX)) == 0) {
    rownames(inmatrix) <- mapping$INDEX
  }
  inmatrix <- inmatrix[,!is.na(colnames(inmatrix))]
  ensembl = useMart("ensembl",dataset="hsapiens_gene_ensembl")
  up<-c("202345_s_at","1555864_s_at","204033_at","206513_at","1555274_a_at","211576_s_at","204016_at","1565951_s_at","219918_s_at","201947_s_at","213535_s_at","204092_s_at","213607_x_at","208117_s_at","210334_x_at","204023_at","201897_s_at","216194_s_at","225834_at","238952_x_at","200634_at","208931_s_at","206332_s_at","220789_s_at","218947_s_at","213310_at","224523_s_at","201231_s_at","217901_at","226936_at","58696_at","200916_at","201614_s_at","200966_x_at","225082_at","242488_at","243011_at","201105_at","224200_s_at","222417_s_at","210460_s_at","200750_s_at","206364_at","201091_s_at","203432_at","221970_s_at","212533_at","213194_at","244686_at","200638_s_at","205235_s_at")
  down<-c("201921_at","227278_at","209740_s_at","227547_at","225582_at","200850_s_at","213628_at","209717_at","222495_at","1557277_a_at","1554736_at","218924_s_at","226954_at","202838_at","230192_at","48106_at","237964_at","202729_s_at","212435_at")
  cutoff <- 0.66;
  
  bm.up <- getBM(attributes=c('affy_hg_u133_plus_2', 'hgnc_symbol'), 
        filters = 'affy_hg_u133_plus_2', 
        values = up, 
        mart = ensembl)
  
  bm.down <- getBM(attributes=c('affy_hg_u133_plus_2', 'hgnc_symbol'), 
                 filters = 'affy_hg_u133_plus_2', 
                 values = down, 
                 mart = ensembl)
  
  up <- bm.up$hgnc_symbol[!(bm.up$hgnc_symbol %in% c(''))]
  down <- bm.down$hgnc_symbol[!(bm.down$hgnc_symbol %in% c(''))]
  data <- apply(inmatrix,c(1:2),as.numeric);
  if(!already.log2.transformed) {
    data <- log2(inmatrix)
  }
  data_up<-t(data[toupper(mapping$GENE) %in% toupper(up),])
  data_down<-t(data[toupper(mapping$GENE) %in% toupper(down),])
  raw.score<-rowMeans(data_up)-rowMeans(data_down)
  data.frame(ID=colnames(inmatrix),raw.score=raw.score,high.risk=round(raw.score,digits=2) > cutoff)
}

uams.70.entrez <- function(inmatrix,already.log2.transformed=FALSE) {
  ensembl = useMart("ensembl",dataset="hsapiens_gene_ensembl")
  bm <- getBM(attributes=c('entrezgene', 'hgnc_symbol'), 
              filters = 'entrezgene', 
              values = rownames(inmatrix), 
              mart = ensembl)
  names(bm) <- c('INDEX','GENE');
  uams.70.gene(inmatrix,bm,already.log2.transformed=already.log2.transformed)
}