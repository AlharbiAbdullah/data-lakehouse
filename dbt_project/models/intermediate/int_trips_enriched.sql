{{
    config(
        materialized='view'
    )
}}

with trips as (
    select * from {{ ref('int_trips_unioned') }}
),

zones as (
    select * from {{ ref('stg_taxi_zones') }}
),

enriched as (
    select
        t.trip_id,
        t.trip_type,
        t.pickup_datetime,
        t.dropoff_datetime,
        t.pickup_zone_id,
        t.dropoff_zone_id,
        t.passenger_count,
        t.trip_distance,
        t.fare_amount,
        t.extra,
        t.mta_tax,
        t.improvement_surcharge,
        t.tip_amount,
        t.tolls_amount,
        t.total_amount,
        t.vendor_id,
        t.rate_code_id,
        t.payment_type,
        t.loaded_at,

        -- Pickup zone info
        pz.zone_name as pickup_zone_name,
        pz.borough as pickup_borough,
        pz.service_zone as pickup_service_zone,

        -- Dropoff zone info
        dz.zone_name as dropoff_zone_name,
        dz.borough as dropoff_borough,
        dz.service_zone as dropoff_service_zone,

        -- Calculated fields
        datediff('minute', t.pickup_datetime, t.dropoff_datetime) as trip_duration_minutes,

        -- Average speed (only when we have distance and duration)
        case
            when t.trip_distance > 0
                 and datediff('minute', t.pickup_datetime, t.dropoff_datetime) > 0
            then t.trip_distance / (datediff('minute', t.pickup_datetime, t.dropoff_datetime) / 60.0)
            else null
        end as avg_speed_mph,

        -- Tip percentage (only for credit card payments where tip is recorded)
        case
            when t.fare_amount > 0 and t.tip_amount is not null
            then (t.tip_amount / t.fare_amount) * 100
            else null
        end as tip_percentage

    from trips t
    left join zones pz on t.pickup_zone_id = pz.zone_id
    left join zones dz on t.dropoff_zone_id = dz.zone_id
)

select * from enriched
