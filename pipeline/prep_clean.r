# ==============================================================================
# PROJECT: THE COMPASS LENS
# SCRIPT:  02_prep_clean.R
# PURPOSE: Parse, filter, and pivot raw BLS/FRED flat-files into an analytical engine
# ==============================================================================

library(data.table)
library(tidyverse)
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
cat("[*] Processing LAUS County & Statewide Data...\n")
laus_county_raw <- fread(file.path(RAW_DIR, "laus_county.txt"), sep = "\t", header = TRUE, fill = TRUE)
laus_state_raw  <- fread(file.path(RAW_DIR, "laus_state.txt"), sep = "\t", header = TRUE, fill = TRUE)

# Combine county and state flat files cleanly
laus_raw <- bind_rows(laus_county_raw, laus_state_raw)
setnames(laus_raw, names(laus_raw), trimws(names(laus_raw)))

laus_clean <- laus_raw %>%
  # 1. Clean whitespace across all raw character columns first
  mutate(
    series_id = trimws(series_id),
    period    = trimws(period),
    year      = trimws(year),
    value     = trimws(value)
  ) %>%
  # 2. Filter out NA, blanks, and annual average M13 values
  filter(!is.na(year) & !is.na(period) & !is.na(series_id)) %>%
  filter(year != "" & period != "" & period != "M13") %>%
  filter(str_detect(series_id, "^LAUCN|^LAUST")) %>%
  # 3. Extract metadata flags
  mutate(
    state_fips   = substr(series_id, 6, 7),
    area_type    = substr(series_id, 3, 4), # "CN" = County, "ST" = State
    county_fips  = if_else(area_type == "CN", substr(series_id, 8, 10), NA_character_),
    measure_code = substr(series_id, 19, 20) 
  ) %>%
  # 4. Keep target region
  filter(state_fips == MI_FIPS & (county_fips %in% names(COUNTY_MAP) | area_type == "ST")) %>%
  # 5. Extract month and strictly enforce valid months 01-12
  mutate(
    month_val = parse_number(period)
  ) %>%
  filter(!is.na(month_val) & month_val >= 1 & month_val <= 12) %>%
  mutate(
    county_name = case_when(
      area_type == "ST" ~ "Michigan (Statewide)",
      area_type == "CN" ~ COUNTY_MAP[county_fips],
      TRUE ~ NA_character_
    ),
    
    # Safely construct ISO YYYY-MM-01 string
    month_num = str_pad(month_val, width = 2, pad = "0"),
    date      = as.Date(paste(year, month_num, "01", sep = "-")),
    
    metric = case_when(
      measure_code == "03" ~ "unemployment_rate",
      measure_code == "04" ~ "unemployed_count",
      measure_code == "05" ~ "employed_count",
      measure_code == "06" ~ "labor_force",
      TRUE ~ NA_character_
    ),
    value = as.numeric(value)
  ) %>%
  filter(!is.na(metric) & !is.na(value) & !is.na(county_name) & !is.na(date))

# 3. CLEAN & PARSE CES (CURRENT EMPLOYMENT STATISTICS)
cat("[*] Processing CES State & Area Payrolls...\n")
ces_raw <- fread(file.path(RAW_DIR, "ces_state_area.txt"), sep = "\t", header = TRUE, fill = TRUE)
setnames(ces_raw, names(ces_raw), trimws(names(ces_raw)))

ces_clean <- ces_raw %>%
  filter(str_detect(series_id, "^SMU")) %>%
  mutate(
    state_fips    = substr(series_id, 4, 5),
    area_code     = substr(series_id, 6, 10),
    industry_code = substr(series_id, 11, 18),
    data_type     = substr(series_id, 19, 20)
  ) %>%
  filter(state_fips == MI_FIPS & area_code %in% c("00000", "35660")) %>%
  filter(period != "M13" & data_type == "01") %>% 
  mutate(
    region_name = if_else(area_code == "00000", "Michigan Statewide", "Detroit MSA"),
    date = as.Date(paste(year, substr(period, 2, 3), "01", sep = "-")),
    metric = if_else(industry_code == "00000000", "total_nonfarm_payroll", paste0("ind_", industry_code)),
    value = as.numeric(value)
  ) %>%
  filter(metric == "total_nonfarm_payroll" & !is.na(value))

# ==============================================================================
# 4. PIVOT WIDE, CONSOLIDATE & BUILD REGIONAL AGGREGATE
# ==============================================================================
cat("[*] Reshaping, completing date sequences, and generating Regional Summary...\n")

# 1. Pivot LAUS to wide structure & force missing date completion
laus_wide <- dcast(laus_clean, county_name + date ~ metric, value.var = "value") %>%
  as_tibble() %>%
  group_by(county_name) %>%
  complete(date = seq.Date(min(date), max(date), by = "1 month")) %>%
  ungroup()

# 2. GENERATE REGIONAL AGGREGATE (OWL CORRIDOR TOTAL ONLY)
# CRITICAL: Exclude 'Michigan (Statewide)' so it doesn't inflate corridor totals!
owl_region_summary <- laus_wide %>%
  filter(county_name != "Michigan (Statewide)") %>% 
  group_by(date) %>%
  summarize(
    county_name       = "OWL Corridor",
    
    labor_force       = if (all(is.na(labor_force))) NA_real_ else sum(labor_force, na.rm = TRUE),
    employed_count    = if (all(is.na(employed_count))) NA_real_ else sum(employed_count, na.rm = TRUE),
    unemployed_count  = if (all(is.na(unemployed_count))) NA_real_ else sum(unemployed_count, na.rm = TRUE),
    
    # Recalculate true regional rate
    unemployment_rate = (unemployed_count / labor_force) * 100,
    
    .groups = "drop"
  )

# 3. Combine individual counties, statewide baseline, and regional aggregate
laus_wide <- bind_rows(laus_wide, owl_region_summary)

# 4. Pivot CES to wide structure (RESOVED BUG: Restored missing ces_wide block)
ces_wide <- dcast(ces_clean, region_name + date ~ metric, value.var = "value") %>%
  as_tibble() %>%
  group_by(region_name) %>%
  complete(date = seq.Date(min(date), max(date), by = "1 month")) %>%
  ungroup()

# ==============================================================================
# 5. INTEGRATE FRED CONSUMER SENTIMENT (UMICH)
# ==============================================================================
cat("[*] Merging Consumer Sentiment benchmarks...\n")
sentiment_file <- file.path(RAW_DIR, "consumer_sentiment.txt")

if (file.exists(sentiment_file)) {
  sentiment_raw <- fread(sentiment_file, header = TRUE)
  setnames(sentiment_raw, c("date", "consumer_sentiment"))
  sentiment_raw[, date := as.Date(date)]
  
  laus_wide <- left_join(laus_wide, sentiment_raw, by = "date")
}

# ==============================================================================
# 6. SAVE PRODUCTION-READY ASSETS
# ==============================================================================
cat("[*] Exporting master data matrices to data/processed/...\n")

# Save binary RDS files
write_rds(laus_wide, file.path(PROCESSED_DIR, "master_county_pulse.rds"))
write_rds(ces_wide, file.path(PROCESSED_DIR, "master_payroll_pulse.rds"))

# Export Pro Tier CSV download
laus_pro_export <- laus_wide %>%
  select(
    `Date`                  = date,
    `Area`                  = county_name, # Renamed from `County`
    `Labor Force`           = labor_force,
    `Employed`              = employed_count,
    `Unemployed`            = unemployed_count,
    `Unemployment Rate (%)` = unemployment_rate
  ) %>%
  mutate(
    `Adjustment Status` = "NSA",
    Date = format(Date, "%B %Y")
  )

write_csv(laus_pro_export, file.path(PROCESSED_DIR, "OWL_Corridor_Area_Data.csv"))

cat("\n[✓] SUCCESS: Data pipeline transformation clean! RDS & CSV files exported.\n")