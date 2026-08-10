# ==============================================================================
# SCRIPT:  00_run_pipeline.R
# PURPOSE: Master Entry Point: Routes execution to specific cadence modules.
# SYSTEM:  The Compass Lens Architecture
# ==============================================================================

library(here)

# Execution Cadence Flags
RUN_MONTHLY   <- TRUE
RUN_QUARTERLY <- FALSE
RUN_ANNUAL    <- FALSE

if (RUN_MONTHLY)   source(here::here("pipeline", "00a_run_monthly.R"))
if (RUN_QUARTERLY) source(here::here("pipeline", "00b_run_quarterly.R"))
if (RUN_ANNUAL)    source(here::here("pipeline", "00c_run_annual.R"))