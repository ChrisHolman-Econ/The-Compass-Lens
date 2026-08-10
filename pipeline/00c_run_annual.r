# ==============================================================================
# SCRIPT:  00c_run_annual.R
# PURPOSE: Executable Cadence Module: Annual Census PEP/ACS ELT, Benchmark 
#          Analytics, Structural Plotting, and Quarto Report Generation.
# SYSTEM:  The Compass Lens Architecture
# ==============================================================================

suppressPackageStartupMessages({
  library(here)
  library(quarto)
  library(duckdb)
})

cat("========================================================\n")
cat(" RUNNING ANNUAL BENCHMARK CADENCE (CENSUS & STRUCTURAL)\n")
cat(" Timestamp: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("========================================================\n\n")

cadence_start <- Sys.time()

# Ensure open DB connections are cleanly closed on exit
on.exit({
  if (exists("con") && dbIsValid(con)) {
    dbDisconnect(con, shutdown = TRUE)
  }
}, add = TRUE)

# Pipeline script sequence for Annual execution
annual_scripts <- c(
  "03_load_census.r",         # Ingests Census PEP & ACS 5-Year metrics
  "04_hydrate_duckdb.r",      # Hydrates annual tables in DuckDB
  "05_transform_analytics.r", # Recomputes multi-year benchmark averages
  "06_prep_report_vars.r",   # Extracts annual structural metrics
  "09_plot_annual.r"          # Exports annual_population_index.png, etc.
)

for (script in annual_scripts) {
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
    cat(sprintf("\n❌ ANNUAL PIPELINE HALTED AT: %s\n", script))
    cat("Error Details: ", e$message, "\n")
    stop(e)
  })
}

# Render Quarto Report Target
cat(">>> RENDERING ANNUAL BENCHMARK QUARTO DOCUMENT...\n")
report_year <- format(Sys.Date(), "%Y") # e.g. 2026

quarto::quarto_render(
  input       = here::here("templates", "annual_benchmark.qmd"),
  output_file = sprintf("%s_annual_benchmark.pdf", report_year),
  output_dir  = here::here("reports", "annual")
)

total_elapsed <- round(as.numeric(difftime(Sys.time(), cadence_start, units = "mins")), 2)

cat("========================================================\n")
cat(sprintf(" [✓] ANNUAL CADENCE COMPLETE! Total time: %s mins\n", total_elapsed))
cat(sprintf(" Output Report: reports/annual/%s_annual_benchmark.pdf\n", report_year))
cat("========================================================\n")