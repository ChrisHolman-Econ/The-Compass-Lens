# ==============================================================================
# SCRIPT:  02_load_bls.r
# PROJECT: The Compass Lens
# PURPOSE: Extract Michigan LAUS & QCEW datasets with httr2 retry logic.
# DEPENDENCIES: data.table, httr2, base R
# ==============================================================================

if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
if (!requireNamespace("data.table", quietly = TRUE)) install.packages("data.table")
if (!requireNamespace("httr2", quietly = TRUE)) install.packages("httr2")

library(data.table)
library(httr2)

# 1. PATH CONFIGURATION & HEADERS
# ------------------------------------------------------------------------------
RAW_ROOT <- here::here("data", "raw")
BLS_DIR  <- file.path(RAW_ROOT, "bls")

if (!dir.exists(BLS_DIR)) {
  dir.create(BLS_DIR, recursive = TRUE)
}

BLS_UA <- "TheCompassLens/1.0 (Public Benefit Pipeline; holman_chris@icloud.com)"

message("========================================================")
message("PROCESSING BLS DATASETS (MICHIGAN LAUS & QCEW)")
message("========================================================\n")

# 2. VERIFY / EXTRACT MICHIGAN LAUS
# ------------------------------------------------------------------------------
master_laus_path <- file.path(RAW_ROOT, "laus_county.txt")
laus_dest_path   <- file.path(BLS_DIR, "laus_michigan.tsv")

cat("[*] Extracting Michigan LAUS records from master county cache...\n")

if (file.exists(laus_dest_path) && file.info(laus_dest_path)$size > 1000) {
  dt_check <- fread(laus_dest_path, select = 1)
  cat(sprintf(" [✓] LAUS cached file verified (%s rows).\n\n", 
              format(nrow(dt_check), big.mark = ",")))
} else if (file.exists(master_laus_path)) {
  dt_laus <- fread(master_laus_path, sep = "\t", header = TRUE, fill = TRUE)
  setnames(dt_laus, names(dt_laus), trimws(names(dt_laus)))
  dt_mi_laus <- dt_laus[grepl("CN26", series_id)]
  fwrite(dt_mi_laus, file = laus_dest_path, sep = "\t")
  cat(sprintf(" [✓] Extracted %s Michigan LAUS rows -> %s\n\n", 
              format(nrow(dt_mi_laus), big.mark = ","), laus_dest_path))
} else {
  cat(" [❌] Master file 'laus_county.txt' not found in data/raw/. Run 01_load_source.R first.\n\n")
}

# 3. FETCH MICHIGAN QCEW CSV (WITH RETRY LOGIC & BROWSER HEADERS)
# ------------------------------------------------------------------------------
QCEW_YEAR <- "2024"
QCEW_QTR  <- "1"
QCEW_URL  <- sprintf("https://data.bls.gov/cew/data/api/%s/%s/area/26000.csv", QCEW_YEAR, QCEW_QTR)
QCEW_DEST <- file.path(BLS_DIR, sprintf("qcew_mi_%sq%s.csv", QCEW_YEAR, QCEW_QTR))

cat(sprintf("[*] Pulling Michigan QCEW CSV (%s Q%s) via httr2 API client...\n", QCEW_YEAR, QCEW_QTR))

tryCatch({
  req <- request(QCEW_URL) |>
    req_headers(
      `User-Agent`         = BLS_UA,
      `Accept`             = "text/csv,text/html,application/xhtml+xml,*/*",
      `Accept-Language`    = "en-US,en;q=0.9",
      `Referer`            = "https://www.bls.gov/cew/",
      `Sec-Fetch-Dest`     = "document",
      `Sec-Fetch-Mode`     = "navigate",
      `Sec-Fetch-Site`     = "same-site"
    ) |>
    # Automatically retry on 503, 500, or rate-limits up to 5 times with backoff
    req_retry(
      max_tries = 5,
      backoff   = ~ 2^.x
    )
  
  resp <- req_perform(req, path = QCEW_DEST)
  
  # Verify downloaded payload
  if (file.exists(QCEW_DEST) && file.info(QCEW_DEST)$size > 100) {
    first_line <- readLines(QCEW_DEST, n = 1, warn = FALSE)
    if (grepl("<!DOCTYPE|html", first_line, ignore.case = TRUE)) {
      file.remove(QCEW_DEST)
      cat(" [❌] BLS REJECTED REQUEST: Returned HTML block page for QCEW API.\n\n")
    } else {
      dt_qcew <- fread(QCEW_DEST)
      cat(sprintf(" [✓] Downloaded and verified: %s QCEW matrix (%s rows)\n\n", 
                  QCEW_YEAR, format(nrow(dt_qcew), big.mark = ",")))
    }
  } else {
    cat(" [❌] Download failed or empty file returned for QCEW API.\n\n")
  }
}, error = function(e) {
  cat(sprintf(" [❌] httr2 Extraction Error on QCEW: %s\n\n", e$message))
})

cat("========================================================\n")
cat(" PIPELINE STEP 02 COMPLETE: RAW BLS DATA READY\n")
cat("========================================================\n")