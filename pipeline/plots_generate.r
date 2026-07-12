# ==============================================================================
# PROJECT: THE COMPASS LENS
# SCRIPT:  04_plot_laus_trends.R
# PURPOSE: Generate publication-ready trend lines for the OWL Corridor
#          with custom Navy & Gold branding engine.
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

# Centralized Brand Palette
COMPASS_PALETTE <- c(
  "Oakland"    = "#1B365D",  # Deep Navy Blue (Primary Institutional)
  "Washtenaw"  = "#D4AF37",  # Metallic Gold (Sharp Accent)
  "Livingston" = "#4A5568"   # Slate Gray (Muted Secondary Baseline)
)

# Custom Reusable Theme Function
theme_compass <- function(base_size = 11) {
  theme_minimal(base_size = base_size) %+replace% 
    theme(
      # Typography & Titles
      plot.title    = element_text(face = "bold", size = 14, color = "#1B365D", margin = margin(b = 4)),
      plot.subtitle = element_text(size = 10.5, color = "gray40", margin = margin(b = 15)),
      plot.caption  = element_text(size = 8, color = "gray50", hjust = 1, margin = margin(t = 10)),
      
      # Legend Configuration
      legend.position = "top",
      legend.title    = element_text(size = 9.5, face = "bold", color = "#1B365D"),
      legend.text     = element_text(size = 9, color = "black"),
      
      # Axis Elements
      axis.title.y  = element_text(size = 9.5, face = "bold", color = "#1B365D", margin = margin(r = 10)),
      axis.title.x  = element_blank(), 
      axis.text     = element_text(size = 9, color = "black"),
      
      # Clean Grid Layouts (Drop vertical lines to emphasize temporal flow)
      panel.grid.minor   = element_blank(),
      panel.grid.major.y = element_line(color = "gray92", size = 0.5),
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
  # Safely pivot metrics from column headers into a long dataframe for ggplot mapping
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
               aes(x = date, y = value, color = county_name)) +
  geom_line(size = 1.2, alpha = 0.9) +
  geom_point(data = filter(plot_df, metric == "unemployment_rate" & date == max(date)), 
             size = 2.5, show.legend = FALSE) +
  scale_y_continuous(labels = label_percent(scale = 1), breaks = seq(0, 10, by = 1)) +
  scale_x_date(date_breaks = "6 months", date_labels = "%b '%y") +
  scale_color_manual(values = COMPASS_PALETTE) +
  labs(
    title = "Unemployment Rate Trajectory: OWL Corridor",
    subtitle = "Post-pandemic structural labor market normalization (Jan 2022 - Present)",
    y = "Unemployment Rate",
    color = "County",
    caption = "Source: Bureau of Labor Statistics (LAUS) | Data Streamed via The Compass Lens"
  ) +
  theme_compass()

ggsave(file.path(PLOT_DIR, "laus_unemployment_rates.png"), plot = p_ur, width = 8, height = 4.5, dpi = 300)


# ==============================================================================
# 4. CHART 2: INDEXED LABOR FORCE POOL SHIFTS
# ==============================================================================

cat("[*] Plotting Relative Labor Force Capacity Expansion...\n")

# Index local capacity to Jan 2022 = 100 to illustrate relative expansion rate scales
indexed_lf <- plot_df %>%
  filter(metric == "labor_force") %>%
  group_by(county_name) %>%
  arrange(date) %>%
  mutate(indexed_val = (value / value[date == as.Date("2022-01-01")]) * 100) %>%
  ungroup()

p_lf <- ggplot(indexed_lf, aes(x = date, y = indexed_val, color = county_name)) +
  geom_hline(yintercept = 100, linetype = "dashed", color = "gray50", size = 0.5) +
  geom_line(size = 1.2, alpha = 0.9) +
  scale_y_continuous(labels = function(x) paste0(x, "%")) +
  scale_x_date(date_breaks = "6 months", date_labels = "%b '%y") +
  scale_color_manual(values = COMPASS_PALETTE) +
  labs(
    title = "Labor Force Expansion Trends",
    subtitle = "Relative capacity shifts, indexed to January 2022 = 100",
    y = "Indexed Growth Baseline",
    color = "County",
    caption = "Source: Bureau of Labor Statistics (LAUS) | Data Streamed via The Compass Lens"
  ) +
  theme_compass()

ggsave(file.path(PLOT_DIR, "laus_labor_force_indexed.png"), plot = p_lf, width = 8, height = 4.5, dpi = 300)

cat("\n========================================================\n")
cat("[✓] SUCCESS: Brand graphics generated and saved to /plots\n")
cat("========================================================\n")