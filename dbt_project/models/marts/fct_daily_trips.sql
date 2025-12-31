{{
    config(
        materialized='incremental',
        unique_key=['trip_date', 'pickup_borough', 'trip_type'],
        incremental_strategy='merge'
    )
}}

with trips as (
    select * from {{ ref('int_trips_validated') }}

    {% if is_incremental() %}
    -- 3-day lookback for late-arriving data
    where pickup_datetime >= (
        select dateadd('day', -3, max(trip_date))
        from {{ this }}
    )
    {% endif %}
),

daily_aggregates as (
    select
        cast(date_trunc('day', pickup_datetime) as date) as trip_date,
        pickup_borough,
        trip_type,

        -- Trip counts
        count(*) as total_trips,
        sum(case when passenger_count is not null then passenger_count else 0 end) as total_passengers,

        -- Distance metrics
        sum(coalesce(trip_distance, 0)) as total_distance_miles,
        avg(trip_distance) as avg_distance_miles,

        -- Fare metrics (only for yellow/green)
        sum(coalesce(fare_amount, 0)) as total_fare,
        avg(fare_amount) as avg_fare,
        sum(coalesce(tip_amount, 0)) as total_tips,
        avg(tip_percentage) as avg_tip_percentage,

        -- Duration metrics
        avg(trip_duration_minutes) as avg_duration_minutes,

        -- Metadata
        current_timestamp as updated_at

    from trips
    where pickup_borough is not null
    group by 1, 2, 3
)

select * from daily_aggregates
