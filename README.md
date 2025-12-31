# NYC Taxi Data Lakehouse

```
    ╔═══════════════════════════════════════════════════════════════════════╗
    ║                                                                       ║
    ║     ███╗   ██╗██╗   ██╗ ██████╗    ████████╗ █████╗ ██╗  ██╗██╗      ║
    ║     ████╗  ██║╚██╗ ██╔╝██╔════╝    ╚══██╔══╝██╔══██╗╚██╗██╔╝██║      ║
    ║     ██╔██╗ ██║ ╚████╔╝ ██║            ██║   ███████║ ╚███╔╝ ██║      ║
    ║     ██║╚██╗██║  ╚██╔╝  ██║            ██║   ██╔══██║ ██╔██╗ ██║      ║
    ║     ██║ ╚████║   ██║   ╚██████╗       ██║   ██║  ██║██╔╝ ██╗██║      ║
    ║     ╚═╝  ╚═══╝   ╚═╝    ╚═════╝       ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝      ║
    ║                                                                       ║
    ║              D A T A   L A K E H O U S E                              ║
    ║                                                                       ║
    ╚═══════════════════════════════════════════════════════════════════════╝
```

Modern data lakehouse with **medallion architecture** (Bronze → Silver → Gold) using NYC Taxi Trip Records, DuckDB, and dbt.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           DATA LAKEHOUSE ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   ┌──────────────┐                                                               │
│   │  RAW DATA    │     NYC Taxi Trip Records (Parquet)                          │
│   │  ──────────  │     • Yellow Taxi  • Green Taxi  • FHV                       │
│   │  Jan-Mar '24 │     • ~10M+ trips across 3 months                            │
│   └──────┬───────┘                                                               │
│          │                                                                       │
│          ▼                                                                       │
│   ┌──────────────────────────────────────────────────────────────────────────┐  │
│   │                         MEDALLION LAYERS                                  │  │
│   ├──────────────────────────────────────────────────────────────────────────┤  │
│   │                                                                          │  │
│   │  ┌────────────┐      ┌────────────┐      ┌────────────┐                 │  │
│   │  │   BRONZE   │      │   SILVER   │      │    GOLD    │                 │  │
│   │  │  (staging) │ ───▶ │(intermediate)───▶ │  (marts)   │                 │  │
│   │  └────────────┘      └────────────┘      └────────────┘                 │  │
│   │                                                                          │  │
│   │  ┌────────────┐      ┌────────────┐      ┌────────────┐                 │  │
│   │  │ stg_yellow │      │ int_trips  │      │ fct_daily  │                 │  │
│   │  │ stg_green  │      │  _unioned  │      │  _trips    │                 │  │
│   │  │ stg_fhv    │      │            │      │            │                 │  │
│   │  │ stg_zones  │      │ int_trips  │      │ fct_zone   │                 │  │
│   │  │            │      │ _enriched  │      │  _metrics  │                 │  │
│   │  │            │      │            │      │            │                 │  │
│   │  │            │      │ int_trips  │      │ dim_zones  │                 │  │
│   │  │            │      │ _validated │      │            │                 │  │
│   │  └────────────┘      └────────────┘      └────────────┘                 │  │
│   │                                                                          │  │
│   │   Raw ingestion       Cleaned &          Analytics-ready                │  │
│   │   Type casting        Validated          Aggregated                     │  │
│   │   Hash-based IDs      Zone enrichment    Incremental                    │  │
│   │                       Calculated fields  Daily metrics                  │  │
│   │                                                                          │  │
│   └──────────────────────────────────────────────────────────────────────────┘  │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Tech Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                        TECHNOLOGY STACK                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│   │   DuckDB    │  │     dbt     │  │   Parquet   │             │
│   │  ─────────  │  │  ─────────  │  │  ─────────  │             │
│   │  Warehouse  │  │  Transform  │  │   Storage   │             │
│   └─────────────┘  └─────────────┘  └─────────────┘             │
│                                                                  │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│   │  Python 3.11│  │     UV      │  │   GitHub    │             │
│   │  ─────────  │  │  ─────────  │  │  Actions    │             │
│   │  Scripts    │  │  Packages   │  │  ─────────  │             │
│   └─────────────┘  └─────────────┘  │    CI/CD    │             │
│                                      └─────────────┘             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

```bash
# Clone repository
git clone https://github.com/AlharbiAbdullah/data-lakehouse
cd data-lakehouse

# Install dependencies
uv sync

# Run the complete pipeline
uv run python scripts/run_pipeline.py

# Or run steps individually:
uv run python scripts/download_data.py   # Download NYC Taxi data
uv run python scripts/setup_warehouse.py # Set up DuckDB

cd dbt_project
uv run dbt deps                          # Install dbt packages
uv run dbt seed                          # Load reference data
uv run dbt run                           # Run transformations
uv run dbt test                          # Run data quality tests
uv run dbt docs generate && dbt docs serve  # View documentation
```

## Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DATA FLOW                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   NYC TLC Website                                                            │
│        │                                                                     │
│        │  download_data.py                                                   │
│        ▼                                                                     │
│   ┌─────────────────────────────────────────┐                               │
│   │           data/raw/*.parquet            │                               │
│   │  • yellow_tripdata_2024-{01,02,03}     │                               │
│   │  • green_tripdata_2024-{01,02,03}      │                               │
│   │  • fhv_tripdata_2024-{01,02,03}        │                               │
│   └────────────────────┬────────────────────┘                               │
│                        │                                                     │
│                        │  setup_warehouse.py                                 │
│                        ▼                                                     │
│   ┌─────────────────────────────────────────┐                               │
│   │     data/warehouse/lakehouse.duckdb     │                               │
│   │              (raw schema)               │                               │
│   └────────────────────┬────────────────────┘                               │
│                        │                                                     │
│                        │  dbt run                                            │
│                        ▼                                                     │
│   ┌─────────────────────────────────────────┐                               │
│   │          BRONZE → SILVER → GOLD          │                               │
│   │     (staging, intermediate, marts)      │                               │
│   └────────────────────┬────────────────────┘                               │
│                        │                                                     │
│                        │  dbt test                                           │
│                        ▼                                                     │
│   ┌─────────────────────────────────────────┐                               │
│   │          Data Quality Validated          │                               │
│   │   • Unique IDs  • Positive fares        │                               │
│   │   • Valid zones • Duration bounds       │                               │
│   └─────────────────────────────────────────┘                               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Medallion Layers

| Layer | dbt Folder | Prefix | Purpose |
|-------|------------|--------|---------|
| **Bronze** | `staging/` | `stg_` | Raw ingestion with type casting and hash-based IDs |
| **Silver** | `intermediate/` | `int_` | Cleaned, validated, enriched with zone data |
| **Gold** | `marts/` | `fct_`, `dim_` | Analytics-ready aggregations (incremental) |

## Key Features

```
┌─────────────────────────────────────────────────────────────────┐
│                         KEY FEATURES                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ✓ Deterministic Trip IDs                                       │
│    MD5 hash of (pickup_datetime + dropoff_datetime +            │
│    pickup_zone + dropoff_zone + fare_amount)                    │
│                                                                  │
│  ✓ Incremental Models                                           │
│    Gold layer uses incremental materialization                  │
│    with 3-day lookback for late-arriving data                   │
│                                                                  │
│  ✓ Data Quality Tests                                           │
│    • Unique constraints  • Not null checks                      │
│    • Accepted values     • Range validations                    │
│                                                                  │
│  ✓ All Trip Types                                               │
│    • Yellow Taxi (Manhattan)                                    │
│    • Green Taxi (Outer boroughs)                                │
│    • FHV (For-hire vehicles)                                    │
│                                                                  │
│  ✓ CI/CD Pipeline                                               │
│    GitHub Actions runs dbt build + test on every push           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
data-lakehouse/
├── data/
│   ├── raw/                    # Raw parquet files (gitignored)
│   └── warehouse/              # DuckDB database (gitignored)
│
├── dbt_project/
│   ├── dbt_project.yml         # dbt configuration
│   ├── profiles.yml            # DuckDB connection
│   ├── packages.yml            # dbt dependencies
│   │
│   ├── seeds/
│   │   └── taxi_zones.csv      # Zone lookup reference data
│   │
│   ├── macros/
│   │   └── generate_trip_id.sql
│   │
│   └── models/
│       ├── staging/            # Bronze layer
│       │   ├── stg_yellow_trips.sql
│       │   ├── stg_green_trips.sql
│       │   ├── stg_fhv_trips.sql
│       │   └── stg_taxi_zones.sql
│       │
│       ├── intermediate/       # Silver layer
│       │   ├── int_trips_unioned.sql
│       │   ├── int_trips_enriched.sql
│       │   └── int_trips_validated.sql
│       │
│       └── marts/              # Gold layer
│           ├── dim_zones.sql
│           ├── fct_daily_trips.sql
│           └── fct_zone_metrics.sql
│
├── scripts/
│   ├── download_data.py        # Download NYC Taxi data
│   ├── setup_warehouse.py      # Initialize DuckDB
│   └── run_pipeline.py         # End-to-end execution
│
├── docs/
│   ├── architecture.md
│   └── data_dictionary.md
│
└── .github/workflows/
    └── dbt_ci.yml              # CI/CD pipeline
```

## Sample Queries

Once the pipeline completes, query the Gold layer:

```sql
-- Daily trip summary by borough
SELECT
    trip_date,
    pickup_borough,
    trip_type,
    total_trips,
    avg_fare,
    avg_duration_minutes
FROM marts.fct_daily_trips
WHERE trip_date >= '2024-01-01'
ORDER BY trip_date, total_trips DESC;

-- Busiest zones
SELECT
    z.zone_name,
    z.borough,
    SUM(m.pickups) as total_pickups,
    SUM(m.dropoffs) as total_dropoffs
FROM marts.fct_zone_metrics m
JOIN marts.dim_zones z ON m.zone_id = z.zone_id
GROUP BY z.zone_name, z.borough
ORDER BY total_pickups DESC
LIMIT 10;
```

## Data Quality

```
┌─────────────────────────────────────────────────────────────────┐
│                      DATA QUALITY TESTS                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Bronze Layer (staging)                                         │
│  ├── trip_id: unique, not_null                                  │
│  ├── pickup_datetime: not_null                                  │
│  ├── dropoff_datetime: not_null                                 │
│  └── trip_type: accepted_values ['yellow', 'green', 'fhv']     │
│                                                                  │
│  Silver Layer (intermediate)                                    │
│  ├── trip_duration_minutes: range (0, 180)                      │
│  ├── fare_amount: positive (for yellow/green)                   │
│  └── trip_distance: non-negative                                │
│                                                                  │
│  Gold Layer (marts)                                             │
│  ├── total_trips: not_null, >= 0                                │
│  └── zone_id: not_null, references dim_zones                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

*Built with DuckDB, dbt, and Python*
