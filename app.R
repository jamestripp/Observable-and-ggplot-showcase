# app.R

# 1. Load packages
library(shiny)
library(shinydashboard)
library(ggplot2)
library(ggiraph)
library(dplyr)
library(readr)
library(DT)
library(r2d3)
library(scales)

# 2. Retro ggplot2 theme
theme_retro <- function(base_size = 12) {
  theme_minimal() %+replace%#base_family = "Press Start 2P", base_size = base_size) %+replace%
    theme(
      plot.background   = element_rect(fill = "black", color = NA),
      panel.background  = element_rect(fill = "black", color = NA),
      panel.grid.major  = element_line(color = "#ff00ff", size = 0.6),
      panel.grid.minor  = element_line(color = "#ff77ff", linetype = "dotted"),
      axis.text         = element_text(color = "#66fcf1", size = rel(0.8)),
      axis.title        = element_text(color = "#45a29e", size = rel(1)),
      legend.background = element_rect(fill = "black"),
      legend.key        = element_rect(fill = "black"),
      legend.text       = element_text(color = "#c5c6c7"),
      legend.title      = element_text(color = "#45a29e"),
      plot.title        = element_text(color = "#66fcf1", size = rel(1.2),
                                       hjust = 0.5, face = "bold")
    )
}

# 3. Fetch/cache Gapminder data
csv_url <- paste0(
  "https://raw.githubusercontent.com/",
  "resbaz/r-novice-gapminder-files/",
  "master/data/gapminder-FiveYearData.csv"
)
if (!file.exists("gapminder.csv")) {
  download.file(csv_url, "gapminder.csv", mode = "wb")
}
gap <- read_csv("gapminder.csv",
                col_types = cols(
                  country    = col_character(),
                  continent  = col_character(),
                  year       = col_integer(),
                  lifeExp    = col_double(),
                  pop        = col_double(),
                  gdpPercap  = col_double()
                )) %>%
  rename(
    Country      = country,
    Continent    = continent,
    Year         = year,
    LifeExpect   = lifeExp,
    Population   = pop,
    GDP_Per_Cap  = gdpPercap
  )

# 4. UI choices
country_choices <- sort(unique(gap$Country))
year_min  <- min(gap$Year)
year_max  <- max(gap$Year)
axis_choices <- c(
  "Year"            = "Year",
  "Life Expectancy" = "LifeExpect",
  "GDP per Capita"  = "GDP_Per_Cap",
  "Population"      = "Population"
)

# 4. UI
ui <- dashboardPage(
  dashboardHeader(title = "Gapminder + D3"),
  dashboardSidebar(
    tags$head(
      tags$link(rel = "stylesheet", href = "custom.css"),
      tags$link(rel = "stylesheet",
                href = "https://fonts.googleapis.com/css2?family=Press+Start+2P&display=swap")
    ),
    sidebarMenu(
      menuItem("Information", tabName = "info",   icon = icon("info-circle")),
      menuItem("Plot",        tabName = "plot",   icon = icon("chart-line")),
      menuItem("Table",       tabName = "table",  icon = icon("table")),
      menuItem("D3 Plot",     tabName = "d3plot", icon = icon("js"))
    ),
    selectizeInput(
      "countries", "Select Countries:",
      choices  = country_choices,
      selected = c("United States", "China"),
      multiple = TRUE
    ),
    sliderInput(
      "year_range", "Year Range:",
      min = year_min, max = year_max,
      value = c(year_min, year_max), sep = ""
    ),
    selectInput(
      "plot_type", "Plot type:",
      choices = c("Point Plot" = "point", "Bubble Plot" = "bubble"),
      selected = "point"
    ),
    conditionalPanel(
      condition = "input.plot_type == 'bubble'",
      selectInput(
        "sizevar", "Bubble size variable:",
        choices  = axis_choices,
        selected = "Population"
      )
    ),
    selectInput(
      "xvar", "X axis:",
      choices  = axis_choices,
      selected = "GDP_Per_Cap"
    ),
    selectInput(
      "yvar", "Y axis:",
      choices  = axis_choices,
      selected = "LifeExpect"
    )
  ),
  
  dashboardBody(
    tabItems(
      # Information tab
      tabItem(tabName = "info",
              fluidRow(
                box(
                  title = "Welcome to the Gapminder Explorer",
                  width = 12, status = "primary", solidHeader = TRUE,
                  p("Use the controls on the left to filter countries and years,"),
                  p("choose between point or bubble plots, and select your X/Y axes."),
                  p("The Data Table tab shows the raw filtered data,"),
                  p("and the D3 Plot tab renders the same scatter/bubble using D3."),
                  p("This app is built with Shiny, ggiraph and r2d3.")
                )
              )
      ),
      
      # Plot tab
      tabItem(tabName = "plot",
              fluidRow(
                box(
                  girafeOutput("life_plot", height = 450),
                  width = 12, status = "primary", solidHeader = TRUE
                )
              )
      ),
      
      # Table tab
      tabItem(tabName = "table",
              fluidRow(
                box(
                  DTOutput("life_table"),
                  width = 12, status = "info", solidHeader = TRUE
                )
              )
      ),
      
      # D3 Plot tab
      tabItem(tabName = "d3plot",
              fluidRow(
                box(
                  d3Output("d3_scatter", height = "500px"),
                  width = 12, status = "warning", solidHeader = TRUE
                )
              )
      )
    )
  )
)

# 5. Server
server <- function(input, output, session) {
  
  # Filtered data
  filtered <- reactive({
    df <- gap %>%
      filter(Year >= input$year_range[1],
             Year <= input$year_range[2])
    if (length(input$countries) > 0) {
      df <- df %>% filter(Country %in% input$countries)
    }
    df
  })
  
  # Fixed ggiraph scatter/bubble
  output$life_plot <- renderGirafe({
    df_plot <- filtered() %>%
      mutate(
        xval    = .data[[input$xvar]],
        yval    = .data[[input$yvar]],
        sizeval = if (input$plot_type == "bubble")
          .data[[input$sizevar]] else NA_real_,
        tooltip = paste0(
          "Country: ", Country, "\n",
          names(axis_choices)[axis_choices == input$xvar], ": ", round(xval, 1), "\n",
          names(axis_choices)[axis_choices == input$yvar], ": ", round(yval, 1),
          if (input$plot_type == "bubble") {
            paste0("\n", 
                   names(axis_choices)[axis_choices == input$sizevar], 
                   ": ", scales::comma(sizeval))
          } else ""
        )
      )
    
    # Build ggplot object
    p <- ggplot(df_plot, aes(x = xval, y = yval, color = Country))
    
    if (input$plot_type == "bubble") {
      p <- p +
        geom_point_interactive(aes(size = sizeval, tooltip = tooltip), alpha = 0.7) +
        scale_size_continuous(
          name  = names(axis_choices)[axis_choices == input$sizevar],
          range = c(3, 12)
        )
    } else {
      p <- p +
        geom_line_interactive(aes(group = Country), size = 1.2) +
        geom_point_interactive(aes(tooltip = tooltip), size = 4)
    }
    
    # Add labels and theme
    p <- p +
      labs(
        x = names(axis_choices)[axis_choices == input$xvar],
        y = names(axis_choices)[axis_choices == input$yvar]
      ) +
      theme_retro()
    
    # Wrap in girafe()
    girafe(
      ggobj   = p,
      options = list(
        opts_hover(css      = "stroke-width:2;"),
        opts_selection(type = "none")
      )
    )
  })
  
  # Data table
  output$life_table <- renderDT({
    datatable(
      filtered(),
      extensions = "Buttons",
      options = list(
        dom        = "Bfrtip",
        buttons    = c("copy", "csv", "excel", "pdf", "print"),
        pageLength = 10
      )
    )
  })
  
  # D3 scatter/bubble
  output$d3_scatter <- renderD3({
    df <- filtered() %>%
      select(Country, Year, LifeExpect, GDP_Per_Cap, Population)
    
    r2d3(
      data   = df,
      script = "scatter.js",
      width  = 700,
      height = 500,
      options = list(
        margin   = list(top = 20, right = 20, bottom = 40, left = 50),
        plotType = input$plot_type,
        xvar     = input$xvar,
        yvar     = input$yvar,
        sizevar  = input$sizevar
      )
    )
  })
}

# 6. Run the App
shinyApp(ui, server)
