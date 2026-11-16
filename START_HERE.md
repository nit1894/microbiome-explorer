# Start here

This folder is already arranged as a GitHub repository. Do not move individual files or rename the `R`, `data`, `www`, `infra`, or `.github` folders.

## Your only scientific-data step

Run the application and choose one of these upload routes on **Data & QC**:

1. **Phyloseq RDS** — upload one trusted `.rds` file containing a complete `phyloseq` object.
2. **CSV/TSV tables** — upload an abundance table and sample metadata; taxonomy is optional.

The application automatically matches sample IDs and detects whether samples occupy the rows or columns of the abundance table. Read [DATA_FORMAT.md](DATA_FORMAT.md) if validation reports an ID mismatch.

## Put the project on GitHub

1. Create a new empty GitHub repository named `microbiome-explorer`. Do not add a README or license on GitHub because this folder already contains both.
2. Open Terminal and enter the extracted project folder.
3. Run the following commands, replacing the final URL with the URL GitHub shows you:

```bash
git init
git add .
git commit -m "Launch Microbiome Explorer"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/microbiome-explorer.git
git push -u origin main
```

Using `git add .` matters because it includes the hidden `.github` workflows and `.gitignore` file.

## Run locally

With R installed:

```r
source("install_packages.R")
shiny::runApp()
```

With Docker installed:

```bash
docker compose up --build
```

Then open <http://localhost:3838>.

## Before adding the link to a résumé

- Confirm that the demonstration dataset loads.
- Open every analysis page and confirm that plots appear.
- Run MaAsLin2 once.
- Add one screenshot to `screenshots/` and link it from `README.md`.
- Replace `YOUR-USERNAME` in `CITATION.cff` with your GitHub username.

AWS deployment is deliberately separate from the first GitHub upload. The application, Docker definition, AWS infrastructure, and deployment workflow are already in the repository; AWS resources must be created in your own account before the deployment workflow can run.
