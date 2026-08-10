# ==============================================================================
# UTILITY: THEME & COLOR PALETTE DEFINITIONS (THE COMPASS LENS)
# ==============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
})

# ------------------------------------------------------------------------------
# 1. COLOR PALETTE DEFINITIONS
# ------------------------------------------------------------------------------
COLOR_NAVY       <- "#1B365D" # Primary / WCC Navy
COLOR_LIGHT_BLUE <- "#4B9CD3" # Secondary Accent
COLOR_SLATE      <- "#5C768D" # Muted / Grid Details
COLOR_TEXT_DARK  <- "#222222" # Dark Neutral
COLOR_GRID       <- "#E5E9F0" # Subtle Gridlines

# Regional Geographic Palette
COLOR_CORRIDOR   <- "#6B21A8" # Purple (OWL Corridor Aggregate)
COLOR_OAKLAND    <- "#10B981" # Green
COLOR_LIVINGSTON <- "#F97316" # Orange
COLOR_WASHTENAW  <- "#1B365D" # Navy
COLOR_MICHIGAN   <- "#9CA3AF" # Light Gray Baseline

# Named vector for consistent ggplot mapping across all plot scripts
PALETTE_OWL_CORRIDOR <- c(
  "OWL Corridor"         = COLOR_CORRIDOR,
  "Oakland County"       = COLOR_OAKLAND,
  "Livingston County"    = COLOR_LIVINGSTON,
  "Washtenaw County"     = COLOR_WASHTENAW,
  "Michigan (Statewide)" = COLOR_MICHIGAN
)

LINEWIDTH_OWL_CORRIDOR <- c(
  "OWL Corridor"         = 1.2,
  "Oakland County"       = 0.8,
  "Livingston County"    = 0.8,
  "Washtenaw County"     = 0.8,
  "Michigan (Statewide)" = 0.8
)

# ------------------------------------------------------------------------------
# 2. GGPLOT2 THEME FUNCTION
# ------------------------------------------------------------------------------
theme_compass <- function(base_size = 11, base_family = "") {
  theme_minimal(base_size = base_size, base_family = base_family) %+replace%
    theme(
      plot.title        = element_text(face = "bold", size = rel(1.15), color = COLOR_TEXT_DARK, margin = margin(b = 4)),
      plot.subtitle     = element_text(size = rel(0.95), color = COLOR_SLATE, margin = margin(b = 10)),
      plot.caption      = element_text(size = rel(0.75), color = COLOR_SLATE, hjust = 0, margin = margin(t = 8)),
      panel.grid.major  = element_line(color = COLOR_GRID, linewidth = 0.4),
      panel.grid.minor  = element_blank(),
      axis.title        = element_text(size = rel(0.85), face = "bold", color = COLOR_TEXT_DARK),
      axis.text         = element_text(size = rel(0.85), color = COLOR_TEXT_DARK),
      legend.position   = "bottom",
      legend.title      = element_blank(),
      legend.text       = element_text(size = rel(0.85), color = COLOR_TEXT_DARK),
      strip.background  = element_blank(),
      strip.text        = element_text(face = "bold", size = rel(0.95), color = COLOR_TEXT_DARK)
    )
}