# ==============================================================================
# THE COMPASS LENS BRANDING ENGINE
# ==============================================================================

# 1. CENTRALIZED BRAND PALETTE
# Master Brand Palette for Counties & Regional Benchmarks
COMPASS_PALETTE <- c(
  "OWL Corridor"         = "#6B21A8", # Plum Purple (Hero Regional Aggregate)
  "Washtenaw"            = "#00274C", # Michigan Navy (U of M Anchor)
  "Oakland"              = "#15803D", # Forest Green (County Baseline)
  "Livingston"           = "#C2410C", # Institutional Burnt Orange (Brighton Anchor)
  "Michigan (Statewide)" = "#475569", # Muted Slate (Macro Benchmark)
  "United States"        = "#94A3B8"  # Cool Gray (National Baseline)
)

# Define Line Styles
owl_linetypes <- c(
  "OWL Corridor"         = "solid",
  "Washtenaw"            = "solid",
  "Oakland"              = "solid",
  "Livingston"           = "solid",
  "Michigan (Statewide)" = "dashed",
  "United States"        = "dotted"
)

# Line Width Hierarchy
owl_widths <- c(
  "OWL Corridor"         = 1.2,  # Thicker line to draw the eye
  "Washtenaw"            = 0.9,
  "Oakland"              = 0.9,
  "Livingston"           = 0.9,
  "Michigan (Statewide)" = 0.8,
  "United States"        = 0.8
)

# Line Alpha Hierarchy (Mutes County Lines to Highlight Region)
owl_alphas <- c(
  "OWL Corridor"         = 1.00, # Fully opaque hero line
  "Washtenaw"            = 0.60,
  "Oakland"              = 0.60,
  "Livingston"           = 0.60,
  "Michigan (Statewide)" = 0.50,
  "United States"        = 0.40
)

# 2. CUSTOM THEME FUNCTION FOR REUSE
theme_compass <- function(base_size = 11) {
  theme_minimal(base_size = base_size) %+replace% 
    theme(
      # Typography & Titles
      plot.title    = element_text(face = "bold", size = 14, color = "#1B365D", margin = margin(b = 4)),
      plot.subtitle = element_text(size = 10.5, color = "gray40", margin = margin(b = 15)),
      plot.caption  = element_text(size = 8, color = "gray50", hjust = 1, margin = margin(t = 10)),
      
      # Legend Configuration
      legend.position = "bottom",
      legend.title    = element_blank(), # Set to blank to ensure seamless scale merging
      legend.text     = element_text(size = 9, color = "black"),
      
      # Axis Elements
      axis.title.y  = element_text(size = 9.5, face = "bold", color = "#1B365D", margin = margin(r = 10)),
      axis.title.x  = element_blank(),
      axis.text     = element_text(size = 9, color = "black"),
      
      # Clean Grid Layouts
      panel.grid.minor   = element_blank(),
      panel.grid.major.y = element_line(color = "gray92", linewidth = 0.5),
      panel.grid.major.x = element_blank(),
      
      # Background Cleanliness
      plot.background  = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA)
    )
}