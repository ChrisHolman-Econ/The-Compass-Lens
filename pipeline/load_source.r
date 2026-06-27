# ==============================================================================
# PROJECT: The Compass Lens
# SCRIPT:  01_load_source.R
# PURPOSE: Extract raw macro and regional flat-files directly from source APIs/FTPs
# AUTHORS: Chris Holman
# ==============================================================================

library(data.table)

# ------------------------------------------------------------------------------
# 1. ENVIRONMENT CONFIGURATION & DIRECTORY SAFETIES
# ------------------------------------------------------------------------------

# Define project directories relative to the workspace root
RAW_DIR       <- "data/raw"
PROCESSED_DIR <- "data/processed"

# Programmatically build folders if they do not exist locally
if (!dir.exists(RAW_DIR)) dir.create(RAW_DIR, recursive = TRUE)
if (!dir.exists(PROCESSED_DIR)) dir.create(PROCESSED_DIR, recursive = TRUE)

# BLS servers block requests missing modern User-Agent/Contact headers. 
# We override the R default to prevent 403 Forbidden errors.
options(HTTPUserAgent = "TheCompassLens/1.0 (holman_chris@icloud.com; Public Benefit Research Pipeline)")

# ------------------------------------------------------------------------------
# 2. DEFINE MASTER FILE MANIFEST (THE DATA TARGETS)
# ------------------------------------------------------------------------------

# Mapping out exact source text assets for bulk download
data_manifest <- list(
  # Local Area Unemployment Statistics (All US Counties)
  laus_county = "https://download.bls.gov/pub/time.series/la/la.data.64.County",
  
  # Current Employment Statistics (State & Metro Area Payrolls)
  ces_state_area = "https://download.bls.gov/pub/time.series/sm/sm.data.1.AllData",
  
  # Job Openings and Labor Turnover Survey (Regional/National Tracks)
  jolts_regional = "https://download.bls.gov/pub/time.series/jt/jt.data.1.AllItems",
  
  # Quarterly Census of Employment and Wages (Michigan 2025/2026 Baseline)
  # Note: QCEW flat time-series uses 'en'. We capture the complete national track.
  qcew_structural = "https://download.bls.gov/pub/time.series/en/en.data.1.AllData"
)

# ------------------------------------------------------------------------------
# 3. FIXED AUTOMATED EXTRACT & CACHE PIPELINE (BYPASSING BLS BLOCKS)
# ------------------------------------------------------------------------------

cat("========================================================\n")
cat("LAUNCHING SOURCE EXTRACTION: THE COMPASS LENS\n")
cat("========================================================\n\n")

# Define the exact header vector that cleared the Akamai firewall in Bash
bls_headers <- c(
  "User-Agent" = "TheCompassLens/1.0 (Public Benefit Pipeline; holman_chris@icloud.com)"
)

for (dataset_name in names(data_manifest)) {
  target_url       <- data_manifest[[dataset_name]]
  destination_path <- file.path(RAW_DIR, paste0(dataset_name, ".txt"))
  
  cat(paste0("[*] Pulling ", dataset_name, " via system curl...\n"))
  
  tryCatch({
    # 1. Download directly using Mac's native curl utility
    download.file(
      url      = target_url,
      destfile = destination_path,
      method   = "curl",
      extra    = paste0('-H "User-Agent: ', bls_headers["User-Agent"], '"'),
      quiet    = FALSE
    )
    
    # 2. Instantly read the downloaded local text file into an R data.frame/data.table
    # fill = TRUE handles any trailing whitespace anomalies in raw BLS files cleanly
    dt_cache <- fread(destination_path, sep = "\t", header = TRUE, fill = TRUE)
    
    cat(paste0(" [✓] Loaded into memory: ", dataset_name, " matrix (", nrow(dt_cache), " rows)\n\n"))
    
    # Optional: If you want to keep the data frames explicitly alive in your current 
    # R global environment loop, you can assign them dynamically:
    # assign(paste0("raw_", dataset_name), dt_cache, envir = .GlobalEnv)
    
  }, error = function(e) {
    cat(paste0(" [❌] R Extraction Error on: ", dataset_name, "\n"))
    cat(paste0("      Message: ", e$message, "\n\n"))
  })
}

# ------------------------------------------------------------------------------
# 4. CAPTURE CONSUMER SENTIMENT VIA FRED API
# ------------------------------------------------------------------------------
cat("[*] Extracting University of Michigan Consumer Sentiment Index via FRED...\n")

# Setup FRED request strings
# Series ID 'UMCSENT' tracks the core University of Michigan Sentiment value
FRED_API_KEY <- Sys.getenv("FRED_API_KEY") 

if (FRED_API_KEY == "") {
  # Fallback: Pull directly from the open CSV web export if no API token is stored
  sentiment_url <- "https://fred.stlouisfed.org/graph/fredgraph.csv?id=UMCSENT"
  cat("     ! No local FRED_API_KEY detected in .Renviron. Falling back to public URL.\n")
} else {
  sentiment_url <- paste0("https://api.stlouisfed.org/fred/series/observations?series_id=UMCSENT&api_key=", 
                          FRED_API_KEY, "&file_type=json")
}

tryCatch({
  if (grepl("csv", sentiment_url)) {
    sentiment_data <- fread(sentiment_url)
  } else {
    # If using JSON API, import jsonlite on the fly to unpack the observation nodes
    if (!requireNamespace("jsonlite", quietly = TRUE)) install.packages("jsonlite")
    raw_json <- jsonlite::fromJSON(sentiment_url)
    sentiment_data <- as.data.table(raw_json$observations)
  }
  
  fwrite(sentiment_data, file = file.path(RAW_DIR, "consumer_sentiment.csv"))
  cat(" [✓] Successfully cached Consumer Sentiment track.\n\n")
  
}, error = function(e) {
  cat(" [❌] ERROR: Consumer Sentiment extraction stalled.\n")
  cat(paste0("      Message: ", e$message, "\n\n"))
})

cat("========================================================\n")
cat(" PIPELINE STEP 01 COMPLETE: DATA ASSETS SECURED LOCAL\n")
cat("========================================================\n")