library(quarto)
library(readr)
library(here)
library(fs) # Standard utility for directory creation and file management

# 1. Define output directory and ensure it exists
output_dir <- here("output", "releases")
dir_create(output_dir)

# 2. Read master data to find the latest available reporting month
master_data <- read_rds(here("data", "processed", "master_county_pulse.rds"))
latest_date <- max(master_data$date)

# Format for file naming (e.g., "2026-04")
date_stamp  <- format(latest_date, "%Y-%m")
doc_filename <- paste0(date_stamp, "_compass_lens.docx")

cat("Rendering release for:", date_stamp, "...\n")

# 3. Render the report dynamically using quarto
# Quarto builds the file locally first
quarto_render(
  input         = here("templates", "rpt_monthly_pulse.qmd"),
  output_format = "docx",
  output_file   = doc_filename
)

# 4. Move the finished report from the template directory into your output archive
temp_rendered_location <- here("templates", doc_filename)
final_destination      <- file.path(output_dir, doc_filename)

if (file_exists(temp_rendered_location)) {
  file_move(temp_rendered_location, final_destination)
  cat("Successfully generated and archived:", final_destination, "\n")
} else {
  cat("Warning: Render completed, but file was not found at expected temporary path.\n")
}