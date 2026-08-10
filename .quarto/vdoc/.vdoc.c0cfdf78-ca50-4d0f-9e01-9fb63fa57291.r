#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#| label: setup-env
#| include: false

library(here)
library(knitr)
library(tidyverse)

# Load pre-calculated inline annual report variables
vars_path <- here::here("data", "report_vars.rds")

if (file.exists(vars_path)) {
  report_vars <- readRDS(vars_path)
} else {
  # Fallback structure if script hasn't populated data yet
  report_vars <- list(
    benchmark_year       = "Latest Available",
    total_corridor_pop   = "N/A",
    pop_change_pct       = "N/A",
    washtenaw_mhi        = "N/A",
    oakland_mhi          = "N/A",
    livingston_mhi       = "N/A",
    corridor_bach_pct    = "N/A"
  )
}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
