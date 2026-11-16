# Data input guide

Microbiome Explorer begins with processed feature counts and sample metadata. Raw FASTQ files should first be processed with an appropriate workflow such as DADA2, QIIME 2, or another validated pipeline.

## Option 1: phyloseq RDS

Save a complete phyloseq object:

```r
saveRDS(phyloseq_object, "my_microbiome_data.rds")
```

Upload that file under **Data & QC → Phyloseq RDS**. Only upload RDS files that you created or trust.

The object may store taxa as rows or columns; the application converts the OTU table to samples × features internally. Sample metadata and a taxonomy table are imported when present.

## Option 2: CSV or TSV tables

### Abundance table with samples in rows

The first column contains sample IDs. Remaining columns contain non-negative numeric counts.

```csv
SampleID,ASV001,ASV002,ASV003
Sample_01,120,40,0
Sample_02,90,65,3
```

### Abundance table with samples in columns

Transposed tables are also accepted. The first column contains feature IDs and the remaining column names are sample IDs.

```csv
FeatureID,Sample_01,Sample_02
ASV001,120,90
ASV002,40,65
ASV003,0,3
```

### Metadata table

One row per sample. The sample-ID column may be named `SampleID`, `Sample_ID`, `sample`, or `sampleid`. Every other column becomes an available grouping or model variable.

```csv
SampleID,Host_Species,Treatment,Sex,Replicate
Sample_01,D_melanogaster,Control,Female,1
Sample_02,D_melanogaster,Ethanol,Female,1
```

### Optional taxonomy table

The first column identifies features. Remaining columns are taxonomic ranks.

```csv
FeatureID,Kingdom,Phylum,Family,Genus
ASV001,Bacteria,Bacillota,Lactobacillaceae,Lactiplantibacillus
ASV002,Bacteria,Pseudomonadota,Acetobacteraceae,Acetobacter
```

## Validation rules

The application checks:

- sample-ID overlap and orientation;
- duplicate or empty identifiers;
- missing, non-numeric, and negative abundances;
- zero-depth samples;
- all-zero features; and
- minimum matched sample count.

All uploaded sample IDs should be unique. Feature names should also be unique. Metadata variables intended for modeling should use consistent labels and should not contain accidental trailing spaces.

## Experimental-design guidance

- Keep biological replicate, vial, batch, sex, treatment, host species, stage, and generation in separate metadata columns.
- Use a random effect only when it reflects a meaningful repeated or grouped sampling unit.
- Do not treat multiple flies pooled into one sequencing sample as independent replicates.
- Inspect multivariate dispersion before interpreting PERMANOVA as evidence of centroid separation.
- Treat relative-abundance plots as descriptive because they do not remove compositional constraints.
