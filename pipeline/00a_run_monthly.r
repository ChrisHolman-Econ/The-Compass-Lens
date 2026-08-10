# ==============================================================================
# Pipeline Execution: Monthly Economic Briefing
# ==============================================================================

library(here)
library(quarto)
library(cli)

cli_h1("Executing OWL Monthly Economic Briefing Pipeline")

# 1. Execute ELT & Visuals
source(here::here("pipeline", "01_fetch_monthly_data.R"))
source(here::here("pipeline", "04_generate_monthly_plots.R"))
source(here::here("pipeline", "06_prep_report_vars.R"))

# 2. Ensure Output Directory Exists
output_dir <- here::here("output", "monthly")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# 3. Define Stamp Filename
stamp <- format(Sys.Date(), "%Y_%m")
out_filename <- paste0("OWL_Monthly_Briefing_", stamp, ".pdf")

# 4. Render Quarto Document
cli_alert_info("Rendering templates/monthly_brief.qmd to PDF...")

quarto::quarto_render(
  input = here::here("templates", "monthly_brief.qmd"),
  output_file = out_filename
)

# 5. Move Rendered PDF to output/monthly/
file.rename(
  from = here::here("templates", out_filename),
  to   = file.path(output_dir, out_filename)
)

cli_alert_success("Monthly PDF successfully rendered: {file.path(output_dir, out_filename)}")