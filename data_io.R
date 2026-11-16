clean_id <- function(x) {
  trimws(as.character(x))
}

read_table_auto <- function(path, original_name = path) {
  ext <- tolower(tools::file_ext(original_name))
  if (ext %in% c("tsv", "txt")) {
    out <- utils::read.delim(path, check.names = FALSE, stringsAsFactors = FALSE)
  } else {
    out <- utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  }
  as.data.frame(out, check.names = FALSE)
}

find_id_column <- function(df, candidates) {
  matched <- names(df)[tolower(names(df)) %in% tolower(candidates)]
  if (length(matched)) matched[[1]] else names(df)[[1]]
}

prepare_metadata <- function(metadata) {
  if (!nrow(metadata) || ncol(metadata) < 2) {
    stop("Metadata must contain sample IDs and at least one explanatory variable.")
  }
  id_col <- find_id_column(metadata, c("SampleID", "Sample_ID", "sample", "sampleid"))
  names(metadata)[names(metadata) == id_col] <- "SampleID"
  metadata$SampleID <- clean_id(metadata$SampleID)
  if (any(!nzchar(metadata$SampleID))) stop("Metadata contains empty sample IDs.")
  if (anyDuplicated(metadata$SampleID)) stop("Metadata sample IDs must be unique.")
  rownames(metadata) <- metadata$SampleID
  metadata
}

numeric_matrix <- function(df) {
  converted <- lapply(df, function(x) suppressWarnings(as.numeric(as.character(x))))
  out <- as.matrix(as.data.frame(converted, check.names = FALSE))
  colnames(out) <- names(df)
  out
}

orient_abundance_table <- function(abundance, metadata) {
  sample_ids <- metadata$SampleID
  first_col <- names(abundance)[[1]]
  row_ids <- clean_id(abundance[[first_col]])
  row_overlap <- sum(row_ids %in% sample_ids)
  column_overlap <- sum(names(abundance)[-1] %in% sample_ids)

  if (row_overlap == 0 && column_overlap == 0) {
    stop("No sample IDs match between the abundance table and metadata. Check spelling and orientation.")
  }

  if (row_overlap >= column_overlap) {
    values <- numeric_matrix(abundance[-1])
    rownames(values) <- row_ids
    counts <- values
  } else {
    values <- numeric_matrix(abundance[-1])
    rownames(values) <- row_ids
    counts <- t(values)
  }

  if (anyNA(counts)) stop("The abundance table contains missing or non-numeric abundance values.")
  if (any(counts < 0)) stop("The abundance table contains negative values.")
  if (anyDuplicated(rownames(counts))) stop("Sample IDs in the abundance table must be unique.")
  if (anyDuplicated(colnames(counts))) stop("Feature or taxon names in the abundance table must be unique.")

  shared <- metadata$SampleID[metadata$SampleID %in% rownames(counts)]
  if (length(shared) < 3) stop("At least three matched samples are required.")
  counts <- counts[shared, , drop = FALSE]
  metadata <- metadata[shared, , drop = FALSE]

  zero_samples <- rowSums(counts) == 0
  if (any(zero_samples)) {
    counts <- counts[!zero_samples, , drop = FALSE]
    metadata <- metadata[!zero_samples, , drop = FALSE]
  }
  zero_features <- colSums(counts) == 0
  counts <- counts[, !zero_features, drop = FALSE]

  list(counts = counts, metadata = metadata,
       notes = c(
         sprintf("Matched %d samples.", nrow(counts)),
         sprintf("Retained %d non-zero features.", ncol(counts)),
         if (any(zero_samples)) sprintf("Removed %d zero-depth samples.", sum(zero_samples)) else NULL,
         if (any(zero_features)) sprintf("Removed %d all-zero features.", sum(zero_features)) else NULL
       ))
}

prepare_taxonomy <- function(taxonomy, feature_ids) {
  if (is.null(taxonomy)) return(NULL)
  id_col <- find_id_column(taxonomy, c("FeatureID", "Feature_ID", "ASV", "OTU", "Taxon"))
  feature <- clean_id(taxonomy[[id_col]])
  taxonomy[[id_col]] <- NULL
  rownames(taxonomy) <- feature
  taxonomy <- taxonomy[!duplicated(rownames(taxonomy)), , drop = FALSE]
  missing <- setdiff(feature_ids, rownames(taxonomy))
  if (length(missing)) {
    blank <- as.data.frame(matrix(NA_character_, nrow = length(missing), ncol = ncol(taxonomy)))
    names(blank) <- names(taxonomy)
    rownames(blank) <- missing
    taxonomy <- rbind(taxonomy, blank)
  }
  taxonomy[feature_ids, , drop = FALSE]
}

bundle_from_tables <- function(abundance_path, metadata_path, taxonomy_path = NULL,
                               abundance_name = abundance_path,
                               metadata_name = metadata_path,
                               taxonomy_name = taxonomy_path) {
  metadata <- prepare_metadata(read_table_auto(metadata_path, metadata_name))
  abundance <- read_table_auto(abundance_path, abundance_name)
  oriented <- orient_abundance_table(abundance, metadata)
  taxonomy <- if (!is.null(taxonomy_path)) {
    prepare_taxonomy(read_table_auto(taxonomy_path, taxonomy_name), colnames(oriented$counts))
  } else NULL

  structure(list(
    counts = oriented$counts,
    metadata = oriented$metadata,
    taxonomy = taxonomy,
    source = "Uploaded tables",
    notes = oriented$notes
  ), class = "microbiome_bundle")
}

bundle_from_phyloseq <- function(path) {
  if (!requireNamespace("phyloseq", quietly = TRUE)) {
    stop("The phyloseq package is required to read a phyloseq RDS file.")
  }
  object <- readRDS(path)
  if (inherits(object, "microbiome_bundle")) return(object)
  if (!inherits(object, "phyloseq") && is.list(object)) {
    candidates <- object[vapply(object, inherits, logical(1), what = "phyloseq")]
    if (length(candidates) == 1) object <- candidates[[1]]
    if (length(candidates) > 1) {
      stop("The RDS file contains multiple phyloseq objects. Save the intended object alone with saveRDS().")
    }
  }
  if (!inherits(object, "phyloseq")) {
    stop("The uploaded RDS file is not a phyloseq object and does not contain exactly one phyloseq object.")
  }

  counts <- as(phyloseq::otu_table(object), "matrix")
  if (phyloseq::taxa_are_rows(object)) counts <- t(counts)
  metadata <- as.data.frame(phyloseq::sample_data(object), stringsAsFactors = FALSE)
  metadata$SampleID <- rownames(metadata)
  metadata <- metadata[, c("SampleID", setdiff(names(metadata), "SampleID")), drop = FALSE]
  taxonomy <- if (!is.null(phyloseq::tax_table(object, errorIfNULL = FALSE))) {
    as.data.frame(as(phyloseq::tax_table(object), "matrix"), stringsAsFactors = FALSE)
  } else NULL

  metadata <- prepare_metadata(metadata)
  counts <- counts[metadata$SampleID, , drop = FALSE]
  structure(list(
    counts = counts,
    metadata = metadata,
    taxonomy = taxonomy,
    source = "Uploaded phyloseq object",
    notes = c(sprintf("Loaded %d samples.", nrow(counts)),
              sprintf("Loaded %d features.", ncol(counts)))
  ), class = "microbiome_bundle")
}

load_demo_bundle <- function(root = ".") {
  bundle <- bundle_from_tables(
    file.path(root, "data", "demo", "abundance_table.csv"),
    file.path(root, "data", "demo", "metadata.csv"),
    file.path(root, "data", "demo", "taxonomy.csv")
  )
  bundle$source <- "Included demonstration dataset"
  bundle
}

bundle_summary <- function(bundle) {
  data.frame(
    Metric = c("Source", "Samples", "Features", "Total reads", "Metadata variables"),
    Value = c(bundle$source, nrow(bundle$counts), ncol(bundle$counts),
              format(sum(bundle$counts), big.mark = ","), ncol(bundle$metadata) - 1),
    check.names = FALSE
  )
}
