# ==============================================================================
# PIPELINE STEP 09: ANNUAL VISUALIZATION ENGINE (STRUCTURAL BENCHMARKS & POP)
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
cat("GENERATING ANNUAL BENCHMARK PLOTS (POPULATION & STRUCTURAL)\n")
cat("========================================================\n\n")

# Connect to DuckDB if con does not exist
if (!exists("con") || !dbIsValid(con)) {
  DB_PATH <- here("data", "duckdb", "compass_lens.duckdb")
  con <- dbConnect(duckdb::duckdb(), DB_PATH, read_only = TRUE)
}

# ------------------------------------------------------------------------------
# A1. COUNTY POPULATION SHIFTS & GROWTH INDEX (CENSUS PEP)
# ------------------------------------------------------------------------------
cat("[1/3] Rendering: County Population Shifts & Growth Index...\n")

df_pop <- dbGetQuery(con, "
  SELECT 
    CAST(year AS INTEGER) AS year,
    county_name,
    population
  FROM vw_census_pop_annual
  WHERE year >= 2015
  ORDER BY county_name, year ASC
") %>%
  group_by(county_name) %>%
  mutate(
    pop_index = (population / population[year == 2015][1]) * 100
  ) %>%
  ungroup()

p_pop <- ggplot(df_pop, aes(x = year, y = pop_index, color = county_name, linewidth = county_name)) +
  geom_hline(yintercept = 100, linetype = "dashed", color = COLOR_SLATE, alpha = 0.5) +
  geom_line(na.rm = TRUE) +
  geom_point(size = 2, na.rm = TRUE) +
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
  scale_y_continuous(labels = label_number(accuracy = 0.5)) +
  scale_x_continuous(breaks = seq(2015, max(df_pop$year, na.rm = TRUE), by = 2)) +
  theme_compass() +
  labs(
    title = "Regional Population Trajectories & Growth Velocity",
    subtitle = "Annual Population Estimates Index (2015 = 100)",
    caption = "Source: U.S. Census Bureau (Population Estimates Program PEP)\nNote: Baseline of 100 indicates 2015 total population level.",
    x = NULL,
    y = "Population Index (2015 = 100)"
  )

file_pop <- file.path(PLOTS_DIR, "annual_population_index.png")
ggsave(file_pop, plot = p_pop, width = 8, height = 4.5, dpi = 300)
cat(sprintf(" [✓] Saved: %s\n\n", file_pop))

# ------------------------------------------------------------------------------
# A2. LONG-TERM STRUCTURAL UNEMPLOYMENT (ANNUAL BENCHMARK AVERAGES)
# ------------------------------------------------------------------------------
cat("[2/3] Rendering: Long-Term Annual Unemployment Benchmark Averages...\n")

df_annual_unemp <- dbGetQuery(con, "
  SELECT 
    CAST(year AS INTEGER) AS year,
    county_name,
    AVG(value) AS annual_unemp_rate
  FROM vw_laus_owl_corridor
  WHERE measure_type IN ('Unemployment Rate', 'unemployment_rate')
  GROUP BY year, county_name
  HAVING COUNT(month) = 12
  ORDER BY year ASC
")

p_annual_unemp <- ggplot(df_annual_unemp, aes(x = year, y = annual_unemp_rate, fill = county_name)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  scale_fill_manual(values = c(
    "OWL Corridor"        = COLOR_CORRIDOR,
    "Oakland County"      = COLOR_OAKLAND,
    "Livingston County"   = COLOR_LIVINGSTON,
    "Washtenaw County"    = COLOR_WASHTENAW,
    "Michigan (Statewide)"= COLOR_MICHIGAN
  )) +
  scale_y_continuous(labels = label_percent(scale = 1, accuracy = 0.1)) +
  scale_x_continuous(breaks = seq(min(df_annual_unemp$year, na.rm = TRUE), max(df_annual_unemp$year, na.rm = TRUE), by = 1)) +
  theme_compass() +
  labs(
    title = "Annual Average Unemployment Rate Benchmarks",
    subtitle = "12-month average structural unemployment rate comparison (%)",
    caption = "Source: U.S. Bureau of Labor Statistics (LAUS Annual Benchmarks)",
    x = NULL,
    y = "Annual Average Rate"
  )

file_annual_unemp <- file.path(PLOTS_DIR, "annual_unemployment_benchmark.png")
ggsave(file_annual_unemp, plot = p_annual_unemp, width = 9, height = 4.5, dpi = 300)
cat(sprintf(" [✓] Saved: %s\n\n", file_annual_unemp))

# ------------------------------------------------------------------------------
# A3. STRUCTURAL LABOR FORCE PARTICIPATION / RATIOS
# ------------------------------------------------------------------------------
cat("[3/3] Rendering: Structural Labor Force Supply Ratios...\n")

df_lf_ratio <- dbGetQuery(con, "
  SELECT 
    CAST(year AS INTEGER) AS year,
    county_name,
    AVG(value) AS annual_avg_lf
  FROM vw_laus_owl_corridor
  WHERE measure_type IN ('Labor Force', 'labor_force')
    AND year >= 2018
  GROUP BY year, county_name
  ORDER BY year ASC
")

p_lf_ratio <- ggplot(df_lf_ratio, aes(x = year, y = annual_avg_lf, color = county_name)) +
  geom_line(linewidth = 1.1, na.rm = TRUE) +
  geom_point(size = 2.5, na.rm = TRUE) +
  scale_color_manual(values = c(
    "OWL Corridor"        = COLOR_CORRIDOR,
    "Oakland County"      = COLOR_OAKLAND,
    "Livingston County"   = COLOR_LIVINGSTON,
    "Washtenaw County"    = COLOR_WASHTENAW,
    "Michigan (Statewide)"= COLOR_MICHIGAN
  )) +
  scale_y_continuous(labels = label_comma()) +
  scale_x_continuous(breaks = seq(2018, max(df_lf_ratio$year, na.rm = TRUE), by = 1)) +
  theme_compass() +
  labs(
    title = "Structural Labor Force Supply Trajectory",
    subtitle = "Annual average total labor force level (Persons)",
    caption = "Source: U.S. Bureau of Labor Statistics (LAUS Benchmarked Series)",
    x = NULL,
    y = "Average Available Labor Force"
  )

file_lf_ratio <- file.path(PLOTS_DIR, "annual_labor_force_levels.png")
ggsave(file_lf_ratio, plot = p_lf_ratio, width = 8, height = 4.5, dpi = 300)
cat(sprintf(" [✓] Saved: %s\n\n", file_lf_ratio))

cat("========================================================\n")
cat(" [✓] ALL ANNUAL PUBLICATION PLOTS EXPORTED CLEANLY\n")
cat("========================================================\n")