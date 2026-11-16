# Microbiome Explorer - Docker build for the current project layout
FROM rocker/shiny:4.5.2

# System dependencies for R packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gfortran \
    libcurl4-openssl-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libfribidi-dev \
    libglpk-dev \
    libgsl-dev \
    libharfbuzz-dev \
    libjpeg-dev \
    libpng-dev \
    libssl-dev \
    libtiff-dev \
    libudunits2-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /srv/shiny-server

# Package installation is independent of source files, for Docker build caching
COPY install_packages.R /tmp/install_packages.R
RUN Rscript /tmp/install_packages.R && rm /tmp/install_packages.R

# Remove bundled example apps so the project is served at port 3838 root
RUN rm -rf /srv/shiny-server/*

# App and supporting scripts live at repository root
COPY app.R analysis.R data_io.R plots.R s3_storage.R styles.css ./

# Demo dataset lives under data/demo/
COPY data/ ./data/

# Shiny serves static files in www/
RUN mkdir -p www \
    && cp styles.css www/styles.css \
    && chown -R shiny:shiny /srv/shiny-server

EXPOSE 3838
HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 \
  CMD curl --fail http://localhost:3838/ || exit 1

CMD ["/usr/bin/shiny-server"]
