library(readxl)

uams_calls_to_binary_table <- function(path.to.excel='All_translocation_Summaries_from_BWalker_2016-10-04.xlsx') {
  uams <- read_excel(path=path.to.excel,sheet=1);
  dfci <- read_excel(path=path.to.excel,sheet=2);
  mmrf <- read_excel(path=path.to.excel,sheet=3);
  uams[uams == 'N/A'] <- NA;
  dfci[dfci == 'N/A'] <- NA;
  mmrf[mmrf == 'N/A'] <- NA;
  data.frame(study=c(rep('uams',nrow(uams)),
                     rep('dfci',nrow(dfci)),
                     rep('mmrf',nrow(mmrf))),
             simple_name=c(uams$simple_name,
                           dfci$Sample,
                           mmrf$simple_name),
             CYTO_is_HRD_CONSENSUS=c(uams$UK_HRD_CALL == 'HRD',
                                     dfci$HRD_summary == 'HRD',
                                     mmrf$HRD_Summary == 'HRD'),
             CYTO_TC_GROUP=c(as.character(uams$UK_Tx_CALL),
                             as.character(dfci$TC_summary),
                             as.character(mmrf$TC_Summary)),
             "CYTO_t(4;14)_CONSENSUS"=c(!is.na(as.character(uams$`MANTA_(4;14)`)),
                                        !is.na(as.character(dfci$`MANTA_(4;14)`)),
                                        !is.na(as.character(mmrf$`MANTA_(4;14)`))),
             "CYTO_t(6;14)_CONSENSUS"=c(!is.na(as.character(uams$`MANTA_(6;14)`)),
                                        !is.na(as.character(dfci$`MANTA_(6;14)`)),
                                        !is.na(as.character(mmrf$`MANTA_(6;14)`))),
             "CYTO_t(11;14)_CONSENSUS"=c(!is.na(as.character(uams$`MANTA_(11;14)`)),
                                         !is.na(as.character(dfci$`MANTA_(11;14)`)),
                                         !is.na(as.character(mmrf$`MANTA_(11;14)`))),
             "CYTO_t(14;16)_CONSENSUS"=c(!is.na(as.character(uams$`MANTA_(14;16)`)),
                                         !is.na(as.character(dfci$`MANTA_(14;16)`)),
                                         !is.na(as.character(mmrf$`MANTA_(14;16)`))),
             "CYTO_t(14;20)_CONSENSUS"=c(!is.na(as.character(uams$`MANTA_(14;20)`)),
                                         !is.na(as.character(dfci$`MANTA_(14;20)`)),
                                         !is.na(as.character(mmrf$`MANTA_(14;20)`)))
             )
}