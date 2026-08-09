# ==============================================================================
# SCRIPT:  05_transform_analytics.R
# PURPOSE: Phase 3 (Transform): Build analytical SQL views in DuckDB for YoY 
#          growth rates, regional spreads, LAUS 12-MMA, unpivoted QCEW, and
#          the regional OWL Corridor (Oakland-Washtenaw-Livingston) aggregates.
# SYSTEM:  The Compass Lens Architecture
# ==============================================================================

library(DBI)
library(duckdb)
library(here)

# ------------------------------------------------------------------------------
# 1. DATABASE CONNECTION
# ------------------------------------------------------------------------------
DB_PATH <- here::here("data", "db", "glce_econ_warehouse.duckdb")

if (!file.exists(DB_PATH)) {
  stop("CRITICAL: DuckDB database file does not exist. Run 04_hydrate_duckdb.R first.")
}

con <- dbConnect(duckdb::duckdb(), dbdir = DB_PATH, read_only = FALSE)

message("========================================================")
message("BUILDING ANALYTICAL SQL VIEWS IN DUCKDB")
message("========================================================\n")

# ------------------------------------------------------------------------------
# 2. VIEW 1: FRED MACRO METRICS WITH YoY % CHANGES & SPREADS
# ------------------------------------------------------------------------------
message("[*] Building view: 'vw_fred_macro_yoy'...")

dbExecute(con, "CREATE OR REPLACE VIEW vw_fred_macro_yoy AS
WITH base AS (
  SELECT 
    CAST(date AS DATE) AS observation_date,
    metric_name,
    series_id,
    geo_level,
    value,
    -- Compute 12-month lag for YoY calculation (monthly series)
    LAG(value, 12) OVER (PARTITION BY metric_name ORDER BY CAST(date AS DATE)) AS value_yoy_lag
  FROM stg_fred_macro
)
SELECT 
  observation_date,
  metric_name,
  series_id,
  geo_level,
  value,
  value_yoy_lag,
  CASE 
    WHEN value_yoy_lag IS NOT NULL AND value_yoy_lag != 0 
    THEN ROUND(((value - value_yoy_lag) / value_yoy_lag) * 100.0, 2)
    ELSE NULL 
  END AS yoy_pct_change
FROM base;")

message(" [✓] View 'vw_fred_macro_yoy' created.")

# ------------------------------------------------------------------------------
# 3. VIEW 2: MI VS US UNEMPLOYMENT SPREAD
# ------------------------------------------------------------------------------
message("[*] Building view: 'vw_mi_vs_us_unemployment'...")

dbExecute(con, "CREATE OR REPLACE VIEW vw_mi_vs_us_unemployment AS
SELECT 
  mi.observation_date,
  mi.value AS mi_unemployment_rate,
  us.value AS us_unemployment_rate,
  ROUND(mi.value - us.value, 2) AS mi_us_spread_pts
FROM vw_fred_macro_yoy mi
JOIN vw_fred_macro_yoy us 
  ON mi.observation_date = us.observation_date
WHERE mi.metric_name = 'unemployment_rate_michigan'
  AND us.metric_name = 'unemployment_rate_us';")

message(" [✓] View 'vw_mi_vs_us_unemployment' created.")

# ------------------------------------------------------------------------------
# 4. VIEW 3: LAUS COUNTY UNEMPLOYMENT & 12-MONTH MOVING AVERAGE (12-MMA)
# ------------------------------------------------------------------------------
message("[*] Building view: 'vw_laus_county_clean'...")

dbExecute(con, "CREATE OR REPLACE VIEW vw_laus_county_clean AS
WITH base AS (
  SELECT 
    series_id,
    -- Extract FIPS county code from BLS series ID (character positions 6 to 10)
    SUBSTRING(series_id, 6, 5) AS county_fips,
    CAST(year AS INTEGER) AS year,
    CAST(REPLACE(period, 'M', '') AS INTEGER) AS month,
    MAKE_DATE(CAST(year AS INTEGER), CAST(REPLACE(period, 'M', '') AS INTEGER), 1) AS observation_date,
    -- Map measure code suffixes (03=Unemployment Rate, 04=Unemployed, 05=Employed, 06=Labor Force)
    CASE SUBSTRING(series_id, 18, 2)
      WHEN '03' THEN 'unemployment_rate'
      WHEN '04' THEN 'unemployed_count'
      WHEN '05' THEN 'employed_count'
      WHEN '06' THEN 'labor_force'
      ELSE 'other'
    END AS measure_type,
    TRY_CAST(TRIM(value) AS DOUBLE) AS value
  FROM stg_bls_laus_county
  WHERE period LIKE 'M%' 
    AND period != 'M13' -- Exclude annual averages
)
SELECT 
  series_id,
  county_fips,
  year,
  month,
  observation_date,
  measure_type,
  value,
  -- 12-Month Moving Average across current and prior 11 months
  ROUND(
    AVG(value) OVER (
      PARTITION BY county_fips, measure_type 
      ORDER BY observation_date 
      ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
    ), 2
  ) AS value_12mma
FROM base;")

message(" [✓] View 'vw_laus_county_clean' created.")

# ------------------------------------------------------------------------------
# 5. VIEW 4: QCEW MONTHLY TIME SERIES (UNPIVOTED EMPLOYMENT)
# ------------------------------------------------------------------------------
message("[*] Building view: 'vw_qcew_monthly_series'...")

dbExecute(con, "CREATE OR REPLACE VIEW vw_qcew_monthly_series AS
WITH unpivoted AS (
  SELECT 
    area_fips,
    industry_code,
    own_code,
    CAST(year AS INTEGER) AS year,
    CAST(qtr AS INTEGER) AS qtr,
    -- Unpivot month 1, 2, and 3 employment levels into rows
    UNNEST([
      {'month_num': (CAST(qtr AS INTEGER) * 3 - 2), 'emp': TRY_CAST(month1_emplvl AS DOUBLE)},
      {'month_num': (CAST(qtr AS INTEGER) * 3 - 1), 'emp': TRY_CAST(month2_emplvl AS DOUBLE)},
      {'month_num': (CAST(qtr AS INTEGER) * 3 - 0), 'emp': TRY_CAST(month3_emplvl AS DOUBLE)}
    ]) AS m_data,
    TRY_CAST(total_qtrly_wages AS DOUBLE) AS total_qtrly_wages,
    TRY_CAST(avg_wkly_wage AS DOUBLE) AS avg_wkly_wage
  FROM stg_bls_qcew_data
  WHERE area_fips LIKE '26%' -- Filter to Michigan counties and statewide
)
SELECT 
  area_fips AS county_fips,
  industry_code,
  own_code,
  year,
  qtr,
  MAKE_DATE(year, CAST(m_data.month_num AS INTEGER), 1) AS observation_date,
  m_data.emp AS monthly_employment,
  avg_wkly_wage,
  total_qtrly_wages
FROM unpivoted;")

message(" [✓] View 'vw_qcew_monthly_series' created.")

# ------------------------------------------------------------------------------
# 6. VIEW 5: LAUS OWL CORRIDOR REGIONAL AGGREGATE
# ------------------------------------------------------------------------------
message("[*] Building view: 'vw_laus_owl_corridor'...")

dbExecute(con, "CREATE OR REPLACE VIEW vw_laus_owl_corridor AS
WITH owl_base AS (
  SELECT 
    observation_date,
    year,
    month,
    measure_type,
    SUM(value) AS total_value
  FROM vw_laus_county_clean
  WHERE county_fips IN ('26093', '26125', '26161')
  GROUP BY observation_date, year, month, measure_type
),
pivoted AS (
  SELECT 
    observation_date,
    year,
    month,
    MAX(CASE WHEN measure_type = 'labor_force' THEN total_value END) AS labor_force,
    MAX(CASE WHEN measure_type = 'employed_count' THEN total_value END) AS employed_count,
    MAX(CASE WHEN measure_type = 'unemployed_count' THEN total_value END) AS unemployed_count
  FROM owl_base
  GROUP BY observation_date, year, month
)
SELECT 
  'OWL' AS region_code,
  'Oakland-Washtenaw-Livingston' AS region_name,
  observation_date,
  year,
  month,
  labor_force,
  employed_count,
  unemployed_count,
  ROUND((unemployed_count / NULLIF(labor_force, 0)) * 100.0, 2) AS unemployment_rate,
  -- 12-Month Moving Average of the Corridor Unemployment Rate
  ROUND(
    AVG(ROUND((unemployed_count / NULLIF(labor_force, 0)) * 100.0, 2)) OVER (
      ORDER BY observation_date 
      ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
    ), 2
  ) AS unemployment_rate_12mma
FROM pivoted;")

message(" [✓] View 'vw_laus_owl_corridor' created.")

# ------------------------------------------------------------------------------
# 7. VIEW 6: QCEW OWL CORRIDOR REGIONAL AGGREGATE
# ------------------------------------------------------------------------------
message("[*] Building view: 'vw_qcew_owl_corridor'...")

dbExecute(con, "CREATE OR REPLACE VIEW vw_qcew_owl_corridor AS
SELECT 
  'OWL' AS region_code,
  'Oakland-Washtenaw-Livingston' AS region_name,
  industry_code,
  own_code,
  observation_date,
  year,
  qtr,
  SUM(monthly_employment) AS total_monthly_employment,
  SUM(total_qtrly_wages) AS total_qtrly_wages,
  -- Weighted average weekly wage across the three counties
  ROUND(SUM(monthly_employment * avg_wkly_wage) / NULLIF(SUM(monthly_employment), 0), 2) AS weighted_avg_wkly_wage
FROM vw_qcew_monthly_series
WHERE county_fips IN ('26093', '26125', '26161')
GROUP BY industry_code, own_code, observation_date, year, qtr;")

message(" [✓] View 'vw_qcew_owl_corridor' created.")

# ------------------------------------------------------------------------------
# 8. DISCONNECT & CLEANUP
# ------------------------------------------------------------------------------
dbDisconnect(con, shutdown = TRUE)

message("\n========================================================")
message(" PIPELINE STEP 05 COMPLETE: ALL ANALYTICAL VIEWS READY")
message("========================================================")