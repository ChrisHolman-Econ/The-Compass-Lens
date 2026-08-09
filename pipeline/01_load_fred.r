# ==============================================================================
# SCRIPT:  01_fetch_fred.R
# PURPOSE: Pure Extract: Pull single-series macroeconomic indicators from FRED
#          API and save raw payload to data/raw/fred/
# SYSTEM:  The Compass Lens Architecture
# ==============================================================================

library(tidyverse)
library(fredr)
library(here)

# ------------------------------------------------------------------------------
# 1. ENVIRONMENT & PATH SAFETIES
# ------------------------------------------------------------------------------
RAW_FRED_DIR <- here::here("data", "raw", "fred")
if (!dir.exists(RAW_FRED_DIR)) dir.create(RAW_FRED_DIR, recursive = TRUE)

FRED_API_KEY <- Sys.getenv("FRED_API_KEY")
if (nchar(FRED_API_KEY) == 0) {
  stop("CRITICAL: 'FRED_API_KEY' not found in environment.")
}
fredr_set_key(FRED_API_KEY)

START_DATE <- as.Date("2018-01-01")

# ------------------------------------------------------------------------------
# 2. DEFINE FRED SERIES MANIFEST
# ------------------------------------------------------------------------------
fred_manifest <- tibble::tribble(
  ~series_id,             ~metric_name,                  ~geo_level,   ~frequency,
  "MORTGAGE30US",         "mortgage_rate_30yr_fixed",    "National",   "Weekly",
  "UMCSENT",              "consumer_sentiment_umich",    "National",   "Monthly",
  "CUURA208SA0",          "cpi_all_items_detroit",       "MSA",        "Bi-Monthly",
  "CPIAUCSL",             "cpi_all_items_us",            "National",   "Monthly",
  "UNRATE",               "unemployment_rate_us",        "National",   "Monthly",
  "MIUR",                 "unemployment_rate_michigan",  "Statewide",  "Monthly",
  "SMS26000000000000026", "nonfarm_employment_michigan", "Statewide",  "Monthly",
  "PERMIT",               "housing_permits_us",          "National",   "Monthly"
)

# ------------------------------------------------------------------------------
# 3. EXTRACTION ENGINE
# ------------------------------------------------------------------------------
message("--> Extracting raw FRED series...")

fetch_single_series <- function(id, name, geo, freq) {
  message(sprintf("    [API] Pulling %-30s [ID: %s]", name, id))
  
  fredr(
    series_id = id,
    observation_start = START_DATE,
    units = "lin"
  ) %>%
    select(date, value) %>%
    mutate(
      series_id   = id,
      metric_name = name,
      geo_level   = geo,
      frequency   = freq,
      value       = as.numeric(value),
      fetched_at  = Sys.time()
    )
}

raw_fred_data <- pmap_dfr(
  list(
    fred_manifest$series_id,
    fred_manifest$metric_name,
    fred_manifest$geo_level,
    fred_manifest$frequency
  ),
  fetch_single_series
)

# ------------------------------------------------------------------------------
# 4. LAND RAW ASSETS TO DISK
# ------------------------------------------------------------------------------
output_file <- file.path(RAW_FRED_DIR, "raw_fred.rds")
saveRDS(raw_fred_data, file = output_file)

message(sprintf("SUCCESS: Raw FRED extract landed -> %s (%s rows)", output_file, format(nrow(raw_fred_data), big.mark = ",")))