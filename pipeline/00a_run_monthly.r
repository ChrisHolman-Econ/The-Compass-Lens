# pipeline/00a_run_monthly.R
library(here)
library(quarto)

cat("========================================================\n")
cat(" RUNNING MONTHLY BRIEF CADENCE (ELT -> ANALYTICS -> REPORT)\n")
cat("========================================================\n")

# 1. Run pipeline ETL & Monthly Visualization
source(here("pipeline", "01_load_fred.r"))
source(here("pipeline", "02_load_bls.r"))
source(here("pipeline", "04_hydrate_duckdb.r"))
source(here("pipeline", "05_transform_analytics.r"))
source(here("pipeline", "06_prep_report_vars.r"))
source(here("pipeline", "07_plot_monthly.r"))

# 2. Render Quarto Monthly Briefing
quarto_render(
  input = here("templates", "monthly_brief.qmd"),
  output_file = sprintf("%s_monthly_brief.pdf", format(Sys.Date(), "%Y-%m")),
  output_dir = here("reports", "monthly")
)