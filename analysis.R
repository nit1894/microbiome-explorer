filter_counts <- function(counts, min_prevalence = 0.05, min_total = 1) {
  keep <- colMeans(counts > 0) >= min_prevalence & colSums(counts) >= min_total
  if (!any(keep)) stop("Filtering removed every feature. Reduce the filtering thresholds.")
  counts[, keep, drop = FALSE]
}

relative_abundance <- function(counts) {
  totals <- rowSums(counts)
  if (any(totals == 0)) stop("Relative abundance cannot be calculated for zero-depth samples.")
  sweep(counts, 1, totals, "/")
}

aggregate_taxa <- function(counts, taxonomy = NULL, rank = "Feature") {
  if (identical(rank, "Feature") || is.null(taxonomy) || !rank %in% names(taxonomy)) return(counts)
  labels <- as.character(taxonomy[colnames(counts), rank])
  labels[is.na(labels) | !nzchar(labels)] <- "Unclassified"
  t(rowsum(t(counts), group = labels, reorder = FALSE))
}

composition_data <- function(bundle, rank = "Feature", top_n = 12,
                             min_prevalence = 0.05) {
  counts <- filter_counts(bundle$counts, min_prevalence = min_prevalence)
  counts <- aggregate_taxa(counts, bundle$taxonomy, rank)
  rel <- relative_abundance(counts)
  totals <- sort(colSums(rel), decreasing = TRUE)
  top <- names(totals)[seq_len(min(top_n, length(totals)))]
  other <- rowSums(rel[, setdiff(colnames(rel), top), drop = FALSE])
  display <- rel[, top, drop = FALSE]
  if (any(other > 0)) display <- cbind(display, Other = other)

  long <- as.data.frame(display, check.names = FALSE)
  long$SampleID <- rownames(long)
  long <- tidyr::pivot_longer(long, -SampleID, names_to = "Taxon", values_to = "RelativeAbundance")
  dplyr::left_join(long, bundle$metadata, by = "SampleID")
}

alpha_diversity <- function(bundle) {
  counts <- bundle$counts
  out <- data.frame(
    SampleID = rownames(counts),
    Observed = rowSums(counts > 0),
    Shannon = vegan::diversity(counts, index = "shannon"),
    Simpson = vegan::diversity(counts, index = "simpson"),
    check.names = FALSE
  )
  dplyr::left_join(out, bundle$metadata, by = "SampleID")
}

beta_ordination <- function(bundle, min_prevalence = 0.05) {
  counts <- filter_counts(bundle$counts, min_prevalence = min_prevalence)
  rel <- relative_abundance(counts)
  distance <- vegan::vegdist(rel, method = "bray")
  fit <- stats::cmdscale(distance, eig = TRUE, k = 2)
  points <- as.data.frame(fit$points)
  names(points) <- c("PCoA1", "PCoA2")
  points$SampleID <- rownames(points)
  positive <- fit$eig[fit$eig > 0]
  variance <- if (length(positive)) 100 * positive[1:2] / sum(positive) else c(NA_real_, NA_real_)
  list(
    points = dplyr::left_join(points, bundle$metadata, by = "SampleID"),
    distance = distance,
    variance = variance
  )
}

permanova_result <- function(ordination, metadata, variable) {
  if (is.null(variable) || !nzchar(variable)) return(NULL)
  dat <- data.frame(group = metadata[[variable]], row.names = metadata$SampleID)
  dat <- dat[attr(ordination$distance, "Labels"), , drop = FALSE]
  fit <- vegan::adonis2(ordination$distance ~ group, data = dat, permutations = 999)
  data.frame(
    Variable = variable,
    R2 = round(fit$R2[[1]], 4),
    F = round(fit$F[[1]], 4),
    P = fit$`Pr(>F)`[[1]],
    Permutations = 999,
    check.names = FALSE
  )
}

run_maaslin2 <- function(bundle, fixed_effects, random_effects = NULL,
                         min_prevalence = 0.05, output_dir = tempfile("maaslin2-"),
                         reference_levels = NULL) {
  if (!requireNamespace("Maaslin2", quietly = TRUE)) {
    stop("Maaslin2 is not installed. Run install_packages.R or rebuild the Docker image.")
  }
  if (!length(fixed_effects)) stop("Select at least one fixed effect.")
  counts <- filter_counts(bundle$counts, min_prevalence = min_prevalence)
  metadata <- bundle$metadata
  rownames(metadata) <- metadata$SampleID
  metadata$SampleID <- NULL

  missing_effects <- setdiff(fixed_effects, names(metadata))
  if (length(missing_effects)) {
    stop("Fixed effect(s) not found in metadata: ", paste(missing_effects, collapse = ", "))
  }

  # Optional explicit references for uploaded datasets, e.g.:
  # reference_levels = c(Host_Species = "Drosophila_species_1")
  # Callers of the original four/five-argument function still work unchanged.
  if (!is.null(reference_levels)) {
    if (!is.character(reference_levels) || is.null(names(reference_levels)) ||
        any(is.na(names(reference_levels)) | !nzchar(names(reference_levels)))) {
      stop("reference_levels must be a named character vector, e.g. c(Group = 'Control').")
    }
    unknown_refs <- setdiff(names(reference_levels), fixed_effects)
    if (length(unknown_refs)) {
      stop("Reference specified for a variable not selected as a fixed effect: ",
           paste(unknown_refs, collapse = ", "))
    }
  }

  # MaAsLin2 requires an explicit reference for character/factor fixed
  # effects with more than two observed categories.
  reference_settings <- character()
  for (variable in fixed_effects) {
    values <- metadata[[variable]]
    if (!(is.character(values) || is.factor(values))) next

    observed_levels <- sort(unique(as.character(values[!is.na(values)])))
    observed_levels <- observed_levels[nzchar(observed_levels)]

    requested <- if (!is.null(reference_levels) && variable %in% names(reference_levels)) {
      unname(reference_levels[[variable]])
    } else {
      NULL
    }

    if (length(observed_levels) > 2L || !is.null(requested)) {
      # Use species 1 for the supplied demonstration dataset. Otherwise the
      # first alphabetically sorted observed level is a reproducible default.
      ref <- if (!is.null(requested)) {
        requested
      } else if (identical(variable, "Host_Species") &&
                 "Drosophila_species_1" %in% observed_levels) {
        "Drosophila_species_1"
      } else {
        observed_levels[[1]]
      }
      if (length(ref) != 1L || is.na(ref) || !(ref %in% observed_levels)) {
        stop("Invalid reference for ", variable, ". Choose an observed metadata level.")
      }
      if (grepl("[,;]", variable) || grepl("[,;]", ref)) {
        stop("Reference names and values cannot contain commas or semicolons in MaAsLin2.")
      }
      reference_settings <- c(reference_settings, paste(variable, ref, sep = ","))
    }
  }

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  args <- list(
    input_data = as.data.frame(counts, check.names = FALSE),
    input_metadata = metadata,
    output = output_dir,
    fixed_effects = fixed_effects,
    normalization = "TSS",
    transform = "LOG",
    correction = "BH",
    standardize = FALSE,
    plot_heatmap = TRUE,
    plot_scatter = FALSE
  )
  if (!is.null(random_effects) && nzchar(random_effects)) args$random_effects <- random_effects
  if (length(reference_settings)) {
    args$reference <- paste(reference_settings, collapse = ";")
    message("MaAsLin2 reference category/categories: ", args$reference)
  }

  do.call(Maaslin2::Maaslin2, args)
  result_path <- file.path(output_dir, "all_results.tsv")
  if (!file.exists(result_path)) stop("MaAsLin2 completed without producing all_results.tsv.")
  list(
    results = utils::read.delim(result_path, check.names = FALSE),
    output_dir = output_dir,
    references = reference_settings
  )
}
