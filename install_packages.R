cran_packages <- c(
  "shiny", "bslib", "ggplot2", "plotly", "DT", "dplyr", "tidyr", "tibble",
  "vegan", "scales", "paws.storage", "testthat", "remotes"
)

missing_cran <- cran_packages[!vapply(cran_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_cran)) {
  install.packages(missing_cran, repos = "https://cloud.r-project.org", Ncpus = 2)
}

if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager", repos = "https://cloud.r-project.org")
}

bioconductor_packages <- c("phyloseq", "Maaslin2")
missing_bioc <- bioconductor_packages[!vapply(bioconductor_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_bioc)) {
  BiocManager::install(missing_bioc, ask = FALSE, update = FALSE, Ncpus = 2)
}
