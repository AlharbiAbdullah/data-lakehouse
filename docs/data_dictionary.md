# Data Dictionary

## Overview

This document describes all tables and columns in the NYC Taxi Data Lakehouse.

---

## Bronze Layer (Staging)

### stg_yellow_trips

Yellow taxi trip records with standardized column names.

| Column | Type | Description |
|--------|------|-------------|
| trip_id | VARCHAR | Deterministic ID (MD5 hash) |
| trip_type | VARCHAR | Always 'yellow' |
| pickup_datetime | TIMESTAMP | When meter was engaged |
| dropoff_datetime | TIMESTAMP | When meter was disengaged |
| pickup_zone_id | INTEGER | TLC zone ID for pickup |
| dropoff_zone_id | INTEGER | TLC zone ID for dropoff |
| passenger_count | INTEGER | Number of passengers |
| trip_distance | DOUBLE | Distance in miles |
| fare_amount | DOUBLE | Base fare from meter |
| extra | DOUBLE | Miscellaneous extras |
| mta_tax | DOUBLE | MTA tax |
| improvement_surcharge | DOUBLE | Improvement surcharge |
| tip_amount | DOUBLE | Tip (credit card only) |
| tolls_amount | DOUBLE | Toll charges |
| total_amount | DOUBLE | Total charged |
| vendor_id | INTEGER | TPEP provider (1=CMT, 2=VeriFone) |
| rate_code_id | INTEGER | Final rate code |
| payment_type | INTEGER | 1=Credit, 2=Cash, 3=No charge, 4=Dispute |
| loaded_at | TIMESTAMP | When record was loaded |

### stg_green_trips

Green taxi trip records (outer boroughs).

| Column | Type | Description |
|--------|------|-------------|
| trip_id | VARCHAR | Deterministic ID (MD5 hash) |
| trip_type | VARCHAR | Always 'green' |
| pickup_datetime | TIMESTAMP | When meter was engaged |
| dropoff_datetime | TIMESTAMP | When meter was disengaged |
| pickup_zone_id | INTEGER | TLC zone ID for pickup |
| dropoff_zone_id | INTEGER | TLC zone ID for dropoff |
| passenger_count | INTEGER | Number of passengers |
| trip_distance | DOUBLE | Distance in miles |
| fare_amount | DOUBLE | Base fare from meter |
| extra | DOUBLE | Miscellaneous extras |
| mta_tax | DOUBLE | MTA tax |
| improvement_surcharge | DOUBLE | Improvement surcharge |
| tip_amount | DOUBLE | Tip (credit card only) |
| tolls_amount | DOUBLE | Toll charges |
| total_amount | DOUBLE | Total charged |
| vendor_id | INTEGER | LPEP provider |
| rate_code_id | INTEGER | Final rate code |
| payment_type | INTEGER | Payment method |
| green_trip_type | INTEGER | 1=Street-hail, 2=Dispatch |
| loaded_at | TIMESTAMP | When record was loaded |

### stg_fhv_trips

For-hire vehicle trip records.

| Column | Type | Description |
|--------|------|-------------|
| trip_id | VARCHAR | Deterministic ID (MD5 hash) |
| trip_type | VARCHAR | Always 'fhv' |
| pickup_datetime | TIMESTAMP | Pickup timestamp |
| dropoff_datetime | TIMESTAMP | Dropoff timestamp |
| pickup_zone_id | INTEGER | TLC zone ID for pickup |
| dropoff_zone_id | INTEGER | TLC zone ID for dropoff |
| dispatching_base_num | VARCHAR | TLC base license number |
| affiliated_base_num | VARCHAR | Affiliated base license |
| is_shared_ride | BOOLEAN | Whether shared ride |
| loaded_at | TIMESTAMP | When record was loaded |

### stg_taxi_zones

Taxi zone lookup reference.

| Column | Type | Description |
|--------|------|-------------|
| zone_id | INTEGER | Unique zone identifier |
| borough | VARCHAR | NYC borough name |
| zone_name | VARCHAR | Zone/neighborhood name |
| service_zone | VARCHAR | Yellow Zone, Boro Zone, Airports, etc. |
| loaded_at | TIMESTAMP | When record was loaded |

---

## Silver Layer (Intermediate)

### int_trips_unioned

All trip types with standardized schema.

| Column | Type | Description |
|--------|------|-------------|
| trip_id | VARCHAR | Deterministic ID |
| trip_type | VARCHAR | 'yellow', 'green', or 'fhv' |
| pickup_datetime | TIMESTAMP | Pickup timestamp |
| dropoff_datetime | TIMESTAMP | Dropoff timestamp |
| pickup_zone_id | INTEGER | Pickup zone ID |
| dropoff_zone_id | INTEGER | Dropoff zone ID |
| passenger_count | INTEGER | Passengers (null for FHV) |
| trip_distance | DOUBLE | Distance (null for FHV) |
| fare_amount | DOUBLE | Fare (null for FHV) |
| tip_amount | DOUBLE | Tip (null for FHV) |
| total_amount | DOUBLE | Total (null for FHV) |
| vendor_id | INTEGER | Vendor (null for FHV) |
| payment_type | INTEGER | Payment type (null for FHV) |
| loaded_at | TIMESTAMP | Load timestamp |

### int_trips_enriched

Trips enriched with zone information and calculated fields.

| Column | Type | Description |
|--------|------|-------------|
| *All columns from int_trips_unioned* | | |
| pickup_zone_name | VARCHAR | Pickup zone name |
| pickup_borough | VARCHAR | Pickup borough |
| pickup_service_zone | VARCHAR | Pickup service zone type |
| dropoff_zone_name | VARCHAR | Dropoff zone name |
| dropoff_borough | VARCHAR | Dropoff borough |
| dropoff_service_zone | VARCHAR | Dropoff service zone type |
| trip_duration_minutes | INTEGER | Duration in minutes |
| avg_speed_mph | DOUBLE | Average speed (mph) |
| tip_percentage | DOUBLE | Tip as % of fare |

### int_trips_validated

Clean trips with outliers and invalid records removed.

Same columns as `int_trips_enriched` with filters applied:
- Trip duration: 1-180 minutes
- Fare amount: $0-$1,000 (for metered trips)
- Distance: 0-200 miles (for metered trips)
- Average speed: < 100 mph
- Valid zone IDs (excludes Unknown/Outside NYC)

---

## Gold Layer (Marts)

### dim_zones

Zone dimension table.

| Column | Type | Description |
|--------|------|-------------|
| zone_id | INTEGER | Primary key |
| borough | VARCHAR | NYC borough |
| zone_name | VARCHAR | Zone name |
| service_zone | VARCHAR | Service classification |
| is_airport | BOOLEAN | True if airport zone |
| is_yellow_zone | BOOLEAN | True if Yellow Zone |
| is_nyc_borough | BOOLEAN | True if valid NYC borough |
| loaded_at | TIMESTAMP | Load timestamp |

### fct_daily_trips

Daily trip aggregations by borough and trip type.

| Column | Type | Description |
|--------|------|-------------|
| trip_date | DATE | Trip date |
| pickup_borough | VARCHAR | Pickup borough |
| trip_type | VARCHAR | 'yellow', 'green', or 'fhv' |
| total_trips | BIGINT | Number of trips |
| total_passengers | BIGINT | Total passengers |
| total_distance_miles | DOUBLE | Total distance |
| avg_distance_miles | DOUBLE | Average distance |
| total_fare | DOUBLE | Total fare revenue |
| avg_fare | DOUBLE | Average fare |
| total_tips | DOUBLE | Total tips |
| avg_tip_percentage | DOUBLE | Average tip % |
| avg_duration_minutes | DOUBLE | Average duration |
| updated_at | TIMESTAMP | Last update timestamp |

**Unique Key:** (trip_date, pickup_borough, trip_type)

### fct_zone_metrics

Zone-level pickup and dropoff metrics.

| Column | Type | Description |
|--------|------|-------------|
| zone_id | INTEGER | Zone ID (FK to dim_zones) |
| metric_date | DATE | Metric date |
| trip_type | VARCHAR | 'yellow', 'green', or 'fhv' |
| pickups | BIGINT | Trips starting in zone |
| dropoffs | BIGINT | Trips ending in zone |
| total_fare_from_zone | DOUBLE | Total fare from pickups |
| avg_fare_from_zone | DOUBLE | Average fare from pickups |
| avg_distance_from_zone | DOUBLE | Average distance from pickups |
| avg_duration_from_zone | DOUBLE | Average duration from pickups |
| updated_at | TIMESTAMP | Last update timestamp |

**Unique Key:** (zone_id, metric_date, trip_type)

---

## Reference Values

### Boroughs

| Borough | Description |
|---------|-------------|
| Manhattan | Yellow Zone primary area |
| Brooklyn | Boro Zone |
| Queens | Boro Zone + Airports |
| Bronx | Boro Zone |
| Staten Island | Boro Zone |
| EWR | Newark Airport (New Jersey) |
| Unknown | Zone ID 264 |
| N/A | Zone ID 265 (Outside NYC) |

### Service Zones

| Service Zone | Description |
|--------------|-------------|
| Yellow Zone | Yellow taxi primary pickup area (Manhattan) |
| Boro Zone | Outer borough areas |
| Airports | JFK, LaGuardia |
| EWR | Newark Airport |
| N/A | Unknown/Outside NYC |

### Payment Types

| Code | Description |
|------|-------------|
| 1 | Credit card |
| 2 | Cash |
| 3 | No charge |
| 4 | Dispute |
| 5 | Unknown |
| 6 | Voided trip |

### Rate Codes

| Code | Description |
|------|-------------|
| 1 | Standard rate |
| 2 | JFK |
| 3 | Newark |
| 4 | Nassau or Westchester |
| 5 | Negotiated fare |
| 6 | Group ride |
