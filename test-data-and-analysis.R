source("R/data_io.R")
source("R/analysis.R")

test_that("demonstration tables load as a matched bundle", {
  bundle <- load_demo_bundle(".")
  expect_s3_class(bundle, "microbiome_bundle")
  expect_equal(nrow(bundle$counts), nrow(bundle$metadata))
  expect_true(all(rownames(bundle$counts) == bundle$metadata$SampleID))
  expect_true(all(bundle$counts >= 0))
})

test_that("relative abundance sums to one", {
  bundle <- load_demo_bundle(".")
  rel <- relative_abundance(bundle$counts)
  expect_equal(as.numeric(rowSums(rel)), rep(1, nrow(rel)), tolerance = 1e-10)
})

test_that("alpha diversity is returned for every sample", {
  bundle <- load_demo_bundle(".")
  alpha <- alpha_diversity(bundle)
  expect_equal(nrow(alpha), nrow(bundle$counts))
  expect_true(all(c("Observed", "Shannon", "Simpson") %in% names(alpha)))
})

test_that("Bray-Curtis ordination returns two coordinates", {
  bundle <- load_demo_bundle(".")
  ord <- beta_ordination(bundle)
  expect_true(all(c("PCoA1", "PCoA2") %in% names(ord$points)))
  expect_equal(nrow(ord$points), nrow(bundle$counts))
})
