# Mapping your microbiome projects into the app

The upload layer is designed for the types of 16S datasets used in the Drosophila host-genotype and eight-species ethanol projects. The application does not hard-code those variables; every metadata column becomes available as a grouping or model variable.

## Fastest route: save the phyloseq object

If the complete object is already present in R:

```r
saveRDS(your_phyloseq_object, "nitin_microbiome_data.rds")
```

Upload `nitin_microbiome_data.rds` under **Data & QC → Phyloseq RDS**. The uploader also accepts an RDS list containing exactly one phyloseq object.

## Eight-species ethanol project

Preserve these variables as separate sample-metadata columns when available:

| Column | Example values | Purpose |
|---|---|---|
| `SampleID` | `Dmel_C_F_V1` | Unique sequencing-sample identifier |
| `Host_Species` | `D_melanogaster` | Composition, diversity, and host effects |
| `Treatment` | `Control`, `Ethanol` | Experimental perturbation |
| `Sex` | `Female`, `Male` | Stratification or model covariate |
| `Vial` | `V1`, `V2`, `V3` | Biological replicate and potential random effect |
| `Clade` | clade label | Higher-level evolutionary comparison |
| `Batch` | extraction or sequencing batch | Technical assessment and adjustment |

The abundance table should contain raw ASV counts before conversion to relative abundance. Taxonomy should remain in a separate table or within the phyloseq object.

## Mitonuclear longitudinal project

Preserve these variables when available:

| Column | Purpose |
|---|---|
| `SampleID` | Unique sequencing sample |
| `Mito_Genotype` | Mitochondrial background |
| `Nuclear_Genotype` | Nuclear background |
| `Mitonuclear_Genotype` | Combined genotype label for visualization |
| `Stage` | Developmental stage |
| `Generation` | Longitudinal generation |
| `Vial` | Repeated experimental unit/random effect |
| `Batch` | Extraction or sequencing batch |

For the factorial biological question, do not replace separate mitochondrial and nuclear variables with only the combined label. Retaining the component variables allows explicit main-effect and interaction models outside or in future versions of the app.

## What the first public demonstration should use

Use the synthetic dataset already included in `data/demo/` for the public portfolio. Upload a private research dataset only in a local or access-controlled deployment unless all collaborators have approved public release.
