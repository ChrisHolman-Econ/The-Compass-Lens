# ==============================================================================
# SCRIPT:  00_run_pipeline.R
# PURPOSE: Master Orchestrator: Sequentially executes ELT extraction and DuckDB 
#          hydration scripts for The Compass Lens.
# SYSTEM:  The Compass Lens Architecture
# ==============================================================================

library(here)

cat("========================================================\n")
cat(" STARTING COMPASS LENS DATA PIPELINE\n")
cat(" Timestamp: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("========================================================\n\n")

pipeline_start <- Sys.time()

# Define script sequence
pipeline_scripts <- c(
  "01_load_fred.r",
  "02_load_bls.r",
  "03_load_census.r",
  "04_hydrate_duckdb.r"
)

# Execution loop
for (script in pipeline_scripts) {
  script_path <- here::here("pipeline", script)
  
  if (!file.exists(script_path)) {
    stop(sprintf("CRITICAL ERROR: Required pipeline script not found: %s", script_path))
  }
  
  cat(sprintf("\n>>> RUNNING: %s ...\n", script))
  step_start <- Sys.time()
  
  tryCatch({
    source(script_path, local = FALSE, encoding = "UTF-8")
    elapsed <- round(as.numeric(difftime(Sys.time(), step_start, units = "secs")), 1)
    cat(sprintf(">>> COMPLETED: %s (%s seconds)\n", script, elapsed))
    
  }, error = function(e) {
    cat(sprintf("\n❌ PIPELINE HALTED AT: %s\n", script))
    cat("Error Details: ", e$message, "\n")
    stop(e)
  })
}

total_elapsed <- round(as.numeric(difftime(Sys.time(), pipeline_start, units = "mins")), 2)

cat("\n========================================================\n")
cat(sprintf(" PIPELINE RUN COMPLETE! Total time: %s minutes\n", total_elapsed))
cat(" Target Database: data/db/glce_econ_warehouse.duckdb\n")
cat("========================================================\n")