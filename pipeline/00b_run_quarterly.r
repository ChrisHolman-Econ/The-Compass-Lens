# ==============================================================================
# Pipeline Execution: Quarterly Economic Review
# ==============================================================================

library(here)
library(quarto)
library(cli)

cli_h1("Executing OWL Quarterly Economic Review Pipeline")

# 1. Execute ELT & Visuals
source(here::here("pipeline", "02_fetch_quarterly_qcew.R"))
source(here::here("pipeline", "05_generate_quarterly_plots.R"))
source(here::here("pipeline", "06_prep_report_vars.R"))

# 2. Output Directory
output_dir <- here::here("output", "quarterly")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# 3. Render Quarto Document
stamp <- format(Sys.Date(), "%Y_Q%q")
out_filename <- paste0("OWL_Quarterly_Review_", stamp, ".pdf")

cli_alert_info("Rendering templates/quarterly_review.qmd to PDF...")

quarto::quarto_render(
  input = here::here("templates", "quarterly_review.qmd"),
  output_file = out_filename
)

file.rename(
  from = here::here("templates", out_filename),
  to   = file.path(output_dir, out_filename)
)

cli_alert_success("Quarterly PDF successfully rendered: {file.path(output_dir, out_filename)}")