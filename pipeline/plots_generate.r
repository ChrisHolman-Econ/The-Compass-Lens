# ==============================================================================
# PROJECT: THE COMPASS LENS
# SCRIPT:  04_plot_laus_trends.R
# PURPOSE: Generate publication-ready trend lines for the OWL Corridor
#          with the updated institutional palette & line hierarchy.
# ==============================================================================

library(data.table)
library(tidyverse)
library(scales)

# 1. PATH SAFETY LAYER
if (Sys.getenv("RSTUDIO") == "1") {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
  setwd("..") 
} else {
  BASE_PATH <- "/Users/christopherholman/Library/Mobile Documents/com~apple~CloudDocs/The Compass Lens"
  setwd(BASE_PATH)
}

RAW_DIR       <- "data/raw"
PROCESSED_DIR <- "data/processed"
PLOT_DIR      <- "plots"

if (!dir.exists(PLOT_DIR)) dir.create(PLOT_DIR, recursive = TRUE)

cat("========================================================\n")
cat("LAUNCHING COMPASS LENS VISUALIZATION PIPELINE\n")
cat("WORKING DIR:", getwd(), "\n") 
cat("========================================================\n\n")


# ==============================================================================
# THE COMPASS LENS BRANDING ENGINE
# ==============================================================================

# 1. Centralized Brand Palette
COMPASS_PALETTE <- c(
  "OWL Corridor" = "#6B21A8", # Plum Purple (Subtle Regional Aggregate)
  "Washtenaw"    = "#00274C", # Michigan Navy (U of M Anchor)
  "Oakland"      = "#15803D", # Forest Green (County Baseline)
  "Livingston"   = "#C2410C", # Institutional Burnt Orange (Brighton Anchor)
  "Michigan"     = "#475569", # Muted Slate (Macro Benchmark)
  "United States"= "#94A3B8"  # Cool Gray (National Baseline)
)

# 2. Line Styles & Widths
owl_linetypes <- c(
  "OWL Corridor" = "solid",
  "Washtenaw"    = "solid",
  "Oakland"      = "solid",
  "Livingston"   = "solid",
  "Michigan"     = "dashed",
  "United States"= "dotted"
)

owl_widths <- c(
  "OWL Corridor" = 1.2,  # Thicker line to draw the eye
  "Washtenaw"    = 0.9,
  "Oakland"      = 0.9,
  "Livingston"   = 0.9,
  "Michigan"     = 0.8,
  "United States"= 0.8
)

# 3. Custom Reusable Theme Function
theme_compass <- function(base_size = 11) {
  theme_minimal(base_size = base_size) %+replace% 
    theme(
      # Typography & Titles
      plot.title    = element_text(face = "bold", size = 14, color = "#00274C", margin = margin(b = 4)),
      plot.subtitle = element_text(size = 10.5, color = "gray40", margin = margin(b = 15)),
      plot.caption  = element_text(size = 8, color = "gray50", hjust = 1, margin = margin(t = 10)),
      
      # Legend Configuration
      legend.position = "top",
      legend.title    = element_text(size = 9.5, face = "bold", color = "#00274C"),
      legend.text     = element_text(size = 9, color = "black"),
      
      # Axis Elements
      axis.title.y  = element_text(size = 9.5, face = "bold", color = "#00274C", margin = margin(r = 10)),
      axis.title.x  = element_blank(), 
      axis.text     = element_text(size = 9, color = "black"),
      
      # Clean Grid Layouts (Drop vertical lines to emphasize temporal flow)
      panel.grid.minor   = element_blank(),
      panel.grid.major.y = element_line(color = "gray92", linewidth = 0.5),
      panel.grid.major.x = element_blank(),
      
      # Background Cleanliness
      plot.background  = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA)
    )
}


# ==============================================================================
# 2. DATA INGESTION & STRUCTURAL TRANSFORMATION
# ==============================================================================

cat("[*] Ingesting wide master matrix and reshaping to long form...\n")

laus_metrics <- read_rds(file.path(PROCESSED_DIR, "master_county_pulse.rds")) %>%
  pivot_longer(
    cols = c(unemployment_rate, unemployed_count, employed_count, labor_force),
    names_to = "metric",
    values_to = "value"
  )

# Isolate post-pandemic macro landscape (January 2022 through present)
plot_df <- laus_metrics %>%
  filter(date >= as.Date("2022-01-01"))


# ==============================================================================
# 3. CHART 1: UNEMPLOYMENT RATE TRAJECTORY
# ==============================================================================

cat("[*] Plotting Unemployment Rate Trajectories...\n")

p_ur <- ggplot(filter(plot_df, metric == "unemployment_rate"), 
               aes(x = date, y = value, color = county_name, linetype = county_name, linewidth = county_name)) +
  geom_line(alpha = 0.9) +
  geom_point(data = filter(plot_df, metric == "unemployment_rate" & date == max(date)), 
             size = 2.5, show.legend = FALSE) +
  scale_y_continuous(labels = label_percent(scale = 1), breaks = seq(0, 10, by = 1)) +
  scale_x_date(date_breaks = "6 months", date_labels = "%b '%y") +
  scale_color_manual(values = COMPASS_PALETTE) +
  scale_linetype_manual(values = owl_linetypes) +
  scale_linewidth_manual(values = owl_widths) +
  labs(
    title = "Unemployment Rate Trajectory: OWL Corridor",
    subtitle = "Post-pandemic structural labor market normalization (Jan 2022 - Present)",
    y = "Unemployment Rate",
    color = "County",
    linetype = "County",
    linewidth = "County",
    caption = "Source: Bureau of Labor Statistics (LAUS) | Data Streamed via The Compass Lens"
  ) +
  theme_compass()

ggsave(file.path(PLOT_DIR, "laus_unemployment_rates.png"), plot = p_ur, width = 8, height = 4.5, dpi = 300)


# ==============================================================================
# 4. CHART 2: INDEXED LABOR FORCE POOL SHIFTS
# ==============================================================================

cat("[*] Plotting Relative Labor Force Capacity Expansion...\n")

indexed_lf <- plot_df %>%
  filter(metric == "labor_force") %>%
  group_by(county_name) %>%
  arrange(date) %>%
  mutate(indexed_val = (value / value[date == as.Date("2022-01-01")]) * 100) %>%
  ungroup()

p_lf <- ggplot(indexed_lf, 
               aes(x = date, y = indexed_val, color = county_name, linetype = county_name, linewidth = county_name)) +
  geom_hline(yintercept = 100, linetype = "dashed", color = "gray50", linewidth = 0.5) +
  geom_line(alpha = 0.9) +
  scale_y_continuous(labels = function(x) paste0(x, "%")) +
  scale_x_date(date_breaks = "6 months", date_labels = "%b '%y") +
  scale_color_manual(values = COMPASS_PALETTE) +
  scale_linetype_manual(values = owl_linetypes) +
  scale_linewidth_manual(values = owl_widths) +
  labs(
    title = "Labor Force Expansion Trends",
    subtitle = "Relative capacity shifts, indexed to January 2022 = 100",
    y = "Indexed Growth Baseline",
    color = "County",
    linetype = "County",
    linewidth = "County",
    caption = "Source: Bureau of Labor Statistics (LAUS) | Data Streamed via The Compass Lens"
  ) +
  theme_compass()

ggsave(file.path(PLOT_DIR, "laus_labor_force_indexed.png"), plot = p_lf, width = 8, height = 4.5, dpi = 300)

cat("\n========================================================\n")
cat("[✓] SUCCESS: Brand graphics generated and saved to /plots\n")
cat("========================================================\n")