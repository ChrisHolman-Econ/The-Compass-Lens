#==========================
# Run Pulse Pipeline
#==========================

UPDATE <- FALSE 

# Load data
if (UPDATE == TRUE) {
  source("pipeline/load_source.r")
} else {
  cat("[*] Skipping data pull. Using cached raw files in pipeline/raw/\n")
}

# Process & clean data
source("pipeline/prep_clean.r")

# Calculate metrics
source("pipeline/calc_metrics.r")

# Load Theme
source("pipeline/theme_compass.R")

# Generate plots
source("pipeline/plots_generate.r")

# Render Pulse Report
source("build_release.R")



