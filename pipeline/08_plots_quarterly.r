# ==============================================================================
# PIPELINE STEP 08: QUARTERLY VISUALIZATION ENGINE (QCEW & INDUSTRY ANALYTICS)
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
cat("GENERATING QUARTERLY PUBLICATION PLOTS (QCEW & WAGES)\n")
cat("========================================================\n\n")

# Connect to DuckDB if con does not exist
if (!exists("con") || !dbIsValid(con)) {
  DB_PATH <- here("data", "duckdb", "compass_lens.duckdb")
  con <- dbConnect(duckdb::duckdb(), DB_PATH, read_only = TRUE)
}

# ------------------------------------------------------------------------------
# Q1. TOTAL COVERED EMPLOYMENT YOY GROWTH (OWL CORRIDOR VS. STATE)
# ------------------------------------------------------------------------------
cat("[1/3] Rendering: Quarterly Covered Employment YoY Growth...\n")

df_qcew_emp <- dbGetQuery(con, "
  SELECT 
    CAST(observation_date AS DATE) AS date,
    county_name,
    avg_monthly_employment,
    avg_monthly_employment_yoy
  FROM vw_qcew_owl_corridor
  WHERE industry_code = '10' -- Total, all industries
    AND observation_date >= '2021-01-01'
  ORDER BY observation_date ASC
")

p_qcew_emp <- ggplot(df_qcew_emp, aes(x = date, y = avg_monthly_employment_yoy, color = county_name, linewidth = county_name)) +
  geom_hline(yintercept = 0, linetype = "solid", color = COLOR_GRID, linewidth = 0.8) +
  geom_line(na.rm = TRUE) +
  scale_color_manual(values = c(
    "OWL Corridor"        = COLOR_CORRIDOR,
    "Oakland County"      = COLOR_OAKLAND,
    "Livingston County"   = COLOR_LIVINGSTON,
    "Washtenaw County"    = COLOR_WASHTENAW,
    "Michigan (Statewide)"= COLOR_MICHIGAN
  )) +
  scale_linewidth_manual(values = c(
    "OWL Corridor"        = 1.2,
    "Oakland County"      = 0.8,
    "Livingston County"   = 0.8,
    "Washtenaw County"    = 0.8,
    "Michigan (Statewide)"= 0.8
  )) +
  scale_y_continuous(labels = label_percent(scale = 100, accuracy = 0.1)) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  theme_compass() +
  labs(
    title = "Covered Payroll Employment YoY Expansion",
    subtitle = "Quarterly total employment growth rate across OWL Corridor counties (%)",
    caption = "Source: U.S. Bureau of Labor Statistics (QCEW)\nNote: Includes UI-covered total all-industry payroll employment.",
    x = NULL,
    y = "YoY Employment Change"
  )

file_qcew_emp <- file.path(PLOTS_DIR, "qcew_employment_yoy.png")
ggsave(file_qcew_emp, plot = p_qcew_emp, width = 8, height = 4.5, dpi = 300)
cat(sprintf(" [✓] Saved: %s\n\n", file_qcew_emp))

# ------------------------------------------------------------------------------
# Q2. AVERAGE WEEKLY WAGE TRENDS & INFLATION BENCHMARK
# ------------------------------------------------------------------------------
cat("[2/3] Rendering: Average Weekly Wage Trajectories...\n")

df_qcew_wage <- dbGetQuery(con, "
  SELECT 
    CAST(observation_date AS DATE) AS date,
    county_name,
    avg_weekly_wage
  FROM vw_qcew_owl_corridor
  WHERE industry_code = '10'
    AND observation_date >= '2021-01-01'
  ORDER BY observation_date ASC
")

p_qcew_wage <- ggplot(df_qcew_wage, aes(x = date, y = avg_weekly_wage, color = county_name, linewidth = county_name)) +
  geom_line(na.rm = TRUE) +
  scale_color_manual(values = c(
    "OWL Corridor"        = COLOR_CORRIDOR,
    "Oakland County"      = COLOR_OAKLAND,
    "Livingston County"   = COLOR_LIVINGSTON,
    "Washtenaw County"    = COLOR_WASHTENAW,
    "Michigan (Statewide)"= COLOR_MICHIGAN
  )) +
  scale_linewidth_manual(values = c(
    "OWL Corridor"        = 1.2,
    "Oakland County"      = 0.8,
    "Livingston County"   = 0.8,
    "Washtenaw County"    = 0.8,
    "Michigan (Statewide)"= 0.8
  )) +
  scale_y_continuous(labels = label_dollar(accuracy = 1)) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  theme_compass() +
  labs(
    title = "Average Weekly Wage Trajectories",
    subtitle = "Quarterly average weekly wage per worker across all covered industries ($)",
    caption = "Source: U.S. Bureau of Labor Statistics (QCEW)\nNote: Nominal weekly wage calculated as total quarterly wages divided by average employment.",
    x = NULL,
    y = "Average Weekly Wage"
  )

file_qcew_wage <- file.path(PLOTS_DIR, "qcew_average_weekly_wage.png")
ggsave(file_qcew_wage, plot = p_qcew_wage, width = 8, height = 4.5, dpi = 300)
cat(sprintf(" [✓] Saved: %s\n\n", file_qcew_wage))

# ------------------------------------------------------------------------------
# Q3. INDUSTRY SECTOR CONCENTRATION (LOCATION QUOTIENTS)
# ------------------------------------------------------------------------------
cat("[3/3] Rendering: Regional Industry Sector Concentration...\n")

# Query latest available quarter's sector breakdown
df_qcew_lq <- dbGetQuery(con, "
  SELECT 
    industry_title,
    location_quotient,
    avg_monthly_employment
  FROM vw_qcew_monthly_series
  WHERE observation_date = (SELECT MAX(observation_date) FROM vw_qcew_monthly_series)
    AND own_code = '5' -- Private Sector
    AND industry_code IN ('1012', '1013', '1021', '1022', '1023', '1024', '1025', '1026')
  ORDER BY location_quotient ASC
")

p_qcew_lq <- ggplot(df_qcew_lq, aes(x = location_quotient, y = reorder(industry_title, location_quotient))) +
  geom_vline(xintercept = 1.0, linetype = "dashed", color = COLOR_SLATE, linewidth = 0.8) +
  geom_col(fill = COLOR_NAVY, width = 0.65, alpha = 0.9) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.1))) +
  theme_compass() +
  labs(
    title = "Regional Sector Specialization (Location Quotients)",
    subtitle = "Employment concentration relative to U.S. baseline (LQ > 1.0 indicates regional specialization)",
    caption = "Source: U.S. Bureau of Labor Statistics (QCEW)\nBaseline LQ = 1.0 represents national average employment concentration.",
    x = "Location Quotient (LQ)",
    y = NULL
  )

file_qcew_lq <- file.path(PLOTS_DIR, "qcew_industry_location_quotient.png")
ggsave(file_qcew_lq, plot = p_qcew_lq, width = 8, height = 5, dpi = 300)
cat(sprintf(" [✓] Saved: %s\n\n", file_qcew_lq))

cat("========================================================\n")
cat(" [✓] ALL QUARTERLY PUBLICATION PLOTS EXPORTED CLEANLY\n")
cat("========================================================\n")