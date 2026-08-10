# ==============================================================================
# PIPELINE STEP 07: MONTHLY VISUALIZATION ENGINE (THEME COMPASS)
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(scales)
  library(here)
  library(duckdb)
})

# ------------------------------------------------------------------------------
# 1. SETUP PATHS & THEME DEFINITIONS
# ------------------------------------------------------------------------------
# Load centralized theme & color utility
source(here::here("pipeline", "utils_theme.r"))

PLOTS_DIR <- here("plots")
if (!dir.exists(PLOTS_DIR)) dir.create(PLOTS_DIR, recursive = TRUE)

cat("========================================================\n")
cat("GENERATING MONTHLY PUBLICATION PLOTS (THEME COMPASS)\n")
cat("========================================================\n\n")

if (!exists("con") || !dbIsValid(con)) {
  DB_PATH <- here("data", "duckdb", "compass_lens.duckdb")
  con <- dbConnect(duckdb::duckdb(), DB_PATH, read_only = TRUE)
}

# ------------------------------------------------------------------------------
# M1. OWL CORRIDOR UNEMPLOYMENT RATES
# ------------------------------------------------------------------------------
cat("[1/4] Rendering: OWL Corridor Unemployment Rates...\n")
df_owl_unemp <- dbGetQuery(con, "
  SELECT CAST(observation_date AS DATE) AS date, county_name, value AS unemployment_rate
  FROM vw_laus_owl_corridor
  WHERE measure_type IN ('Unemployment Rate', 'unemployment_rate')
    AND observation_date >= '2021-01-01'
  ORDER BY observation_date ASC
")

p_owl_unemp <- ggplot(df_owl_unemp, aes(x = date, y = unemployment_rate, color = county_name, linewidth = county_name)) +
  geom_line(alpha = 0.85, na.rm = TRUE) +
  scale_color_manual(values = c("OWL Corridor" = COLOR_CORRIDOR, "Oakland County" = COLOR_OAKLAND, "Livingston County" = COLOR_LIVINGSTON, "Washtenaw County" = COLOR_WASHTENAW, "Michigan (Statewide)" = COLOR_MICHIGAN)) +
  scale_linewidth_manual(values = c("OWL Corridor" = 1.2, "Oakland County" = 0.8, "Livingston County" = 0.8, "Washtenaw County" = 0.8, "Michigan (Statewide)" = 0.8)) +
  scale_y_continuous(labels = label_percent(scale = 1, accuracy = 0.1)) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  theme_compass() +
  labs(title = "OWL Corridor Unemployment Rate Trajectories", subtitle = "Post-pandemic normalization across Oakland, Washtenaw, & Livingston Counties (%)", caption = "Source: U.S. Bureau of Labor Statistics (LAUS)", x = NULL, y = "Unemployment Rate")

ggsave(file.path(PLOTS_DIR, "laus_unemployment_rates.png"), plot = p_owl_unemp, width = 8, height = 4.5, dpi = 300)

# ------------------------------------------------------------------------------
# M2. OWL CORRIDOR INDEXED LABOR FORCE (JAN 2022 = 100, 12-MA)
# ------------------------------------------------------------------------------
cat("[2/4] Rendering: OWL Corridor Labor Force Capacity (Indexed 12-MA)...\n")
df_owl_lf <- dbGetQuery(con, "
  SELECT CAST(observation_date AS DATE) AS date, county_name, value AS labor_force
  FROM vw_laus_owl_corridor
  WHERE measure_type IN ('Labor Force', 'labor_force')
    AND observation_date >= '2020-01-01'
  ORDER BY county_name, observation_date ASC
") %>%
  group_by(county_name) %>%
  arrange(date) %>%
  mutate(
    lf_12ma = sapply(seq_along(labor_force), function(i) {
      if (i < 12) return(NA_real_)
      w <- labor_force[(i - 11):i]
      if (sum(!is.na(w)) == 12) mean(w) else NA_real_
    })
  ) %>%
  group_by(county_name) %>%
  mutate(
    base_val = lf_12ma[date == as.Date("2022-01-01")][1],
    lf_index = (lf_12ma / base_val) * 100
  ) %>%
  ungroup() %>%
  filter(date >= as.Date("2022-01-01"))

p_owl_lf <- ggplot(df_owl_lf, aes(x = date, y = lf_index, color = county_name, linewidth = county_name)) +
  geom_hline(yintercept = 100, linetype = "dashed", color = COLOR_SLATE, alpha = 0.5) +
  geom_line(na.rm = TRUE) +
  scale_color_manual(values = c("OWL Corridor" = COLOR_CORRIDOR, "Oakland County" = COLOR_OAKLAND, "Livingston County" = COLOR_LIVINGSTON, "Washtenaw County" = COLOR_WASHTENAW, "Michigan (Statewide)" = COLOR_MICHIGAN)) +
  scale_linewidth_manual(values = c("OWL Corridor" = 1.2, "Oakland County" = 0.8, "Livingston County" = 0.8, "Washtenaw County" = 0.8, "Michigan (Statewide)" = 0.8)) +
  scale_y_continuous(labels = label_number(accuracy = 1)) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  theme_compass() +
  labs(title = "OWL Corridor Labor Force Capacity Expansion", subtitle = "12-Month Moving Average Index (Jan 2022 = 100)", caption = "Source: U.S. Bureau of Labor Statistics (LAUS)", x = NULL, y = "Labor Force Index")

ggsave(file.path(PLOTS_DIR, "laus_labor_force_indexed_12ma.png"), plot = p_owl_lf, width = 8, height = 4.5, dpi = 300)

# ------------------------------------------------------------------------------
# M3. STATEWIDE SEASONALLY ADJUSTED (SA) MI VS US UNEMPLOYMENT RATE
# ------------------------------------------------------------------------------
cat("[3/4] Rendering: SA Michigan vs. US Unemployment Rate...\n")
df_sa_unemp <- dbGetQuery(con, "
  SELECT CAST(observation_date AS DATE) AS date, mi_unemp_rate_sa, us_unemp_rate_sa
  FROM vw_mi_vs_us_unemployment
  WHERE observation_date >= '2019-01-01'
  ORDER BY observation_date ASC
")

p_sa_unemp <- ggplot(df_sa_unemp, aes(x = date)) +
  geom_line(aes(y = mi_unemp_rate_sa, color = "Michigan (SA)"), linewidth = 1.1) +
  geom_line(aes(y = us_unemp_rate_sa, color = "United States (SA)"), linewidth = 1.0, linetype = "dashed") +
  scale_color_manual(values = c("Michigan (SA)" = COLOR_NAVY, "United States (SA)" = COLOR_SLATE)) +
  scale_y_continuous(labels = label_percent(scale = 1, accuracy = 0.1)) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  theme_compass() +
  labs(title = "Michigan vs. U.S. Unemployment Rate Benchmark", subtitle = "Seasonally Adjusted Monthly Rates (%)", caption = "Source: U.S. Bureau of Labor Statistics / FRED", x = NULL, y = "Unemployment Rate")

ggsave(file.path(PLOTS_DIR, "mi_vs_us_unemployment.png"), plot = p_sa_unemp, width = 8, height = 4.5, dpi = 300)

# ------------------------------------------------------------------------------
# M4. MACRO INDICATORS & CONSUMER SENTIMENT YOY
# ------------------------------------------------------------------------------
cat("[4/4] Rendering: Macro Indicators & Consumer Sentiment YoY...\n")
df_macro <- dbGetQuery(con, "
  SELECT CAST(observation_date AS DATE) AS date, series_title, yoy_change
  FROM vw_fred_macro_yoy
  WHERE observation_date >= '2021-01-01'
  ORDER BY observation_date ASC
")

p_macro <- ggplot(df_macro, aes(x = date, y = yoy_change, color = series_title)) +
  geom_hline(yintercept = 0, linetype = "solid", color = COLOR_GRID, linewidth = 0.8) +
  geom_line(linewidth = 1.0, na.rm = TRUE) +
  scale_y_continuous(labels = label_percent(scale = 1, accuracy = 1)) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  theme_compass() +
  labs(title = "Macroeconomic Sentiment & Price Index Movements", subtitle = "Year-over-Year Percentage Change (%)", caption = "Source: FRED / University of Michigan Consumer Sentiment", x = NULL, y = "YoY Change")

ggsave(file.path(PLOTS_DIR, "macro_yoy_trends.png"), plot = p_macro, width = 8, height = 4.5, dpi = 300)

cat("========================================================\n")
cat(" [✓] ALL 4 MONTHLY PUBLICATION PLOTS EXPORTED CLEANLY\n")
cat("========================================================\n")