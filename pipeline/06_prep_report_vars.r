# ==============================================================================
# SCRIPT: 06_prep_report_vars.r
# PURPOSE: Query DuckDB analytics views & generate formatted report variables
# ==============================================================================

library(DBI)
library(duckdb)
library(dplyr)
library(stringr)

con <- dbConnect(duckdb(), dbdir = here::here("data/db/glce_econ_warehouse.duckdb"), read_only = TRUE)

# --- 1. Helper Function for Conditional Narrative Strings ---
fmt_direction <- function(val, pos_label = "increased", neg_label = "decreased", zero_label = "was flat", decimals = 1, unit = "percentage points") {
  if (is.na(val)) return("was unchanged")
  if (val > 0) {
    sprintf("%s by %.*f %s", pos_label, decimals, val, unit)
  } else if (val < 0) {
    sprintf("%s by %.*f %s", neg_label, decimals, abs(val), unit)
  } else {
    zero_label
  }
}

# --- 2. Query Latest Unemployment Data ---
laus_latest <- dbGetQuery(con, "
  WITH ranked_data AS (
    SELECT 
      observation_date AS date, 
      mi_unemployment_rate AS mi_unemp_rate, 
      us_unemployment_rate AS us_unemp_rate,
      mi_unemployment_rate - LAG(mi_unemployment_rate, 1) OVER (ORDER BY observation_date ASC) AS mi_unemp_mom_change,
      mi_unemployment_rate - LAG(mi_unemployment_rate, 12) OVER (ORDER BY observation_date ASC) AS mi_unemp_yoy_change
    FROM vw_mi_vs_us_unemployment
  )
  SELECT *
  FROM ranked_data
  ORDER BY date DESC
  LIMIT 2
")

latest_row <- laus_latest[1, ]
prev_row   <- laus_latest[2, ]

# --- 3. Construct Variable Environment ---
report_vars <- list(
  ref_month          = format(as.Date(latest_row$date), "%B %Y"),
  mi_unemp_rate_str  = sprintf("%.1f%%", latest_row$mi_unemp_rate),
  us_unemp_rate_str  = sprintf("%.1f%%", latest_row$us_unemp_rate),
  
  # Conditional direction strings
  mi_u_mom_phrase    = fmt_direction(latest_row$mi_unemp_mom_change, pos_label = "increased", neg_label = "decreased"),
  mi_u_yoy_phrase    = fmt_direction(latest_row$mi_unemp_yoy_change, pos_label = "rose", neg_label = "declined")
)

dbDisconnect(con)