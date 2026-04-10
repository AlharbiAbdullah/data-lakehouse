# Data Lakehouse Project Specification

## Project Overview

**Name:** `data-lakehouse`
**Focus:** Data Lakes, Lakehouses, Data Warehouse, dbt
**Dataset:** NYC Taxi Trip Records
**GitHub Repo:** `https://github.com/AlharbiAbdullah/data-lakehouse`

### Goal
Build a modern data lakehouse with medallion architecture (Bronze → Silver → Gold) demonstrating industry best practices for data engineering.

### What You'll Showcase
- Medallion architecture (Bronze/Silver/Gold layers)
- Data modeling with dbt
- ELT patterns and transformations
- Data quality testing
- Documentation and lineage

---

## Dataset: NYC Taxi

**Source:** https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page

**Why NYC Taxi:**
- Industry standard for data engineering demos
- Rich data: fares, tips, distances, pickup/dropoff zones
- Well-documented schema
- Employers recognize it instantly

**Tables:**
- `yellow_taxi_trips` - Yellow cab trips
- `green_taxi_trips` - Green cab trips (outer boroughs)
- `fhv_trips` - For-hire vehicles
- `taxi_zones` - Lookup table for zones

**Sample Data Size:** Start with 1-2 months of data (~2-5 million rows)

---

## Tech Stack

| Component | Technology | Why |
|-----------|------------|-----|
| Warehouse | DuckDB | Lightweight, no infrastructure, fast |
| Transformations | dbt | Industry standard, great docs |
| Storage | Parquet files | Columnar, efficient, portable |
| Python | 3.11+ | Modern features |
| Package Mgmt | UV | Fast, modern |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     DATA LAKEHOUSE                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   RAW DATA (Parquet)                                            │
│        │                                                         │
│        ▼                                                         │
│   ┌─────────────┐                                               │
│   │   BRONZE    │  Raw ingestion, minimal transformation        │
│   │  (staging)  │  - Source conformed                           │
│   └──────┬──────┘  - Timestamps added                           │
│          │                                                       │
│          ▼                                                       │
│   ┌─────────────┐                                               │
│   │   SILVER    │  Cleaned, validated, enriched                 │
│   │(intermediate)│  - Data quality applied                       │
│   └──────┬──────┘  - Business logic                             │
│          │                                                       │
│          ▼                                                       │
│   ┌─────────────┐                                               │
│   │    GOLD     │  Analytics-ready, aggregated                  │
│   │   (marts)   │  - Metrics, KPIs                              │
│   └─────────────┘  - Ready for dashboards                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
data-lakehouse/
├── README.md                 # Project documentation
├── pyproject.toml           # Python dependencies (UV)
├── .gitignore
│
├── data/
│   ├── raw/                 # Raw parquet files (gitignored)
│   └── warehouse/           # DuckDB database (gitignored)
│
├── dbt_project/
│   ├── dbt_project.yml      # dbt configuration
│   ├── profiles.yml         # DuckDB connection
│   │
│   ├── seeds/               # Reference data (CSV)
│   │   └── taxi_zones.csv
│   │
│   ├── models/
│   │   ├── staging/         # BRONZE layer
│   │   │   ├── _staging.yml
│   │   │   ├── stg_yellow_trips.sql
│   │   │   ├── stg_green_trips.sql
│   │   │   └── stg_taxi_zones.sql
│   │   │
│   │   ├── intermediate/    # SILVER layer
│   │   │   ├── _intermediate.yml
│   │   │   ├── int_trips_enriched.sql
│   │   │   └── int_trips_validated.sql
│   │   │
│   │   └── marts/           # GOLD layer
│   │       ├── _marts.yml
│   │       ├── fct_daily_trips.sql
│   │       ├── fct_zone_metrics.sql
│   │       └── dim_zones.sql
│   │
│   └── tests/               # Data quality tests
│       └── assert_positive_fares.sql
│
├── scripts/
│   ├── download_data.py     # Download NYC Taxi data
│   ├── setup_warehouse.py   # Initialize DuckDB
│   └── run_pipeline.py      # End-to-end execution
│
└── docs/
    ├── architecture.md      # Architecture documentation
    └── data_dictionary.md   # Column descriptions
```

---

## Implementation Steps

### Phase 1: Setup (Day 1)
1. [ ] Initialize repository with UV
2. [ ] Set up dbt project with DuckDB adapter
3. [ ] Create download script for NYC Taxi data
4. [ ] Download 1-2 months of sample data
5. [ ] Load raw parquet into DuckDB

### Phase 2: Bronze Layer (Day 1-2)
1. [ ] Create staging models for yellow/green trips
2. [ ] Add source definitions in `_staging.yml`
3. [ ] Implement basic data type casting
4. [ ] Add ingestion timestamp
5. [ ] Create staging model for taxi zones

### Phase 3: Silver Layer (Day 2)
1. [ ] Create enriched trips model (join with zones)
2. [ ] Add data validation (positive fares, valid distances)
3. [ ] Implement data quality tests
4. [ ] Add calculated fields (trip duration, speed)
5. [ ] Document transformations

### Phase 4: Gold Layer (Day 2-3)
1. [ ] Create fact table: daily trip aggregations
2. [ ] Create fact table: zone-level metrics
3. [ ] Create dimension table: zones
4. [ ] Add business metrics (avg fare, tip percentage)
5. [ ] Implement incremental models (optional)

### Phase 5: Documentation (Day 3)
1. [ ] Write comprehensive README
2. [ ] Generate dbt docs
3. [ ] Create architecture diagram
4. [ ] Add data dictionary
5. [ ] Record demo GIF/video

---

## Key Models

### Bronze: `stg_yellow_trips`
```sql
-- models/staging/stg_yellow_trips.sql
with source as (
    select * from {{ source('raw', 'yellow_tripdata') }}
),

staged as (
    select
        -- IDs
        row_number() over () as trip_id,

        -- Timestamps
        tpep_pickup_datetime as pickup_datetime,
        tpep_dropoff_datetime as dropoff_datetime,

        -- Locations
        pulocationid as pickup_zone_id,
        dolocationid as dropoff_zone_id,

        -- Trip info
        passenger_count,
        trip_distance,

        -- Fares
        fare_amount,
        tip_amount,
        total_amount,

        -- Metadata
        current_timestamp as loaded_at

    from source
)

select * from staged
```

### Silver: `int_trips_enriched`
```sql
-- models/intermediate/int_trips_enriched.sql
with trips as (
    select * from {{ ref('stg_yellow_trips') }}
),

zones as (
    select * from {{ ref('stg_taxi_zones') }}
),

enriched as (
    select
        t.*,

        -- Pickup zone info
        pz.zone as pickup_zone_name,
        pz.borough as pickup_borough,

        -- Dropoff zone info
        dz.zone as dropoff_zone_name,
        dz.borough as dropoff_borough,

        -- Calculated fields
        datediff('minute', pickup_datetime, dropoff_datetime) as trip_duration_minutes,
        case
            when trip_distance > 0
            then trip_distance / (datediff('minute', pickup_datetime, dropoff_datetime) / 60.0)
            else 0
        end as avg_speed_mph

    from trips t
    left join zones pz on t.pickup_zone_id = pz.locationid
    left join zones dz on t.dropoff_zone_id = dz.locationid
)

select * from enriched
where trip_duration_minutes > 0
  and trip_duration_minutes < 180  -- Remove outliers
  and fare_amount > 0
```

### Gold: `fct_daily_trips`
```sql
-- models/marts/fct_daily_trips.sql
with trips as (
    select * from {{ ref('int_trips_enriched') }}
)

select
    date_trunc('day', pickup_datetime) as trip_date,
    pickup_borough,

    -- Counts
    count(*) as total_trips,
    sum(passenger_count) as total_passengers,

    -- Distances
    sum(trip_distance) as total_distance_miles,
    avg(trip_distance) as avg_distance_miles,

    -- Fares
    sum(fare_amount) as total_fares,
    avg(fare_amount) as avg_fare,
    sum(tip_amount) as total_tips,
    avg(tip_amount / nullif(fare_amount, 0)) as avg_tip_percentage,

    -- Duration
    avg(trip_duration_minutes) as avg_duration_minutes

from trips
group by 1, 2
```

---

## Data Quality Tests

```yaml
# models/staging/_staging.yml
version: 2

models:
  - name: stg_yellow_trips
    description: Staged yellow taxi trips
    columns:
      - name: trip_id
        tests:
          - unique
          - not_null
      - name: fare_amount
        tests:
          - not_null
      - name: pickup_datetime
        tests:
          - not_null
```

---

## README Template

```markdown
# NYC Taxi Data Lakehouse

Modern data lakehouse implementation with medallion architecture using DuckDB and dbt.

## Architecture

[Architecture diagram here]

## Tech Stack
- **Warehouse:** DuckDB
- **Transformations:** dbt
- **Storage:** Parquet

## Quick Start

```bash
# Clone repository
git clone https://github.com/AlharbiAbdullah/data-lakehouse
cd data-lakehouse

# Install dependencies
uv sync

# Download sample data
uv run python scripts/download_data.py

# Run dbt pipeline
cd dbt_project
dbt run
dbt test
dbt docs generate
dbt docs serve
```

## Layers

| Layer | Purpose | Models |
|-------|---------|--------|
| Bronze | Raw ingestion | stg_* |
| Silver | Cleaned & enriched | int_* |
| Gold | Analytics-ready | fct_*, dim_* |

## Data Quality
- Unique trip IDs
- Positive fares validation
- Trip duration bounds
- Zone reference integrity

## Author
Abdullah Al Harbi - Data & AI Engineer
```

---

## Success Criteria

- [ ] DuckDB warehouse with 3 layers (Bronze/Silver/Gold)
- [ ] dbt models with proper documentation
- [ ] Data quality tests passing
- [ ] README with architecture diagram
- [ ] Reproducible setup (download → run → analyze)
