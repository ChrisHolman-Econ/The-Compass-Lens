# ==============================================================================
# SCRIPT:  03_load_census.R
# PURPOSE: Pure Extract: Pull county-level income, poverty, and educational
#          attainment baselines for Michigan via tidycensus / Census API.
# SYSTEM:  The Compass Lens Architecture
# ==============================================================================

library(tidyverse)
library(tidycensus)
library(here)

# ------------------------------------------------------------------------------
# 1. ENVIRONMENT & PATH SAFETIES
# ------------------------------------------------------------------------------
RAW_CENSUS_DIR <- here::here("data", "raw", "census")
if (!dir.exists(RAW_CENSUS_DIR)) dir.create(RAW_CENSUS_DIR, recursive = TRUE)

# Auto-check and search project root for .Renviron if key isn't loaded in session
if (nchar(Sys.getenv("CENSUS_API_KEY")) == 0) {
  if (file.exists(".Renviron")) {
    readRenviron(".Renviron")
  } else if (file.exists(here::here(".Renviron"))) {
    readRenviron(here::here(".Renviron"))
  } else if (file.exists("~/.Renviron")) {
    readRenviron("~/.Renviron")
  }
}

CENSUS_KEY <- Sys.getenv("CENSUS_API_KEY")
if (nchar(CENSUS_KEY) == 0) {
  stop("CRITICAL: 'CENSUS_API_KEY' not found in environment. Please set CENSUS_API_KEY in your .Renviron file.")
}

# Install Census API key for active session
census_api_key(CENSUS_KEY, install = FALSE)

# ------------------------------------------------------------------------------
# 2. DEFINE ACS VARIABLE MANIFEST
# ------------------------------------------------------------------------------
acs_vars <- c(
  # Median Household Income in the past 12 months
  "median_household_income" = "B19013_001",
  
  # Poverty Universe & Population Below Poverty Level
  "poverty_universe"        = "B17001_001",
  "poverty_count"           = "B17001_002",
  
  # Educational Attainment (Population 25 years and over)
  "edu_universe_25plus"     = "B15003_001",
  "edu_high_school_ged"     = "B15003_017",
  "edu_bachelors"           = "B15003_022",
  "edu_masters"             = "B15003_023",
  "edu_professional"        = "B15003_024",
  "edu_doctorate"           = "B15003_025"
)

# ACS 5-Year Release Years to Extract
ACS_YEARS <- 2018:2022

# ------------------------------------------------------------------------------
# 3. EXTRACTION ENGINE
# ------------------------------------------------------------------------------
message("--> Extracting raw Census ACS 5-Year estimates for Michigan counties...")

fetch_county_acs <- function(target_year) {
  message(sprintf("    [Census API] Pulling ACS 5-Year data for year: %d", target_year))
  
  get_acs(
    geography   = "county",
    state       = "MI",
    variables   = acs_vars,
    year        = target_year,
    survey      = "acs5",
    geometry    = FALSE,
    output      = "tidy"
  ) %>%
    mutate(
      acs_year   = target_year,
      fetched_at = Sys.time()
    )
}

# Map across all target ACS 5-year releases
raw_census_data <- map_dfr(ACS_YEARS, fetch_county_acs)

# ------------------------------------------------------------------------------
# 4. LAND RAW ASSETS TO DISK
# ------------------------------------------------------------------------------
output_file <- file.path(RAW_CENSUS_DIR, "raw_census.rds")
saveRDS(raw_census_data, file = output_file)

# Fixed sprintf formatting using format(..., big.mark = ",")
message(sprintf("SUCCESS: Raw Census extract landed -> %s (%s rows)", 
                output_file, 
                format(nrow(raw_census_data), big.mark = ",")))