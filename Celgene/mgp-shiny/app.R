################################################################################
# Shiny application for visualizing Myeloma Genome Project data details 
#  and aggregated counts.
#
# Dan Rozelle, Ph.D.
# drozelle@ranchobiosciences.com
# Rancho BioSciences 
#
# require(shiny)
# require(rpivotTable)
# require(DT)

app_version = "0.2"
library(shiny)

# Import the most recent data table
f <- list.files(path = "data", pattern = "^INTEGRATED_patient.*", full.names = T)
if(length(f) > 1){f <- f[-1]}
data <- read.delim(f)
data_version <- gsub(".*?([0-9-]+)\\.txt", "\\1",f)

f2 <- list.files(path = "data", pattern = "^integrated_columns.*", full.names = T)
if(length(f2) > 1){f2 <- f2[-1]}
dict <- read.delim(f2)
dictionary_version <- gsub(".*?([0-9-]+)\\.txt", "\\1",f2)

# Extract column and study names for checkbox selectors
study_names <- as.character(unique(data$Study))

column_names <- names(data)
s1 <- 1
s2  <- grep("Absolute_Neutrophil", column_names)
s3  <- grep("Karyotype", column_names)
s4  <- grep("Has.Patient", column_names)

###########################################
# generate the UI panel with checkbox selectors
ui <- shinyUI(fluidPage(
  theme = "styles.css",
  
  headerPanel("MGP Integrated Dataviewer"),
  sidebarLayout(
    sidebarPanel(width = 4,
                 downloadButton('download_handler', 'Download Filtered Data'),
                 checkboxGroupInput(inputId = "checkGroupStudy",
                                    label = h4("Select Datasets to Include"),
                                    choices  = study_names,
                                    selected = study_names
                 ),
                 h4("Select Columns to Display"),
                 tabsetPanel(
                   tabPanel('Dem', checkboxGroupInput(inputId = "checkGroupDemo", 
                                                      label = "", 
                                                      choices = column_names[s1:s2-1],
                                                      selected = c("Patient", "Study", "D_Medical_History", "D_OS"))
                   ),
                   tabPanel('Chem', checkboxGroupInput(inputId = "checkGroupChem", 
                                                       label = "", 
                                                       choices = column_names[s2:s3-1],
                                                       selected = c(""))
                   ),
                   tabPanel('Cyto', checkboxGroupInput(inputId = "checkGroupCyto", 
                                                       label = "", 
                                                       choices = column_names[s3:s4-1],
                                                       selected = c("Karyotype"))
                   ),
                   tabPanel('Inv', checkboxGroupInput(inputId = "checkGroupInv", 
                                                      label = "", 
                                                      choices = column_names[s4:length(column_names)],
                                                      selected = c("Has.WES"))
                   )
                   
                 )
    ),
    
    # Generate the output panels
    mainPanel(
      tabsetPanel(
        tabPanel("Details", DT::dataTableOutput(outputId =  "df_main_table")),
        tabPanel("Pivot",  rpivotTable::rpivotTableOutput(outputId =  "pivotObject")),
        tabPanel("Dictionary",  DT::dataTableOutput(outputId =  "dict_table")),
        tabPanel("Counts", tableOutput(outputId =  "counts")),
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
                 tags$ul(paste("MGP Integrated Dataviewer version:", app_version)),
                 tags$ul(paste("Data tables processed on:", data_version)),
                 tags$ul(paste("Data dictionary version:", dictionary_version)),
                 p(""),
                 span("For questions and comments please contact"),
                 a("Dan Rozelle", href="mailto:drozelle@ranchobiosciences.com"),
                 span("or"),
                 a("David Ballard", href="mailto:dballard@celgene.com")
      )
    )
  )
)))



server <- shinyServer(function(input, output) {
  
  # generate a filtered subtable every time a checkbox is adjusted
  subtable <- reactive({
    data[data$Study %in% input$checkGroupStudy, c(input$checkGroupDemo, input$checkGroupChem, input$checkGroupCyto, input$checkGroupInv)]
  })
  
  # generate the details table from the subtable object
  output$df_main_table <- DT::renderDataTable({subtable()}, filter = "top",
                                              options = list(lengthMenu = c(10, 50, 100), pageLength = 10))
  
  output$dict_table <- DT::renderDataTable(dict, filter = "top",
                                              options = list(lengthMenu = c(10, 50, 100), pageLength = 100))
  
  # generate the summary count table from the subtable object
  output$counts <- renderTable({
    logic_table <- !(is.na(subtable()))
    
    split <- aggregate.data.frame(logic_table, by = list("Study" = subtable()[,"Study"]), sum)
    split$Patient <- NULL
    total <- aggregate.data.frame(logic_table, by = list("Study" = rep(1,nrow(subtable()))), sum)
    total[1,"Study"] <- "Total"
    total$Patient <- NULL
    out <- rbind(split, total)
    n <- names(out)
    n[[2]] <- "n"
    names(out) <- n
    out
  })
  
  output$pivotObject <- rpivotTable::renderRpivotTable({
    rpivotTable::rpivotTable(data =   data, 
                             rows = c("Has.WES", "Has.WGS", "Has.RNA"),
                             cols="Study",
                             vals = "votes", 
                             aggregatorName = "Count", 
                             rendererName = "Table",
                             width="50%", 
                             height="500px")
  })
  
  # download the filtered data
  output$download_handler = downloadHandler('mgp-filtered.csv', content = function(file) {
    s = input$df_main_table_rows_all
    write.csv(subtable()[s, , drop = FALSE], file)
  })
  
  output$help_text <- renderText({ 
    paste("MGP Integrated Dataviewer v0.2 uses data processed on", version)
  })
})

shinyApp(ui = ui, server = server)

