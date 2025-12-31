{{
    config(
        materialized='incremental',
        unique_key=['zone_id', 'metric_date', 'trip_type'],
        incremental_strategy='merge'
    )
}}

with trips as (
    select * from {{ ref('int_trips_validated') }}

    {% if is_incremental() %}
    -- 3-day lookback for late-arriving data
    where pickup_datetime >= (
        select dateadd('day', -3, max(metric_date))
        from {{ this }}
    )
    {% endif %}
),

-- Pickup metrics by zone
pickup_metrics as (
    select
        pickup_zone_id as zone_id,
        cast(date_trunc('day', pickup_datetime) as date) as metric_date,
        trip_type,
        count(*) as pickups,
        sum(coalesce(fare_amount, 0)) as total_fare_from_zone,
        avg(fare_amount) as avg_fare_from_zone,
        avg(trip_distance) as avg_distance_from_zone,
        avg(trip_duration_minutes) as avg_duration_from_zone
    from trips
    where pickup_zone_id is not null
    group by 1, 2, 3
),

-- Dropoff metrics by zone
dropoff_metrics as (
    select
        dropoff_zone_id as zone_id,
        cast(date_trunc('day', pickup_datetime) as date) as metric_date,
        trip_type,
        count(*) as dropoffs
    from trips
    where dropoff_zone_id is not null
    group by 1, 2, 3
),

-- Combine pickup and dropoff metrics
combined as (
    select
        coalesce(p.zone_id, d.zone_id) as zone_id,
        coalesce(p.metric_date, d.metric_date) as metric_date,
        coalesce(p.trip_type, d.trip_type) as trip_type,
        coalesce(p.pickups, 0) as pickups,
        coalesce(d.dropoffs, 0) as dropoffs,
        p.total_fare_from_zone,
        p.avg_fare_from_zone,
        p.avg_distance_from_zone,
        p.avg_duration_from_zone,
        current_timestamp as updated_at
    from pickup_metrics p
    full outer join dropoff_metrics d
        on p.zone_id = d.zone_id
        and p.metric_date = d.metric_date
        and p.trip_type = d.trip_type
)

select * from combined
where zone_id is not null
