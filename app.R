options(shiny.maxRequestSize = 100 * 1024^2)

required_packages <- c("shiny", "bslib", "ggplot2", "plotly", "DT", "dplyr",
                       "tidyr", "tibble", "vegan", "scales")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages)) {
  stop("Install required packages first: ", paste(missing_packages, collapse = ", "))
}

app_root <- normalizePath(".", mustWork = TRUE)
# Load supporting scripts from the same folder as app.R
source(file.path(app_root, "data_io.R"), local = TRUE)
source(file.path(app_root, "analysis.R"), local = TRUE)
source(file.path(app_root, "plots.R"), local = TRUE)
source(file.path(app_root, "s3_storage.R"), local = TRUE)

# Shiny serves static files from the www/ folder.
# Copy the existing stylesheet there so the dashboard displays its design.
if (file.exists(file.path(app_root, "styles.css"))) {
  dir.create(file.path(app_root, "www"), showWarnings = FALSE)
  file.copy(
    file.path(app_root, "styles.css"),
    file.path(app_root, "www", "styles.css"),
    overwrite = TRUE
  )
}

theme <- bslib::bs_theme(
  version = 5,
  bg = "#f5f7f5",
  fg = "#18352f",
  primary = "#157a6e",
  secondary = "#d98e04",
  base_font = bslib::font_google("Inter"),
  heading_font = bslib::font_google("DM Sans")
)

upload_help <- shiny::tags$div(
  class = "upload-help",
  shiny::tags$strong("Accepted inputs"),
  shiny::tags$ul(
    shiny::tags$li("One trusted phyloseq .rds object; or"),
    shiny::tags$li("An abundance CSV/TSV plus metadata CSV/TSV, with an optional taxonomy table.")
  ),
  shiny::tags$p("The application detects whether samples occupy rows or columns by matching metadata IDs.")
)

ui <- shiny::navbarPage(
  title = shiny::tagList(shiny::span(class = "brand-mark", "ME"), "Microbiome Explorer"),
  id = "main_nav",
  theme = theme,
  header = shiny::tags$head(
    shiny::tags$link(rel = "stylesheet", type = "text/css", href = "styles.css")
  ),

  shiny::tabPanel(
    "Overview",
    shiny::div(
      class = "hero",
      shiny::div(
        class = "hero-copy",
        shiny::tags$p(class = "eyebrow", "REPRODUCIBLE MICROBIOME ANALYTICS"),
        shiny::tags$h1("Move from community counts to defensible biological insight."),
        shiny::tags$p(class = "lead",
                      "Validate sample structure, explore community composition, quantify diversity, and test multivariable associations in one documented workflow."),
        shiny::actionButton("open_data", "Start with your data", class = "btn-primary btn-lg")
      ),
      shiny::div(class = "hero-panel", shiny::uiOutput("overview_cards"))
    ),
    shiny::fluidRow(
      shiny::column(4, shiny::div(class = "feature-card", shiny::tags$h3("Validate first"),
                                 shiny::tags$p("Detect mismatched IDs, zero-depth samples, duplicate identifiers and non-numeric abundances before analysis."))),
      shiny::column(4, shiny::div(class = "feature-card", shiny::tags$h3("Model the design"),
                                 shiny::tags$p("Use Bray–Curtis ordination, PERMANOVA and MaAsLin2 while retaining experimental metadata and repeated-measure structure."))),
      shiny::column(4, shiny::div(class = "feature-card", shiny::tags$h3("Reproduce the result"),
                                 shiny::tags$p("Download the cleaned analysis object and results, then run the same application locally or in its Docker container.")))
    )
  ),

  shiny::tabPanel(
    "Data & QC",
    shiny::sidebarLayout(
      shiny::sidebarPanel(
        width = 4,
        shiny::radioButtons("data_mode", "Data source",
                            choices = c("Included demonstration data" = "demo",
                                        "Phyloseq RDS" = "phyloseq",
                                        "CSV/TSV tables" = "tables"),
                            selected = "demo"),
        shiny::conditionalPanel(
          "input.data_mode == 'phyloseq'",
          shiny::fileInput("phyloseq_file", "Trusted phyloseq object", accept = ".rds")
        ),
        shiny::conditionalPanel(
          "input.data_mode == 'tables'",
          shiny::fileInput("abundance_file", "Abundance table", accept = c(".csv", ".tsv", ".txt")),
          shiny::fileInput("metadata_file", "Sample metadata", accept = c(".csv", ".tsv", ".txt")),
          shiny::fileInput("taxonomy_file", "Taxonomy table (optional)", accept = c(".csv", ".tsv", ".txt"))
        ),
        shiny::actionButton("load_data", "Load and validate", class = "btn-primary", width = "100%"),
        shiny::br(), shiny::br(), upload_help,
        shiny::downloadButton("download_bundle", "Download cleaned bundle", class = "btn-outline-primary")
      ),
      shiny::mainPanel(
        width = 8,
        shiny::div(class = "section-heading", shiny::tags$p(class = "eyebrow", "INPUT CHECK"), shiny::tags$h2("Data summary")),
        DT::DTOutput("bundle_summary"),
        shiny::tags$h3("Validation report"),
        shiny::uiOutput("validation_report"),
        shiny::tags$h3("Sample metadata preview"),
        DT::DTOutput("metadata_preview")
      )
    )
  ),

  shiny::tabPanel(
    "Composition",
    shiny::sidebarLayout(
      shiny::sidebarPanel(
        width = 3,
        shiny::selectInput("composition_group", "Facet samples by", choices = NULL),
        shiny::selectInput("taxonomy_rank", "Taxonomic rank", choices = "Feature"),
        shiny::sliderInput("top_taxa", "Number of dominant taxa", min = 5, max = 25, value = 12),
        shiny::sliderInput("composition_prevalence", "Minimum prevalence", min = 0, max = 0.5, value = 0.05, step = 0.01)
      ),
      shiny::mainPanel(
        width = 9,
        shiny::div(class = "section-heading", shiny::tags$p(class = "eyebrow", "COMMUNITY STRUCTURE"),
                   shiny::tags$h2("Taxonomic composition"),
                   shiny::tags$p("Counts are converted to within-sample relative abundance after prevalence filtering.")),
        plotly::plotlyOutput("composition_plot", height = "580px")
      )
    )
  ),

  shiny::tabPanel(
    "Alpha diversity",
    shiny::sidebarLayout(
      shiny::sidebarPanel(
        width = 3,
        shiny::selectInput("alpha_metric", "Diversity metric",
                           choices = c("Observed features" = "Observed", "Shannon" = "Shannon", "Simpson" = "Simpson")),
        shiny::selectInput("alpha_group", "Compare groups by", choices = NULL)
      ),
      shiny::mainPanel(
        width = 9,
        shiny::div(class = "section-heading", shiny::tags$p(class = "eyebrow", "WITHIN-SAMPLE DIVERSITY"),
                   shiny::tags$h2("Alpha diversity"),
                   shiny::tags$p("These exploratory summaries are not automatically interpreted as formal tests.")),
        plotly::plotlyOutput("alpha_plot", height = "560px"),
        DT::DTOutput("alpha_table")
      )
    )
  ),

  shiny::tabPanel(
    "Beta diversity",
    shiny::sidebarLayout(
      shiny::sidebarPanel(
        width = 3,
        shiny::selectInput("pcoa_color", "Color by", choices = NULL),
        shiny::selectInput("pcoa_shape", "Shape by", choices = NULL),
        shiny::selectInput("permanova_variable", "PERMANOVA variable", choices = NULL),
        shiny::sliderInput("beta_prevalence", "Minimum prevalence", min = 0, max = 0.5, value = 0.05, step = 0.01)
      ),
      shiny::mainPanel(
        width = 9,
        shiny::div(class = "section-heading", shiny::tags$p(class = "eyebrow", "BETWEEN-SAMPLE DISSIMILARITY"),
                   shiny::tags$h2("Bray–Curtis PCoA"),
                   shiny::tags$p("PERMANOVA is reported with 999 permutations. Confirm dispersion assumptions before inferential interpretation.")),
        plotly::plotlyOutput("pcoa_plot", height = "540px"),
        DT::DTOutput("permanova_table")
      )
    )
  ),

  shiny::tabPanel(
    "Associations",
    shiny::sidebarLayout(
      shiny::sidebarPanel(
        width = 3,
        shiny::selectizeInput("maaslin_fixed", "Fixed effects", choices = NULL, multiple = TRUE),
        shiny::selectInput("maaslin_random", "Random effect (optional)", choices = NULL),
        shiny::sliderInput("maaslin_prevalence", "Minimum prevalence", min = 0, max = 0.5, value = 0.1, step = 0.01),
        shiny::actionButton("run_maaslin", "Run MaAsLin2", class = "btn-primary", width = "100%"),
        shiny::br(), shiny::br(),
        shiny::downloadButton("download_maaslin", "Download results", class = "btn-outline-primary")
      ),
      shiny::mainPanel(
        width = 9,
        shiny::div(class = "section-heading", shiny::tags$p(class = "eyebrow", "MULTIVARIABLE ASSOCIATIONS"),
                   shiny::tags$h2("MaAsLin2 results"),
                   shiny::tags$p("The default workflow applies TSS normalization, log transformation and Benjamini–Hochberg correction.")),
        shiny::uiOutput("maaslin_status"),
        DT::DTOutput("maaslin_table")
      )
    )
  ),

  shiny::tabPanel(
    "Cloud",
    shiny::fluidRow(
      shiny::column(
        7,
        shiny::div(class = "section-heading", shiny::tags$p(class = "eyebrow", "REPRODUCIBLE STORAGE"),
                   shiny::tags$h2("AWS S3 analysis bundles")),
        shiny::uiOutput("s3_status"),
        shiny::actionButton("upload_s3", "Save current bundle to S3", class = "btn-primary"),
        shiny::br(), shiny::br(),
        DT::DTOutput("s3_objects")
      ),
      shiny::column(
        5,
        shiny::div(class = "method-card",
                   shiny::tags$h3("Deployment architecture"),
                   shiny::tags$ol(
                     shiny::tags$li("GitHub builds the Docker image."),
                     shiny::tags$li("Amazon ECR stores the versioned image."),
                     shiny::tags$li("Amazon ECS Fargate runs the application."),
                     shiny::tags$li("The ECS task role grants limited access to one S3 bucket.")
                   ),
                   shiny::tags$p("Credentials are supplied by the runtime role and are never stored in this repository."))
      )
    )
  ),

  shiny::tabPanel(
    "Methods",
    shiny::div(
      class = "methods-grid",
      shiny::div(class = "method-card", shiny::tags$h3("Data model"),
                 shiny::tags$p("Samples are matched by explicit identifiers. Feature counts remain unrarefied for storage; each analysis applies its documented transformation.")),
      shiny::div(class = "method-card", shiny::tags$h3("Composition"),
                 shiny::tags$p("Taxa are filtered by prevalence, optionally aggregated by taxonomy, and converted to sample-wise relative abundance for visualization.")),
      shiny::div(class = "method-card", shiny::tags$h3("Alpha diversity"),
                 shiny::tags$p("Observed richness, Shannon entropy and Simpson diversity summarize within-sample community diversity.")),
      shiny::div(class = "method-card", shiny::tags$h3("Beta diversity"),
                 shiny::tags$p("Bray–Curtis dissimilarity is calculated on relative abundances and represented using principal coordinates analysis.")),
      shiny::div(class = "method-card", shiny::tags$h3("Association models"),
                 shiny::tags$p("MaAsLin2 estimates multivariable feature–metadata associations. Users must specify biologically justified fixed and random effects.")),
      shiny::div(class = "method-card", shiny::tags$h3("Interpretive limits"),
                 shiny::tags$p("Exploratory visual separation does not establish causality. Study design, dispersion, sequencing depth, compositionality and repeated measures require explicit consideration."))
    )
  )
)

server <- function(input, output, session) {
  current_bundle <- shiny::reactiveVal(load_demo_bundle(app_root))
  maaslin_output <- shiny::reactiveVal(NULL)

  shiny::observeEvent(input$open_data, {
    shiny::updateNavbarPage(session, "main_nav", selected = "Data & QC")
  })

  shiny::observeEvent(input$load_data, {
    result <- tryCatch({
      if (identical(input$data_mode, "demo")) {
        load_demo_bundle(app_root)
      } else if (identical(input$data_mode, "phyloseq")) {
        shiny::req(input$phyloseq_file)
        bundle_from_phyloseq(input$phyloseq_file$datapath)
      } else {
        shiny::req(input$abundance_file, input$metadata_file)
        bundle_from_tables(
          input$abundance_file$datapath,
          input$metadata_file$datapath,
          if (!is.null(input$taxonomy_file)) input$taxonomy_file$datapath else NULL,
          input$abundance_file$name,
          input$metadata_file$name,
          if (!is.null(input$taxonomy_file)) input$taxonomy_file$name else NULL
        )
      }
    }, error = function(e) e)

    if (inherits(result, "error")) {
      shiny::showNotification(conditionMessage(result), type = "error", duration = NULL)
    } else {
      current_bundle(result)
      maaslin_output(NULL)
      shiny::showNotification("Dataset loaded and validated.", type = "message")
    }
  }, ignoreInit = TRUE)

  shiny::observe({
    bundle <- current_bundle()
    metadata_variables <- setdiff(names(bundle$metadata), "SampleID")
    rank_choices <- c("Feature", if (!is.null(bundle$taxonomy)) names(bundle$taxonomy) else character())
    group_choices <- c("SampleID", metadata_variables)
    shiny::updateSelectInput(session, "composition_group", choices = group_choices,
                             selected = metadata_variables[[1]] %||% "SampleID")
    shiny::updateSelectInput(session, "taxonomy_rank", choices = rank_choices,
                             selected = if ("Genus" %in% rank_choices) "Genus" else "Feature")
    shiny::updateSelectInput(session, "alpha_group", choices = group_choices,
                             selected = metadata_variables[[1]] %||% "SampleID")
    shiny::updateSelectInput(session, "pcoa_color", choices = group_choices,
                             selected = metadata_variables[[1]] %||% "SampleID")
    shiny::updateSelectInput(session, "pcoa_shape", choices = c("None" = "", group_choices), selected = "")
    shiny::updateSelectInput(session, "permanova_variable", choices = metadata_variables,
                             selected = metadata_variables[[1]] %||% "")
    shiny::updateSelectizeInput(session, "maaslin_fixed", choices = metadata_variables,
                                selected = metadata_variables[[1]] %||% character(), server = TRUE)
    shiny::updateSelectInput(session, "maaslin_random", choices = c("None" = "", metadata_variables), selected = "")
  })

  output$overview_cards <- shiny::renderUI({
    bundle <- current_bundle()
    shiny::tagList(
      shiny::div(class = "metric", shiny::tags$span("Samples"), shiny::tags$strong(nrow(bundle$counts))),
      shiny::div(class = "metric", shiny::tags$span("Features"), shiny::tags$strong(ncol(bundle$counts))),
      shiny::div(class = "metric", shiny::tags$span("Reads"), shiny::tags$strong(format(sum(bundle$counts), big.mark = ","))),
      shiny::tags$p(class = "metric-caption", bundle$source)
    )
  })

  output$bundle_summary <- DT::renderDT({
    DT::datatable(bundle_summary(current_bundle()), rownames = FALSE,
                  options = list(dom = "t", ordering = FALSE), class = "stripe")
  })

  output$validation_report <- shiny::renderUI({
    notes <- current_bundle()$notes
    shiny::tags$ul(class = "validation-list", lapply(notes, function(note) shiny::tags$li(note)))
  })

  output$metadata_preview <- DT::renderDT({
    DT::datatable(utils::head(current_bundle()$metadata, 20), rownames = FALSE,
                  options = list(scrollX = TRUE, pageLength = 8))
  })

  output$composition_plot <- plotly::renderPlotly({
    bundle <- current_bundle()
    data <- composition_data(bundle, input$taxonomy_rank, input$top_taxa, input$composition_prevalence)
    plotly::ggplotly(composition_plot(data, input$composition_group), tooltip = "text")
  })

  alpha_data <- shiny::reactive(alpha_diversity(current_bundle()))
  output$alpha_plot <- plotly::renderPlotly({
    plotly::ggplotly(alpha_plot(alpha_data(), input$alpha_metric, input$alpha_group), tooltip = "text")
  })
  output$alpha_table <- DT::renderDT({
    DT::datatable(alpha_data(), rownames = FALSE, options = list(scrollX = TRUE, pageLength = 8))
  })

  ordination <- shiny::reactive(beta_ordination(current_bundle(), input$beta_prevalence))
  output$pcoa_plot <- plotly::renderPlotly({
    shape <- if (nzchar(input$pcoa_shape %||% "")) input$pcoa_shape else NULL
    plotly::ggplotly(pcoa_plot(ordination(), input$pcoa_color, shape), tooltip = "text")
  })
  output$permanova_table <- DT::renderDT({
    result <- permanova_result(ordination(), current_bundle()$metadata, input$permanova_variable)
    DT::datatable(result, rownames = FALSE, options = list(dom = "t", ordering = FALSE))
  })

  shiny::observeEvent(input$run_maaslin, {
    result <- tryCatch({
      shiny::withProgress(message = "Running MaAsLin2", value = 0.25, {
        out <- run_maaslin2(current_bundle(), input$maaslin_fixed,
                            input$maaslin_random, input$maaslin_prevalence)
        shiny::incProgress(0.75)
        out
      })
    }, error = function(e) e)
    if (inherits(result, "error")) {
      maaslin_output(NULL)
      shiny::showNotification(conditionMessage(result), type = "error", duration = NULL)
    } else {
      maaslin_output(result)
      shiny::showNotification("MaAsLin2 analysis completed.", type = "message")
    }
  })

  output$maaslin_status <- shiny::renderUI({
    if (is.null(maaslin_output())) {
      shiny::div(class = "empty-state", shiny::tags$h3("Ready for a model"),
                 shiny::tags$p("Select biologically justified effects, then run MaAsLin2."))
    } else {
      significant <- sum(maaslin_output()$results$qval < 0.05, na.rm = TRUE)
      shiny::div(class = "success-state", sprintf("Analysis complete: %d associations have q < 0.05.", significant))
    }
  })

  output$maaslin_table <- DT::renderDT({
    shiny::req(maaslin_output())
    results <- maaslin_output()$results
    results <- results[order(results$qval, results$pval), , drop = FALSE]
    DT::datatable(results, rownames = FALSE, filter = "top",
                  options = list(scrollX = TRUE, pageLength = 12))
  })

  output$download_maaslin <- shiny::downloadHandler(
    filename = function() paste0("maaslin2-results-", Sys.Date(), ".csv"),
    content = function(file) {
      shiny::req(maaslin_output())
      utils::write.csv(maaslin_output()$results, file, row.names = FALSE)
    }
  )

  output$download_bundle <- shiny::downloadHandler(
    filename = function() paste0("microbiome-bundle-", Sys.Date(), ".rds"),
    content = function(file) saveRDS(current_bundle(), file)
  )

  output$s3_status <- shiny::renderUI({
    if (s3_is_configured()) {
      shiny::div(class = "success-state",
                 paste("Connected to bucket", Sys.getenv("MICROBIOME_S3_BUCKET"),
                       "in", Sys.getenv("AWS_REGION")))
    } else {
      shiny::div(class = "empty-state", shiny::tags$h3("Local mode"),
                 shiny::tags$p("Set MICROBIOME_S3_BUCKET and AWS_REGION to enable S3. On ECS, access is supplied by the task role."))
    }
  })

  shiny::observeEvent(input$upload_s3, {
    result <- tryCatch(s3_upload_bundle(current_bundle()), error = function(e) e)
    if (inherits(result, "error")) {
      shiny::showNotification(conditionMessage(result), type = "error", duration = NULL)
    } else {
      shiny::showNotification(paste("Uploaded", result), type = "message")
    }
  })

  output$s3_objects <- DT::renderDT({
    input$upload_s3
    keys <- s3_list_bundles()
    DT::datatable(data.frame(S3_Key = keys), rownames = FALSE, options = list(dom = "t", pageLength = 10))
  })
}

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

shiny::shinyApp(ui, server)
