library(quarto)
library(readr)
library(here)

# 1. Read your master data to find the latest available reporting month
master_data <- read_rds(here("data", "processed", "master_county_pulse.rds"))
latest_date <- max(master_data$date)

# Format for file naming (e.g., "2026-04") and document parameters
date_stamp  <- format(latest_date, "%Y-%m")

# 2. Define standard output filenames for your archives
doc_filename <- paste0(date_stamp, "_compass_lens.docx")

# 3. Render the report dynamically using the quarto package
cat("Rendering release for:", date_stamp, "...\n")

quarto_render(
  input = here("reports", "index.qmd"),
  output_format = "docx",
  output_file = doc_filename
)

cat("Successfully generated:", doc_filename, "\n")