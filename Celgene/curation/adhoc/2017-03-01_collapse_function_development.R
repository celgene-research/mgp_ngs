library(dplyr)
df <- per.file.all 
# %>%  subset(Study == "MMRF") %>% arrange(Sample_Name) 


# ptm <- proc.time()
# small.df <- small.df %>% group_by(Sample_Name) %>% summarise_all(Simplify)
# proc.time() - ptm
# # elapsed 2.309
# 
# ptm2 <- proc.time()
# small.dt <- small.dt[, lapply(.SD,toolboxR::Simplify), by = Sample_Name]
# proc.time() - ptm2
# elapsed 1.569

# ptm3 <- proc.time()
# dt <- DT[, lapply(.SD,toolboxR::Simplify), by = Sample_Name]
# proc.time() - ptm3
# elapsed = too long

# alternative approach
# spread using dcast again
# 

# 
# ptm <- proc.time()
# # gather all variables into a single column
# # dt <- as.data.table(mutate_all(df, as.character))
# dt   <- as.data.table(df)
# 
# # suppress the coersion warning since it is expected
# # <simpleWarning in melt.data.table(dt, id.vars = "Sample_Name", na.rm = TRUE): 
# # 'measure.vars' [File_Name, Patient, Study, Study_Phase, ...] are not all of 
# # the same type. By order of hierarchy, the molten data value column will be of 
# # type 'character'. All measure variables not of type 'character' will be coerced 
# # to. Check DETAILS in ?melt.data.table for more on coercion.> 
# catch <- tryCatch(
#   long <- data.table::melt(dt, id.vars = "Sample_Name", na.rm = TRUE),
#   error = function(e) e,
#   warning = function(w) w
# )
# 
# # filter to remove all NA, blank, or non-duplicated rows
# # remove sample-variable sets that are already unique
# already.unique <- long[(value != "NA"), `:=`(n=.N), by = .(Sample_Name, variable)][n==1, 1:3]
# duplicated     <- long[(value != "NA"), `:=`(n=.N), by = .(Sample_Name, variable)][n>1, 1:3]
# 
# # summarize remaining fields to simplify
# dedup          <- duplicated[, .(value = Simplify(value)), by = .(Sample_Name, variable)]
# 
# # join and spread 
# long <- rbind(already.unique, dedup)
# wide <- data.table::dcast(long, Sample_Name ~ variable, value.var = "value")
# 
# proc.time() - ptm

devtools::install_github("dkrozelle/toolboxR")
library(toolboxR)


# http://stats.idre.ucla.edu/r/faq/how-can-i-collapse-my-data-in-r/
# library(doBy)
# 
ptm <- proc.time()
out <- summaryBy( File_Path+Disease_Status+Patient ~ Sample_Name, FUN = toolboxR::Simplify, data=df, keep.names = T)
proc.time() - ptm

# collapse1 <- summaryBy(socst + math ~ prog + ses + female, FUN=c(mean,sd), data=hsb2)
# collapse1 