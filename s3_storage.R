s3_is_configured <- function() {
  nzchar(Sys.getenv("MICROBIOME_S3_BUCKET")) &&
    nzchar(Sys.getenv("AWS_REGION")) &&
    requireNamespace("paws.storage", quietly = TRUE)
}

s3_client <- function() {
  paws.storage::s3(config = list(region = Sys.getenv("AWS_REGION")))
}

s3_upload_bundle <- function(bundle, key = NULL) {
  if (!s3_is_configured()) stop("S3 is not configured. Set MICROBIOME_S3_BUCKET and AWS_REGION.")
  if (is.null(key)) key <- paste0("analysis-bundles/bundle-", format(Sys.time(), "%Y%m%d-%H%M%S"), ".rds")
  temp <- tempfile(fileext = ".rds")
  on.exit(unlink(temp), add = TRUE)
  saveRDS(bundle, temp)
  raw <- readBin(temp, what = "raw", n = file.info(temp)$size)
  s3_client()$put_object(Bucket = Sys.getenv("MICROBIOME_S3_BUCKET"), Key = key, Body = raw)
  key
}

s3_list_bundles <- function() {
  if (!s3_is_configured()) return(character())
  response <- s3_client()$list_objects_v2(
    Bucket = Sys.getenv("MICROBIOME_S3_BUCKET"), Prefix = "analysis-bundles/"
  )
  if (is.null(response$Contents)) character() else vapply(response$Contents, `[[`, character(1), "Key")
}
