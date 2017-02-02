################################################################################
# Shiny application for visualizing Myeloma Genome Project data details 
#  and aggregated counts.
#
# Dan Rozelle, Ph.D.
# drozelle@ranchobiosciences.com
# Rancho BioSciences 
#

# install.packages("DT")
# install.packages("rpivotTable")

require(shiny)
require(rpivotTable)
require(DT)
require(dplyr)
source("include.R")

app.version = "0.2.2"
library(shiny)

# pull new data tables from S3
# s3 <- "s3://celgene.rnd.combio.mmgp.external/ClinicalData/ProcessedData/Integrated/mgp-shiny/data/"
# system(paste('aws s3 sync',s3, 'data/', sep = " "))

# Import the most recent data tables
options(stringsAsFactors = FALSE)
p.name    <- tail(list.files(path = "data", pattern = "patient", full.names = T), n=1)
p         <- read.delim(p.name)
p.version <- gsub(".*?([0-9-]+)\\.txt", "\\1",p.name)

s.name    <- tail(list.files(path = "data", pattern = "sample", full.names = T), n=1)
s         <- read.delim(s.name)
s.version <- gsub(".*?([0-9-]+)\\.txt", "\\1",s.name)

f.name    <- tail(list.files(path = "data", pattern = "file", full.names = T), n=1)
f         <- read.delim(f.name)
f.version <- gsub(".*?([0-9-]+)\\.txt", "\\1",f.name)

d.name    <- tail(list.files(path = "data", pattern = "dictionary", full.names = T), n=1)
d         <- read.delim(d.name, header = T, sep = "\t")
d <- select(d, names:UAMS_Source)
d.version <- gsub(".*?([0-9-]+)\\.txt", "\\1",d.name)

###
# precalculate some fields
study.names <- unique(p$Study)
columns <- names(f)
chem <- grep("CBC_Absolute_Neutrophil", columns)
cyto <- grep("CYTO_Karyotype_FISH", columns)
demo <- grep("D_Gender", columns)
inv  <- grep("INV_Has.sample", columns)

###########################################
# generate the UI panel with checkbox selectors
ui <- shinyUI(fluidPage(
  theme = "styles.css",
  
  headerPanel("MGP Data Explorer"),
  sidebarLayout(
    sidebarPanel(width = 4,
                 downloadButton('download_handler', 'Download Filtered Data'),
                 selectInput(inputId  = "levelSelect",
                             label    = "Select desired row level",
                             choices  = list("Per-File","Per-Sample","Per-Patient"),
                             selected = "Per-File"),
                 checkboxGroupInput(inputId = "checkGroupStudy",
                                    label = h4("Select datasets to include"),
                                    choices  = study.names,
                                    selected = study.names
                 ),
                 h4("Select columns to display"),
                 tabsetPanel(
                   tabPanel('Sample', checkboxGroupInput(inputId = "checkGroupSample",
                                                       label = "",
                                                       choices = columns[1:chem-1],
                                                       selected = c("Patient", "Study", "Sample_Name_Tissue_Type"))
                   ),tabPanel('Dem.', checkboxGroupInput(inputId = "checkGroupDemo",
                                                       label = "",
                                                       choices = columns[demo:inv-1],
                                                       selected = c("D_OS", "D_PFS"))
                   ),
                   tabPanel('Chem', checkboxGroupInput(inputId = "checkGroupChem",
                                                       label = "",
                                                       choices = columns[chem:cyto-1],
                                                       selected = c(""))
                   ),
                   tabPanel('Cyto', checkboxGroupInput(inputId = "checkGroupCyto",
                                                       label = "",
                                                       choices = columns[cyto:demo-1],
                                                       selected = c(""))
                   ),
                   tabPanel('Inv', checkboxGroupInput(inputId = "checkGroupInv",
                                                      label = "",
                                                      choices = columns[inv:length(columns)],
                                                      selected = c(""))
                   )
                   
                 )
    ),
    
    # Generate the output panels
    mainPanel(
      tabsetPanel(
        tabPanel("Details", DT::dataTableOutput(outputId =  "df_main_table")),
        tabPanel("Pivot",  rpivotTable::rpivotTableOutput(outputId =  "pivotObject")),
        tabPanel("Dictionary",  DT::dataTableOutput(outputId =  "dict_table")),
        # tabPanel("Counts", tableOutput(outputId =  "counts")),
        tabPanel("Help",
                 p("This R-Shiny application has been created to assist in data exploration and 
                     cohort selection for the Myeloma Genome Project. It provides the ability to 
                   specify subsets of columns and filter individual data on the study and response level.
                   This subsetted data can then be downloaded for further offline analysis."),
                 h4("Filtering the Details Table:"),
                 p("Use the checkbox groups to add and subtract specific
                   columns from the table. Entire Study datasets can similarly be toggled using the side
                   panel checkboxes. Columns are generally split into four tabbed lists by Demographic, Blood
                    Chemistry, Cytogenetics, and Inventory columns. After selecting columns, you can use the 
                   filter boxes under each column title to refine which factors you'd like to include 
                   (e.g. OS>100 and Hyperdiploid = 1). This must be done *after* column selection, otherwise 
                   the filters will be reset."),
                 h4("Downloading data:"),
                 p("After selecting columns and filtering rows, the resulting table can be downloaded using the
                   \"Download Filtered Data\" button"),
                 h4("Pivot Table:"),
                 p("To further explore aggregated data we provide a Pivot Table on the second tab. 
                   By clicking and dragging individual fields to one of the blue row and column regions
                   you can automatically sort, count, sum or give the average of the data. Using the 
                   \"pull down arrows\" individual fields can be provide another layer of filtering.
                   Due to the dynamic nature of a pivot table, you typically need to scroll your window
                   further to the right after adding additional columns."),
                 h4("Counts:"),
                 p("This table provides a simple count of the total number of patients by study that
                   we currently have data for a given column. This updates when new columns are added
                   or entire studies are toggled with the checkboxes, but does not respond to text-filtered
                   queries."),
                 h4("Column Metadata:"),
                 p(""),
                 h4("Version Info:"),
                 tags$ul(paste("MGP Integrated Dataviewer version:", app.version)),
                 tags$ul(paste("Per-Patient version:", p.version)),
                 tags$ul(paste("Per-Sample version:", s.version)),
                 tags$ul(paste("Per-File version:", f.version)),
                 tags$ul(paste("Data dictionary version:", d.version)),
                 # actionButton("update.data.sources", label = "check for new data"),
                 p(""),
                 span("For questions and comments please contact"),
                 a("Dan Rozelle", href="mailto:drozelle@ranchobiosciences.com"),
                 span("or"),
                 a("David Ballard", href="mailto:dballard@celgene.com")
      )
    )
  )
)))



server <- shinyServer(function(input, output, session) {
  
  # generate a filtered subtable every time a checkbox is adjusted
  subtable <- reactive({
    
    if( input$levelSelect == "Per-Patient" ){
        df <- p
      }else if( input$levelSelect == "Per-Sample" ){
        df <- s
      }else if( input$levelSelect == "Per-File" ){
        df <- f
      }
    df[df$Study %in% input$checkGroupStudy, names(df) %in% c(input$checkGroupSample, input$checkGroupDemo, input$checkGroupChem, input$checkGroupCyto, input$checkGroupInv)]
  
    })
  
  # generate the details table from the subtable object
  output$df_main_table <- DT::renderDataTable({subtable()}, filter = "top",
                                              options = list(lengthMenu = c(10, 50, 100), pageLength = 100))
  
  output$dict_table <- DT::renderDataTable(d, filter = "top",
                                              options = list(lengthMenu = c(10, 50, 100), pageLength = 100))


  
  # generate the summary count table from the subtable object
  # output$counts <- renderTable({
  #   logic_table <- !(is.na(subtable()))
  #   
  #   split <- aggregate.data.frame(logic_table, by = list("Study" = subtable()[,"Study"]), sum)
  #   split$Patient <- NULL
  #   total <- aggregate.data.frame(logic_table, by = list("Study" = rep(1,nrow(subtable()))), sum)
  #   total[1,"Study"] <- "Total"
  #   total$Patient <- NULL
  #   out <- rbind(split, total)
  #   n <- names(out)
  #   n[[2]] <- "n"
  #   names(out) <- n
  #   out
  # })
  
  output$pivotObject <- rpivotTable::renderRpivotTable({
    rpivotTable::rpivotTable(data           = subtable(),
                             # rows           = c("INV_Has.WES", "INV_Has.WGS"),
                             cols           = "Study",
                             vals           = "Patient",
                             aggregatorName = "Count",
                             rendererName   = "Table",
                             width          = "50%",
                             height         = "500px")
  })
  

  output$download_handler <- downloadHandler(
    filename = 'mgp-filtered.txt',
    content  = function(con){
      s <- input$df_main_table_rows_all  
      write.table(x = subtable()[s, ], 
                file = con,
                quote = F,
                append = F, 
                sep = "\t", 
                row.names = F)}
    )
})

shinyApp(ui = ui, server = server)

