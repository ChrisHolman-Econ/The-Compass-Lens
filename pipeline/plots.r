# ==============================================================================
# SCRIPT:  plots.r
# PROJECT: The Compass Lens
# PURPOSE: Render and export core economic graphics from DuckDB views using
#          the consistent theme_compass design system.
# ==============================================================================

library(DBI)
library(duckdb)
library(ggplot2)
library(scales)
library(dplyr)

# 1. DIRECTORY CONFIGURATION
# ------------------------------------------------------------------------------
PLOTS_DIR <- here::here("plots")
if (!dir.exists(PLOTS_DIR)) {
  dir.create(PLOTS_DIR, recursive = TRUE)
}

# 2. DESIGN SYSTEM: THEME COMPASS & PALETTE DEFINITIONS
# ------------------------------------------------------------------------------
# Primary Brand Palette
COLOR_NAVY      <- "#00274C" # Primary Accent / Trendline
COLOR_LIGHT_BLUE<- "#A4C8E0" # Secondary Accent / Monthly Series
COLOR_SLATE     <- "#708090" # Comparative Benchmark / US Series
COLOR_GRID      <- "#E5E9F0" # Subtle Gridlines
COLOR_TEXT_DARK <- "#2E3440" # Header and Body Text
COLOR_TEXT_MUTED<- "#4C566A" # Subtitle and Axis Titles

theme_compass <- function(base_size = 12, base_family = "sans") {
  theme_minimal(base_size = base_size, base_family = base_family) %+replace%
    theme(
      # Typography
      plot.title        = element_text(face = "bold", size = base_size * 1.25, color = COLOR_TEXT_DARK, margin = margin(b = 4)),
      plot.subtitle     = element_text(size = base_size * 0.9, color = COLOR_TEXT_MUTED, margin = margin(b = 12)),
      plot.caption      = element_text(size = base_size * 0.75, color = COLOR_TEXT_MUTED, hjust = 1, margin = margin(t = 10)),
      axis.title        = element_text(size = base_size * 0.85, color = COLOR_TEXT_MUTED, face = "plain"),
      axis.text         = element_text(size = base_size * 0.8, color = COLOR_TEXT_DARK),
      
      # Gridlines & Layout
      panel.grid.major  = element_line(color = COLOR_GRID, linewidth = 0.4),
      panel.grid.minor  = element_blank(),
      panel.background  = element_blank(),
      plot.background   = element_rect(fill = "white", color = NA),
      plot.margin       = margin(t = 16, r = 16, b = 16, l = 16),
      
      # Legend Alignment
      legend.position   = "top",
      legend.justification = "left",
      legend.direction  = "horizontal",
      legend.title      = element_blank(),
      legend.text       = element_text(size = base_size * 0.85, color = COLOR_TEXT_DARK),
      legend.background = element_blank(),
      legend.key        = element_blank()
    )
}

# 3. DUCKDB CONNECTION
# ------------------------------------------------------------------------------
DB_PATH <- here::here("data", "db", "glce_econ_warehouse.duckdb")

if (!file.exists(DB_PATH)) {
  stop("DuckDB database file not found. Please run pipeline hydration scripts first.")
}

con <- dbConnect(duckdb(), dbdir = DB_PATH, read_only = TRUE)

message("========================================================")
message("GENERATING & EXPORTING PIPELINE PLOTS (THEME COMPASS)")
message("========================================================\n")


# ------------------------------------------------------------------------------
# 4. PLOT 1: MICHIGAN VS US UNEMPLOYMENT RATE
# ------------------------------------------------------------------------------
cat("[*] Rendering: Michigan vs. US Unemployment Rate...\n")

df_unemp <- dbGetQuery(con, "
  SELECT 
    observation_date AS date, 
    mi_unemployment_rate AS mi_rate, 
    us_unemployment_rate AS us_rate
  FROM vw_mi_vs_us_unemployment
  WHERE observation_date >= '2019-01-01'
  ORDER BY observation_date ASC
")

p_unemp <- ggplot(df_unemp, aes(x = as.Date(date))) +
  geom_line(aes(y = mi_rate, color = "Michigan"), linewidth = 1.1) +
  geom_line(aes(y = us_rate, color = "United States"), linewidth = 0.9, linetype = "dashed") +
  scale_color_manual(values = c("Michigan" = COLOR_NAVY, "United States" = COLOR_SLATE)) +
  scale_y_continuous(labels = function(x) paste0(x, "%")) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  theme_compass(base_size = 12) +
  labs(
    title = "Michigan vs. U.S. Unemployment Rate",
    subtitle = "Not Seasonally Adjusted (NSA) | Monthly Unemployment Rates",
    caption = "Source: U.S. Bureau of Labor Statistics (LAUS)",
    x = NULL,
    y = "Unemployment Rate (%)"
  )

file_unemp <- file.path(PLOTS_DIR, "mi_vs_us_unemployment.png")
ggsave(file_unemp, plot = p_unemp, width = 8, height = 4.5, dpi = 300)
cat(sprintf(" [✓] Saved: %s\n\n", file_unemp))


# ------------------------------------------------------------------------------
# 5. PLOT 2: MICHIGAN LABOR FORCE & 12-MONTH MOVING AVERAGE
# ------------------------------------------------------------------------------
cat("[*] Rendering: Michigan Labor Force & 12-MA Trend...\n")

# 1. Fetch aggregated Michigan labor force using standard BLS series_id encoding:
#    - '06' suffix = Civilian Labor Force measure
#    - '26' prefix = Michigan FIPS code
df_raw <- dbGetQuery(con, "
  SELECT 
    CAST(observation_date AS DATE) AS date,
    SUM(value) AS mi_labor_force
  FROM vw_laus_county_clean
  WHERE measure_type = 'Labor Force'
    AND (series_id LIKE 'LAUCN26%' OR CAST(county_fips AS VARCHAR) LIKE '26%')
  GROUP BY observation_date
  ORDER BY observation_date ASC
")

if (nrow(df_raw) == 0) {
  stop("Error: Query returned 0 rows. Check if series_id encoding uses a different suffix or state FIPS.")
}

# 2. Fill missing calendar months (e.g., October) and compute strict 12-MA in R
df_lf <- df_raw %>%
  mutate(date = as.Date(date)) %>%
  filter(!is.na(date)) %>%
  # Ensures missing periods (e.g. October) exist as explicit NA rows
  complete(date = seq.Date(min(date), max(date), by = "month")) %>%
  mutate(
    mi_lf_thousands = mi_labor_force / 1000.0,
    # Strict 12-MA: requires all 12 trailing months to contain valid data
    mi_lf_12ma_thousands = sapply(seq_along(mi_lf_thousands), function(i) {
      if (i < 12) return(NA_real_)
      window <- mi_lf_thousands[(i - 11):i]
      if (sum(!is.na(window)) == 12) mean(window) else NA_real_
    })
  ) %>%
  filter(date >= as.Date("2019-01-01"))

p_lf <- ggplot(df_lf, aes(x = date)) +
  geom_line(aes(y = mi_lf_thousands, color = "Monthly Labor Force"), linewidth = 0.8, alpha = 0.6) +
  geom_line(aes(y = mi_lf_12ma_thousands, color = "12-Month Moving Avg"), linewidth = 1.2) +
  scale_color_manual(values = c(
    "Monthly Labor Force" = COLOR_LIGHT_BLUE, 
    "12-Month Moving Avg" = COLOR_NAVY
  )) +
  scale_y_continuous(labels = comma_format(suffix = "k")) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  theme_compass(base_size = 12) +
  labs(
    title = "Michigan Civilian Labor Force Trend",
    subtitle = "Monthly Level vs. 12-Month Moving Average (Thousands)",
    caption = "Note: Gaps indicate missing survey periods. 12-MA requires 12 complete months.\nSource: U.S. Bureau of Labor Statistics (LAUS)",
    x = NULL,
    y = "Labor Force (Thousands)"
  )

file_lf <- file.path(PLOTS_DIR, "mi_labor_force_12ma.png")
ggsave(file_lf, plot = p_lf, width = 8, height = 4.5, dpi = 300)
cat(sprintf(" [✓] Saved: %s (Rows: %d)\n\n", file_lf, nrow(df_lf)))


# ------------------------------------------------------------------------------
# 6. PLOT 3: MACRO ECONOMIC INDICATORS (FRED YoY)
# ------------------------------------------------------------------------------
cat("[*] Rendering: Macro YoY Indicators...\n")

df_macro <- dbGetQuery(con, "
  SELECT 
    observation_date AS date,
    series_id,
    value,
    yoy_pct_change
  FROM vw_fred_macro_yoy
  WHERE observation_date >= '2020-01-01'
  ORDER BY observation_date ASC
")

if (nrow(df_macro) > 0) {
  # Normalize series labels for mapping
  df_macro <- df_macro %>%
    mutate(series_label = case_when(
      grepl("CPI", series_id, ignore.case = TRUE) ~ "CPI (Inflation)",
      grepl("INDPRO", series_id, ignore.case = TRUE) ~ "Industrial Production",
      grepl("PAYEMS|EMP", series_id, ignore.case = TRUE) ~ "Total Nonfarm Employment",
      TRUE ~ series_id
    ))

  p_macro <- ggplot(df_macro, aes(x = as.Date(date), y = yoy_pct_change, color = series_label)) +
    geom_line(linewidth = 1) +
    scale_color_manual(values = c(
      "CPI (Inflation)"          = COLOR_NAVY,
      "Industrial Production"    = COLOR_LIGHT_BLUE,
      "Total Nonfarm Employment" = COLOR_SLATE
    )) +
    scale_y_continuous(labels = function(x) paste0(x, "%")) +
    scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
    theme_compass(base_size = 12) +
    labs(
      title = "Key Macroeconomic YoY Trends",
      subtitle = "Selected FRED Indicators Year-over-Year % Change",
      caption = "Source: Federal Reserve Bank of St. Louis (FRED)",
      x = NULL,
      y = "YoY Change (%)"
    )

  file_macro <- file.path(PLOTS_DIR, "macro_yoy_trends.png")
  ggsave(file_macro, plot = p_macro, width = 8, height = 4.5, dpi = 300)
  cat(sprintf(" [✓] Saved: %s (Rows: %d)\n\n", file_macro, nrow(df_macro)))
} else {
  cat(" [⚠️] Skipping macro plot: No matching series in vw_fred_macro_yoy.\n\n")
}

# 7. SAFELY CLOSE CONNECTION
dbDisconnect(con)

cat("========================================================\n")
cat(" PIPELINE STEP COMPLETE: ALL PLOTS EXPORTED WITH THEME COMPASS\n")
cat("========================================================\n")