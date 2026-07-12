# ==============================================================================
# 3. CALCULATE CORE PULSE METRICS (MoM & YoY DELTAS)
# ==============================================================================
cat("[*] Calculating Pulse Report metrics...\n")
if (nrow(laus_clean) == 0) {
  stop("CRITICAL ERROR: laus_clean has 0 rows. Check your prep script filters before calculating metrics!")
}
# Sort and calculate lag metrics per county/metric track
laus_metrics <- laus_clean %>%
  arrange(county_name, metric, date) %>%
  group_by(county_name, metric) %>%
  mutate(
    value_lag_1m = lag(value, 1),
    value_lag_1y = lag(value, 12),
    mom_change   = value - value_lag_1m,
    yoy_change   = value - value_lag_1y
  ) %>%
  ungroup()

# Extract the most recent month's data for the immediate executive snapshot
latest_date <- max(laus_metrics$date)
cat(paste("[*] Pinpointing latest available data month:", latest_date, "\n"))

pulse_snapshot <- laus_metrics %>%
  filter(date == latest_date)

# ==============================================================================
# 4. STOW STABLE FLAT FILES FOR QUARTO
# ==============================================================================
cat("[*] Saving processed analytical objects to disk...\n")

# Save the full time-series for trend charts
write_rds(laus_metrics, file.path(PROCESSED_DIR, "laus_time_series.rds"))

# Save the single-month executive summary table for easy rendering
write_rds(pulse_snapshot, file.path(PROCESSED_DIR, "laus_latest_snapshot.rds"))

cat("\n========================================================\n")
cat("PIPELINE COMPLETE: Data is staged for Quarto compilation.\n")
cat("========================================================\n")