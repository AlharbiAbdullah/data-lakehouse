# Architecture Documentation

## Overview

This project implements a modern data lakehouse architecture using the medallion pattern (Bronze → Silver → Gold) for processing NYC Taxi Trip Records.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           SYSTEM ARCHITECTURE                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                         EXTERNAL DATA SOURCE                             │   │
│   │                                                                          │   │
│   │   NYC Taxi & Limousine Commission (TLC)                                 │   │
│   │   https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page         │   │
│   │                                                                          │   │
│   └────────────────────────────────┬────────────────────────────────────────┘   │
│                                    │                                             │
│                                    │ HTTPS (Parquet files)                       │
│                                    ▼                                             │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                         INGESTION LAYER                                  │   │
│   │                                                                          │   │
│   │   scripts/download_data.py                                              │   │
│   │   • Async downloads with httpx                                          │   │
│   │   • Progress tracking with tqdm                                         │   │
│   │   • Concurrent downloads (3 at a time)                                  │   │
│   │                                                                          │   │
│   └────────────────────────────────┬────────────────────────────────────────┘   │
│                                    │                                             │
│                                    │ Parquet files                               │
│                                    ▼                                             │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                         STORAGE LAYER                                    │   │
│   │                                                                          │   │
│   │   data/raw/                    data/warehouse/                          │   │
│   │   ├── yellow_tripdata_*.parquet   └── lakehouse.duckdb                  │   │
│   │   ├── green_tripdata_*.parquet                                          │   │
│   │   ├── fhv_tripdata_*.parquet                                            │   │
│   │   └── taxi_zone_lookup.csv                                              │   │
│   │                                                                          │   │
│   └────────────────────────────────┬────────────────────────────────────────┘   │
│                                    │                                             │
│                                    │ DuckDB external tables                      │
│                                    ▼                                             │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                         TRANSFORMATION LAYER                             │   │
│   │                                                                          │   │
│   │   dbt (Data Build Tool)                                                 │   │
│   │                                                                          │   │
│   │   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐                  │   │
│   │   │   BRONZE    │   │   SILVER    │   │    GOLD     │                  │   │
│   │   │             │   │             │   │             │                  │   │
│   │   │  stg_*      │──▶│  int_*      │──▶│  fct_*      │                  │   │
│   │   │             │   │             │   │  dim_*      │                  │   │
│   │   └─────────────┘   └─────────────┘   └─────────────┘                  │   │
│   │                                                                          │   │
│   └────────────────────────────────┬────────────────────────────────────────┘   │
│                                    │                                             │
│                                    │ Analytics-ready tables                      │
│                                    ▼                                             │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                         CONSUMPTION LAYER                                │   │
│   │                                                                          │   │
│   │   • SQL queries via DuckDB CLI                                          │   │
│   │   • Python analysis with pandas/polars                                  │   │
│   │   • BI tools (Metabase, Superset, etc.)                                │   │
│   │   • dbt docs for documentation                                          │   │
│   │                                                                          │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Medallion Architecture

### Bronze Layer (Staging)

**Purpose:** Raw data ingestion with minimal transformation

**Transformations:**
- Type casting to ensure consistent data types
- Column name standardization (snake_case)
- Generation of deterministic trip IDs using MD5 hash
- Addition of `trip_type` column to identify data source
- Addition of `loaded_at` timestamp for lineage

**Models:**
- `stg_yellow_trips` - Yellow taxi trips
- `stg_green_trips` - Green taxi trips
- `stg_fhv_trips` - For-hire vehicle trips
- `stg_taxi_zones` - Zone lookup reference

### Silver Layer (Intermediate)

**Purpose:** Data cleaning, validation, and enrichment

**Transformations:**
- Union of all trip types into single dataset
- Zone enrichment (join with taxi_zones for borough/zone names)
- Calculated fields:
  - `trip_duration_minutes`
  - `avg_speed_mph`
  - `tip_percentage`
- Data validation and outlier removal:
  - Duration between 1-180 minutes
  - Positive fares (for metered trips)
  - Reasonable speeds (< 100 mph average)
  - Valid zone IDs

**Models:**
- `int_trips_unioned` - All trips with standardized schema
- `int_trips_enriched` - Trips with zone info and calculated fields
- `int_trips_validated` - Clean trips with outliers removed

### Gold Layer (Marts)

**Purpose:** Analytics-ready aggregations for business intelligence

**Features:**
- Incremental materialization for efficiency
- 3-day lookback window for late-arriving data
- Pre-aggregated metrics for fast queries

**Models:**
- `dim_zones` - Zone dimension table
- `fct_daily_trips` - Daily trip aggregations by borough and type
- `fct_zone_metrics` - Zone-level pickup/dropoff metrics

## Data Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│                          DATA LINEAGE                                 │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│   raw.yellow_tripdata ─┐                                             │
│                        │                                              │
│   raw.green_tripdata ──┼──▶ stg_* ──▶ int_trips_unioned              │
│                        │                     │                        │
│   raw.fhv_tripdata ────┘                     ▼                        │
│                              int_trips_enriched ◀── stg_taxi_zones   │
│                                      │                                │
│                                      ▼                                │
│                              int_trips_validated                      │
│                                      │                                │
│                         ┌────────────┼────────────┐                  │
│                         ▼            ▼            ▼                  │
│                   fct_daily    fct_zone      dim_zones               │
│                     _trips      _metrics                             │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

## Key Design Decisions

### 1. Deterministic Trip IDs

Instead of using `row_number()` which varies between runs, we use MD5 hash:

```sql
md5(
    pickup_datetime ||
    dropoff_datetime ||
    pickup_zone_id ||
    dropoff_zone_id ||
    fare_amount
)
```

**Benefits:**
- Reproducible across runs
- Enables incremental processing
- Supports data reconciliation

### 2. Incremental Models

Gold layer tables use incremental materialization:

```sql
{{
    config(
        materialized='incremental',
        unique_key=['trip_date', 'pickup_borough', 'trip_type'],
        incremental_strategy='merge'
    )
}}
```

**3-day lookback window:**
- Catches late-arriving data
- Balances freshness vs. reprocessing cost
- Standard practice for taxi data

### 3. Schema Organization

```
lakehouse.duckdb
├── raw (schema)
│   ├── yellow_tripdata (view → parquet)
│   ├── green_tripdata (view → parquet)
│   ├── fhv_tripdata (view → parquet)
│   └── taxi_zones (view → CSV)
├── staging (schema)
│   └── stg_* models
├── intermediate (schema)
│   └── int_* models
└── marts (schema)
    ├── fct_* models
    └── dim_* models
```

## Performance Considerations

### DuckDB Advantages

- **Columnar storage:** Efficient for analytical queries
- **Vectorized execution:** Fast aggregations
- **Zero dependencies:** Single file database
- **Parquet native:** Direct query on parquet files

### Optimization Strategies

1. **Views for staging:** Bronze layer uses views to avoid data duplication
2. **Incremental Gold:** Only process new/changed data
3. **Predicate pushdown:** Filters pushed to parquet scan
4. **Parallel execution:** DuckDB uses multiple threads

## Extensibility

### Adding New Data Sources

1. Add download URL to `scripts/download_data.py`
2. Create external table in `scripts/setup_warehouse.py`
3. Add source definition in `models/staging/_sources.yml`
4. Create staging model `stg_new_source.sql`
5. Update `int_trips_unioned.sql` to include new source

### Adding New Metrics

1. Add calculated fields to `int_trips_enriched.sql`
2. Add aggregations to `fct_daily_trips.sql` or `fct_zone_metrics.sql`
3. Update schema definitions in `_marts.yml`
4. Add appropriate tests
