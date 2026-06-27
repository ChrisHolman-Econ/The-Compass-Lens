# The Compass Lens: Regional Economic Pulse Pipeline

An institutional-grade, automated ETL (Extract, Transform, Load) architecture built to monitor, model, and visualize sub-county economic and labor market dynamics across Michigan's core transit and commuter corridors. 

Managed under a Low-Profit Limited Liability Company (L3C) framework, **The Compass Lens** serves as an objective, public-benefit data utility providing actionable business intelligence for municipal leaders, Downtown Development Authorities (DDAs), and regional financial stakeholders.

---

## 📊 Core Data Framework

The pipeline programmatically aggregates high-frequency federal and academic data streams to construct a comprehensive monthly economic profile, completely bypassing individual Series ID dependencies by leveraging bulk source flat-files.

*   **LAUS (Local Area Unemployment Statistics):** Sub-county and corridor-level labor force sizing, household employment, and structural divergence metrics.
*   **CES (Current Employment Statistics):** Nonfarm payroll expansions and contractions tracked across regional industry supersectors (e.g., Manufacturing, Logistics, Professional Services).
*   **JOLTS (Job Openings and Labor Turnover Survey):** Regional labor demand dynamics, vacancy rates, and the worker-confidence quits rate.
*   **Consumer Sentiment (University of Michigan):** Forward-looking macroeconomic psychological indicators used as an early-warning radar for local retail and commercial real estate footprints.
*   **QCEW (Quarterly Census of Employment and Wages):** Deep-dive, multi-quarter historical baselines for structural benchmarking and industry-share mapping.

---

## 🛠️ Pipeline Architecture

The codebase is strictly modularized to maintain complete isolation between data extraction, statistical calculation, and downstream communication.

```text
pipeline/
├── 01_load_source.R     # Streams raw flat-files directly from BLS FTP servers & UMich API
├── 02_prep_clean.R      # Filters geographic FIPS (State/County) & constructs Long/Wide dataframes
├── 03_calc_metrics.R    # Calculates month-over-month (MoM) and 12-month year-over-year (YoY) metrics
├── 04_generate_plots.R  # Generates publication-ready static and interactive data visualizations
└── 05_build_insights.R  # Programmatically maps numeric anomalies to automated text blocks```
```

## 🚀 Getting Started
### Prerequisits

To execute the data pipeline locally, you must have an active environment configured with R and the following foundational engineering packages:

```{r}
install.packages(c("data.table", "tidyverse", "fredr", "plotly", "quarto"))
```

### Local Execution Sequence
Clone the repository:
```{bash}
git clone [https://github.com/ChrisHolman-Econ/The-Compass-Lens.git](https://github.com/ChrisHolman-Econ/The-Compass-Lens.git)
cd The-Compass-Lens
```
Initialize Environment Variables:
Ensure your local system environment or `.Renviron` file includes any necessary credentials (e.g., your FRED API key if utilized for secondary verification).

Execute the Pipeline:
Run the scripts sequentially or source the master controller to rebuild the final output:
```{bash}
Rscript pipeline/01_load_source.R
```

## 📂 Project Directory Structure

```{r}
The-Compass-Lens/
├── .gitignore               # Excludes multi-megabyte raw data loads from version tracking
├── README.md                # Project operational specifications
├── The-Compass-Lens.Rproj   # RStudio environment project relative root
├── data/
│   ├── raw/                 # Ignored raw cache of national flat-files
│   └── processed/           # Filtered long and wide Michigan corridor dataframes
├── pipeline/                # Functional ETL codebase steps (01-05)
└── templates/
    └── monthly_pulse.qmd    # Quarto template executing code to render the final report
```

### ⚖️ License & Mission Statement
As an L3C enterprise asset, this project operates with a primary charitable and educational purpose: to democratize advanced econometric modeling and spatial analytics for local community development.

Development and data science infrastructure curated by Chris Holman (Economic Specialist, State of Michigan / Faculty, Washtenaw Community College).

Disclaimer: This independent research pipeline is constructed purely for public educational and civic utility. It does not reflect the official projections, positions, or policy endorsements of the State of Michigan.
