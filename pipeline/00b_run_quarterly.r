# ==============================================================================
# SCRIPT:  00b_run_quarterly.R
# PURPOSE: Executable Cadence Module: Quarterly QCEW ELT, Analytics, Plotting, 
#          and Quarto Report Generation.
# SYSTEM:  The Compass Lens Architecture
# ==============================================================================

suppressPackageStartupMessages({
  library(here)
  library(quarto)
  library(duckdb)
})

cat("========================================================\n")
cat(" RUNNING QUARTERLY REVIEW CADENCE (QCEW & INDUSTRY LQs)\n")
cat(" Timestamp: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("========================================================\n\n")

cadence_start <- Sys.time()

# Ensure open DB connections are cleanly closed on exit
on.exit({
  if (exists("con") && dbIsValid(con)) {
    dbDisconnect(con, shutdown = TRUE)
  }
}, add = TRUE)

# Pipeline script sequence for Quarterly execution
quarterly_scripts <- c(
  "02_load_bls.r",            # Refreshes QCEW series
  "04_hydrate_duckdb.r",      # Hydrates updated DuckDB tables
  "05_transform_analytics.r", # Recomputes Industry LQs and Wage Aggregates
  "06_prep_report_vars.r",   # Extracts quarterly inline metrics
  "08_plot_quarterly.r"       # Exports quarterly_qcew_employment.png, etc.
)

for (script in quarterly_scripts) {
  script_path <- here::here("pipeline", script)
  
  if (!file.exists(script_path)) {
    stop(sprintf("CRITICAL ERROR: Required pipeline script missing: %s", script_path))
  }
  
  cat(sprintf(">>> RUNNING: %s ...\n", script))
  step_start <- Sys.time()
  
  tryCatch({
    source(script_path, local = new.env(parent = globalenv()), encoding = "UTF-8")
    elapsed <- round(as.numeric(difftime(Sys.time(), step_start, units = "secs")), 1)
    cat(sprintf("   [✓] COMPLETED: %s (%s seconds)\n\n", script, elapsed))
  }, error = function(e) {
    cat(sprintf("\n❌ QUARTERLY PIPELINE HALTED AT: %s\n", script))
    cat("Error Details: ", e$message, "\n")
    stop(e)
  })
}

# Render Quarto Report Target
cat(">>> RENDERING QUARTERLY REVIEW QUARTO DOCUMENT...\n")
report_year_qtr <- format(Sys.Date(), "%Y-Q%q") # e.g. 2026-Q3

quarto::quarto_render(
  input       = here::here("templates", "quarterly_review.qmd"),
  output_file = sprintf("%s_quarterly_review.pdf", report_year_qtr),
  output_dir  = here::here("reports", "quarterly")
)

total_elapsed <- round(as.numeric(difftime(Sys.time(), cadence_start, units = "mins")), 2)

cat("========================================================\n")
cat(sprintf(" [✓] QUARTERLY CADENCE COMPLETE! Total time: %s mins\n", total_elapsed))
cat(sprintf(" Output Report: reports/quarterly/%s_quarterly_review.pdf\n", report_year_qtr))
cat("========================================================\n")