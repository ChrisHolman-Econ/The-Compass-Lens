# ==============================================================================
# PROJECT: THE COMPASS LENS
# SCRIPT:  plot_generate.R
# PURPOSE: Generate publication-ready trend lines for the OWL Corridor
# ==============================================================================

library(zoo)
library(data.table)
library(tidyverse)
library(scales)

# 1. PATH SAFETY LAYER
if (Sys.getenv("RSTUDIO") == "1") {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
  setwd("..") 
} else {
  BASE_PATH <- "/Users/christopherholman/Library/Mobile Documents/com~apple~CloudDocs/The-Compass-Lens"
  setwd(BASE_PATH)
}

RAW_DIR       <- "data/raw"
PROCESSED_DIR <- "data/processed"
PLOT_DIR      <- "plots"

if (!dir.exists(PLOT_DIR)) dir.create(PLOT_DIR, recursive = TRUE)

# ==============================================================================
# 2. LOAD BRANDING THEME & ENSURE REGIONAL PALETTE MAPPING
# ==============================================================================
source("pipeline/theme_compass.R")

cat("========================================================\n")
cat("LAUNCHING COMPASS LENS VISUALIZATION PIPELINE\n")
cat("WORKING DIR:", getwd(), "\n") 
cat("========================================================\n\n")


# ==============================================================================
# 3. DATA INGESTION & STRUCTURAL TRANSFORMATION
# ==============================================================================
cat("[*] Ingesting master matrix, completing gaps, and calculating 12-MAs...\n")

plot_df <- read_rds(file.path(PROCESSED_DIR, "master_county_pulse.rds")) %>%
  filter(date >= as.Date("2021-01-01")) %>%
  group_by(county_name) %>%
  complete(date = seq.Date(min(date), max(date), by = "1 month")) %>%
  ungroup() %>%
  pivot_longer(
    cols      = c(unemployment_rate, unemployed_count, employed_count, labor_force),
    names_to  = "metric",
    values_to = "value"
  ) %>%
  group_by(county_name, metric) %>%
  arrange(date) %>%
  mutate(
    # 1. Temporarily interpolate missing raw values to enable downstream 12-MA math
    value_interp = na.approx(value, x = date, na.rm = FALSE),
    
    # 2. Compute 12-MA on the filled series (populates Nov 2025 - May 2026)
    value_12ma   = rollmean(value_interp, k = 12, fill = NA, align = "right"),
    
    # 3. RESTORE VISUAL BREAK: Re-assign NA to 12-MA wherever raw value was NA
    value_12ma   = if_else(is.na(value), NA_real_, value_12ma)
  ) %>%
  select(-value_interp) %>%
  ungroup()


# ==============================================================================
# 4. CHART 1: UNEMPLOYMENT RATE TRAJECTORY
# ==============================================================================
cat("[*] Plotting Unemployment Rate Trajectories...\n")

ur_data <- plot_df %>% 
  filter(metric == "unemployment_rate" & date >= as.Date("2022-01-01"))

# Find latest month with actual non-NA values for terminal dots
latest_ur_dots <- ur_data %>%
  filter(!is.na(value)) %>%
  group_by(county_name) %>%
  filter(date == max(date)) %>%
  ungroup()

# Define alpha/transparency hierarchy in your plot setup
owl_alphas <- c(
  "Livingston"         = 0.45,
  "Oakland"            = 0.45,
  "Washtenaw"          = 0.45,
  "OWL Corridor" = 1.00   # Hero line stays fully opaque
)

p_ur <- ggplot(ur_data, aes(
  x = date, 
  y = value, 
  color = county_name, 
  linetype = county_name, 
  linewidth = county_name,
  alpha = county_name   # Add alpha mapping
)) +
  geom_line(na.rm = FALSE) +
  geom_point(data = latest_ur_dots, size = 2.5, show.legend = FALSE) +
  
  scale_y_continuous(labels = label_percent(scale = 1), breaks = seq(0, 10, by = 1)) +
  scale_x_date(date_breaks = "6 months", date_labels = "%b '%y") +
  
  scale_color_manual(values = COMPASS_PALETTE) +
  scale_linetype_manual(values = owl_linetypes) +
  scale_linewidth_manual(values = owl_widths) +
  scale_alpha_manual(values = owl_alphas) +  # Applies the muted county effect
  
  labs(
    title    = "Unemployment Rate Trajectories: OWL Corridor",
    subtitle = "Post-pandemic structural labor market normalization (Jan 2022 - Present)",
    y        = "Unemployment Rate",
    color    = "Area",
    linetype = "Area",
    linewidth= "Area",
    alpha    = "Area",  # Merges alpha seamlessly into the main legend
    caption  = "Source: Bureau of Labor Statistics (LAUS, NSA) | Processed via The Compass Lens"
  ) +
  theme_compass()

ggsave(file.path(PLOT_DIR, "laus_unemployment_rates.png"), plot = p_ur, width = 8, height = 4.5, dpi = 300)


# ==============================================================================
# 5. CHART 2: INDEXED LABOR FORCE (12-MA SMOOTHED BASELINE)
# ==============================================================================
cat("[*] Plotting Relative Labor Force Expansion (12-MA Smoothed Index)...\n")

indexed_lf <- plot_df %>%
  filter(metric == "labor_force") %>%
  filter(date >= as.Date("2022-01-01")) %>%
  group_by(county_name) %>%
  arrange(date) %>%
  mutate(
    indexed_val = (value_12ma / value_12ma[date == as.Date("2022-01-01")]) * 100
  ) %>%
  ungroup()

# Find latest month with valid 12-MA values for terminal dots
latest_lf_dots <- indexed_lf %>%
  filter(!is.na(indexed_val)) %>%
  group_by(county_name) %>%
  filter(date == max(date)) %>%
  ungroup()

p_lf <- ggplot(indexed_lf, aes(x = date, y = indexed_val, color = county_name, linetype = county_name, linewidth = county_name)) +
  geom_hline(yintercept = 100, linetype = "dashed", color = "gray50", linewidth = 0.5) +
  
  # PASS FULL DATASET: ggplot2 automatically leaves a visual gap at NA (Oct 2025)
  geom_line(alpha = 0.95, na.rm = FALSE) +
  geom_point(data = latest_lf_dots, size = 2.5, show.legend = FALSE) +
  
  scale_y_continuous(labels = label_number(accuracy = 1)) +
  scale_x_date(date_breaks = "6 months", date_labels = "%b '%y") +
  
  scale_color_manual(values = COMPASS_PALETTE) +
  scale_linetype_manual(values = owl_linetypes) +
  scale_linewidth_manual(values = owl_widths) +
  
  labs(
    title    = "Labor Force Expansion Trends (12-Month Moving Average)",
    subtitle = "Relative capacity shifts, indexed to smoothed January 2022 baseline = 100",
    y        = "Indexed Growth Baseline",
    color    = "Area",
    linetype = "Area",
    linewidth= "Area",
    caption  = "Source: Bureau of Labor Statistics (LAUS, NSA) | 12-MA & Indexing via The Compass Lens"
  ) +
  theme_compass()

ggsave(file.path(PLOT_DIR, "laus_labor_force_indexed_12ma.png"), plot = p_lf, width = 8, height = 4.5, dpi = 300)

cat("\n========================================================\n")
cat("[✓] SUCCESS: Brand graphics generated and saved to /plots\n")
cat("========================================================\n")