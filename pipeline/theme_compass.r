# ==============================================================================
# THE COMPASS LENS BRANDING ENGINE
# ==============================================================================

# 1. CENTRALIZED BRAND PALETTE
# Navy handles structural/baseline elements; Gold highlights specific series
COMPASS_PALETTE <- c(
  "Oakland"    = "#1B365D",  # Deep Navy Blue
  "Washtenaw"  = "#D4AF37",  # Metallic Gold Accent
  "Livingston" = "#4A5568"   # Slate Gray (Muted secondary baseline)
)

# 2. CUSTOM THEME FUNCTION FOR REUSE
theme_compass <- function(base_size = 11) {
  theme_minimal(base_size = base_size) %+replace% # %+replace% overrides defaults safely
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
      axis.title.x  = element_blank(), # Keep clean since dates are self-explanatory
      axis.text     = element_text(size = 9, color = "black"),
      
      # Clean Grid Layouts (Drop vertical lines to emphasize the horizontal scale)
      panel.grid.minor   = element_blank(),
      panel.grid.major.y = element_line(color = "gray92", linewidth = 0.5),
      panel.grid.major.x = element_blank(),
      
      # Background Cleanliness
      plot.background  = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA)
    )
}