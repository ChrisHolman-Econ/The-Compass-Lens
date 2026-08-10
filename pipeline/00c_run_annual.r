# ==============================================================================
# Pipeline Execution: Annual Economic Benchmark
# ==============================================================================

library(here)
library(quarto)
library(cli)

cli_h1("Executing OWL Annual Economic Benchmark Pipeline")

# 1. Execute ELT & Visuals
source(here::here("pipeline", "03_fetch_annual_census.R"))
source(here::here("pipeline", "05b_generate_annual_plots.R"))
source(here::here("pipeline", "06_prep_report_vars.R"))

# 2. Output Directory
output_dir <- here::here("output", "annual")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# 3. Render Quarto Document
stamp <- format(Sys.Date(), "%Y")
out_filename <- paste0("OWL_Annual_Benchmark_", stamp, ".pdf")

cli_alert_info("Rendering templates/annual_benchmark.qmd to PDF...")

quarto::quarto_render(
  input = here::here("templates", "annual_benchmark.qmd"),
  output_file = out_filename
)

file.rename(
  from = here::here("templates", out_filename),
  to   = file.path(output_dir, out_filename)
)

cli_alert_success("Annual PDF successfully rendered: {file.path(output_dir, out_filename)}")