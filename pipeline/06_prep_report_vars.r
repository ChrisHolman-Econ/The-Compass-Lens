# ==============================================================================
# Pipeline Step 06: Prepare Report Inline Variables
# Architecture: The Compass Lens Architecture
# ==============================================================================

library(here)
library(tidyverse)
library(cli)

cli_h1("Preparing Report Inline Variables (report_vars.rds)")

# Paths
data_dir  <- here::here("data")
vars_out  <- here::here("data", "report_vars.rds")

# Initialize default list
report_vars <- list()

# ------------------------------------------------------------------------------
# 1. Monthly Metrics (LAUS, CES, CPI, UI)
# ------------------------------------------------------------------------------
monthly_path <- file.path(data_dir, "clean_monthly_metrics.rds")

if (file.exists(monthly_path)) {
  monthly_df <- readRDS(monthly_path)
  
  latest_date <- max(monthly_df$date, na.rm = TRUE)
  report_vars$current_month <- format(latest_date, "%B %Y")
  
  latest_monthly <- monthly_df %>% filter(date == latest_date)
  
  # Helper to safely extract values
  get_val <- function(df, geo, metric, fmt = "%.1f") {
    val <- df %>% 
      filter(area == geo, indicator == metric) %>% 
      pull(value) %>% 
      head(1)
    if (length(val) == 0 || is.na(val)) return("N/A")
    sprintf(fmt, val)
  }
  
  report_vars$washtenaw_unemp <- get_val(latest_monthly, "Washtenaw County", "unemployment_rate")
  report_vars$oakland_unemp   <- get_val(latest_monthly, "Oakland County", "unemployment_rate")
  report_vars$livingston_unemp<- get_val(latest_monthly, "Livingston County", "unemployment_rate")
  report_vars$mi_unemp        <- get_val(latest_monthly, "Michigan", "unemployment_rate")
  report_vars$detroit_cpi_yoy <- get_val(latest_monthly, "Detroit MSA", "cpi_yoy_pct")
  report_vars$ui_claims_total <- get_val(latest_monthly, "OWL Corridor", "ui_claims_sum", fmt = "%'d")
  
  cli_alert_success("Monthly report variables computed for {report_vars$current_month}.")
} else {
  cli_alert_warning("clean_monthly_metrics.rds not found. Populating monthly defaults.")
}

# ------------------------------------------------------------------------------
# 2. Quarterly Metrics (QCEW)
# ------------------------------------------------------------------------------
quarterly_path <- file.path(data_dir, "clean_quarterly_qcew.rds")

if (file.exists(quarterly_path)) {
  qcew_df <- readRDS(quarterly_path)
  
  latest_qtr <- max(qcew_df$period_label, na.rm = TRUE)
  report_vars$current_quarter <- latest_qtr
  
  q_latest <- qcew_df %>% filter(period_label == latest_qtr)
  
  report_vars$total_qcew_emp  <- format(sum(q_latest$month3_employment, na.rm = TRUE), big.mark = ",")
  report_vars$avg_weekly_wage <- format(round(mean(q_latest$avg_weekly_wage, na.rm = TRUE)), big.mark = ",")
  report_vars$yoy_wage_growth <- sprintf("%.1f", mean(q_latest$wage_yoy_pct, na.rm = TRUE))
  
  top_lq_row <- q_latest %>% arrange(desc(location_quotient)) %>% slice(1)
  report_vars$top_lq_industry <- top_lq_row$industry_title %||% "Manufacturing"
  report_vars$top_lq_score    <- sprintf("%.2f", top_lq_row$location_quotient %||% 0)
  
  cli_alert_success("Quarterly report variables computed for {report_vars$current_quarter}.")
} else {
  cli_alert_warning("clean_quarterly_qcew.rds not found. Populating quarterly defaults.")
}

# ------------------------------------------------------------------------------
# 3. Annual Metrics (ACS / PEP)
# ------------------------------------------------------------------------------
annual_path <- file.path(data_dir, "clean_annual_benchmark.rds")

if (file.exists(annual_path)) {
  annual_df <- readRDS(annual_path)
  
  latest_yr <- max(annual_df$year, na.rm = TRUE)
  report_vars$benchmark_year <- as.character(latest_yr)
  
  a_latest <- annual_df %>% filter(year == latest_yr)
  
  report_vars$total_corridor_pop <- format(sum(a_latest$population, na.rm = TRUE), big.mark = ",")
  report_vars$pop_change_pct     <- sprintf("%.2f", mean(a_latest$pop_change_pct, na.rm = TRUE))
  
  get_mhi <- function(df, geo) {
    val <- df %>% filter(area == geo) %>% pull(median_hh_income) %>% head(1)
    if (length(val) == 0 || is.na(val)) return("N/A")
    format(round(val), big.mark = ",")
  }
  
  report_vars$washtenaw_mhi  <- get_mhi(a_latest, "Washtenaw County")
  report_vars$oakland_mhi    <- get_mhi(a_latest, "Oakland County")
  report_vars$livingston_mhi <- get_mhi(a_latest, "Livingston County")
  report_vars$corridor_bach_pct <- sprintf("%.1f", mean(a_latest$bachelor_deg_pct, na.rm = TRUE))
  
  cli_alert_success("Annual report variables computed for year {report_vars$benchmark_year}.")
} else {
  cli_alert_warning("clean_annual_benchmark.rds not found. Populating annual defaults.")
}

# Export
saveRDS(report_vars, vars_out)
cli_alert_success("Saved unified report variables -> {vars_out}")