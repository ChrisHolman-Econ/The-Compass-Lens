# ==============================================================================
# PROJECT: THE COMPASS LENS
# SCRIPT:  02_prep_clean.R
# PURPOSE: Parse, filter, and pivot raw BLS/FRED flat-files into an analytical engine
# ==============================================================================

library(data.table)
library(dplyr)
library(stringr)

# 1. SETUP PATHS & CONFIGURATION
RAW_DIR <- "data/raw"
PROCESSED_DIR <- "data/processed"
if (!dir.exists(PROCESSED_DIR)) dir.create(PROCESSED_DIR, recursive = TRUE)

cat("========================================================\n")
cat("LAUNCHING DATA TRANSFORMATION & CLEANING PIPELINE\n")
cat("========================================================\n\n")

# Target Michigan FIPS and the core OWL Corridor counties
MI_FIPS <- "26"
COUNTY_MAP <- c(
  "125" = "Oakland",
  "161" = "Washtenaw",
  "093" = "Livingston"
)

# 2. CLEAN & PARSE LAUS (LOCAL AREA UNEMPLOYMENT STATISTICS)
cat("[*] Processing LAUS County Data...\n")
laus_raw <- fread(file.path(RAW_DIR, "laus_county.txt"), sep = "\t", header = TRUE, fill = TRUE)

# Clean up column names (BLS often has trailing spaces in headers)
setnames(laus_raw, names(laus_raw), trimws(names(laus_raw)))

# Parse the 20-character BLS LAUS Series ID
# Format: LAUCN261610000000003 -> State: 26, County: 161, Measure: 03
laus_clean <- laus_raw %>%
  lazy_dt() %>%
  filter(str_detect(series_id, "^LAUCN")) %>%
  mutate(
    state_fips   = substr(series_id, 6, 7),
    county_fips  = substr(series_id, 8, 10),
    measure_code = substr(series_id, 18, 19)
  ) %>%
  filter(state_fips == MI_FIPS & county_fips %in% names(COUNTY_MAP)) %>%
  filter(period != "M13") %>% # Strip the annual average trap
  mutate(
    county_name = COUNTY_MAP[county_fips],
    date = as.Date(paste(year, substr(period, 2, 3), "01", sep = "-")),
    metric = case_when(
      measure_code == "03" ~ "unemployment_rate",
      measure_code == "04" ~ "unemployed_count",
      measure_code == "05" ~ "employed_count",
      measure_code == "06" ~ "labor_force",
      TRUE ~ NA_character_
    ),
    value = as.numeric(value)
  ) %>%
  filter(!is.na(metric) & !is.na(value)) %>%
  as.data.table()

# 3. CLEAN & PARSE CES (CURRENT EMPLOYMENT STATISTICS)
cat("[*] Processing CES State & Area Payrolls...\n")
ces_raw <- fread(file.path(RAW_DIR, "ces_state_area.txt"), sep = "\t", header = TRUE, fill = TRUE)
setnames(ces_raw, names(ces_raw), trimws(names(ces_raw)))

# Format: SMU26356600000000001 -> State: 26, Area: 35660 (Detroit MSA), Industry: 00000000 (Total Nonfarm)
# Let's track Michigan statewide (00000) and Detroit-Warren-Dearborn MSA (35660)
ces_clean <- ces_raw %>%
  lazy_dt() %>%
  filter(str_detect(series_id, "^SMU")) %>%
  mutate(
    state_fips    = substr(series_id, 4, 5),
    area_code     = substr(series_id, 6, 10),
    industry_code = substr(series_id, 11, 18),
    data_type     = substr(series_id, 19, 20)
  ) %>%
  filter(state_fips == MI_FIPS & area_code %in% c("00000", "35660")) %>%
  filter(period != "M13" & data_type == "01") %>% # 01 is All Employees
  mutate(
    region_name = if_else(area_code == "00000", "Michigan Statewide", "Detroit MSA"),
    date = as.Date(paste(year, substr(period, 2, 3), "01", sep = "-")),
    metric = if_else(industry_code == "00000000", "total_nonfarm_payroll", paste0("ind_", industry_code)),
    value = as.numeric(value)
  ) %>%
  filter(metric == "total_nonfarm_payroll" & !is.na(value)) %>%
  as.data.table()

# 4. PIVOT WIDE & CONSOLIDATE
cat("[*] Reshaping and assembling the Wide Master dataframe...\n")

# Pivot LAUS to wide structure
laus_wide <- dcast(laus_clean, county_name + date ~ metric, value.var = "value")

# Pivot CES to wide structure
ces_wide <- dcast(ces_clean, region_name + date ~ metric, value.var = "value")

# 5. INTEGRATE FRED CONSUMER SENTIMENT (UMICH)
cat("[*] Merging Consumer Sentiment benchmarks...\n")
sentiment_file <- file.path(RAW_DIR, "consumer_sentiment.txt")

if (file.exists(sentiment_file)) {
  sentiment_raw <- fread(sentiment_file, header = TRUE)
  setnames(sentiment_raw, c("date", "consumer_sentiment"))
  sentiment_raw[, date := as.Date(date)]
  
  # Join sentiment onto our regional dataframes by date
  laus_wide <- merge(laus_wide, sentiment_raw, by = "date", all.x = TRUE)
}

# 6. SAVE PRODUCTION-READY ASSETS
cat("[*] Exporting master data matrices to data/processed/...\n")
fwrite(laus_wide, file.path(PROCESSED_DIR, "master_county_pulse.csv"))
fwrite(ces_wide, file.path(PROCESSED_DIR, "master_payroll_pulse.csv"))

cat("\n[✓] SUCCESS: Data pipeline transformation clean! Ready for analysis tomorrow morning.\n")