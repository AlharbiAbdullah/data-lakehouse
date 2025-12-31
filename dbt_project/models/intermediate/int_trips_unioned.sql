{{
    config(
        materialized='view'
    )
}}

with yellow_trips as (
    select
        trip_id,
        trip_type,
        pickup_datetime,
        dropoff_datetime,
        pickup_zone_id,
        dropoff_zone_id,
        passenger_count,
        trip_distance,
        fare_amount,
        extra,
        mta_tax,
        improvement_surcharge,
        tip_amount,
        tolls_amount,
        total_amount,
        vendor_id,
        rate_code_id,
        payment_type,
        loaded_at
    from {{ ref('stg_yellow_trips') }}
),

green_trips as (
    select
        trip_id,
        trip_type,
        pickup_datetime,
        dropoff_datetime,
        pickup_zone_id,
        dropoff_zone_id,
        passenger_count,
        trip_distance,
        fare_amount,
        extra,
        mta_tax,
        improvement_surcharge,
        tip_amount,
        tolls_amount,
        total_amount,
        vendor_id,
        rate_code_id,
        payment_type,
        loaded_at
    from {{ ref('stg_green_trips') }}
),

fhv_trips as (
    select
        trip_id,
        trip_type,
        pickup_datetime,
        dropoff_datetime,
        pickup_zone_id,
        dropoff_zone_id,
        -- FHV doesn't have these fields
        null as passenger_count,
        null as trip_distance,
        null as fare_amount,
        null as extra,
        null as mta_tax,
        null as improvement_surcharge,
        null as tip_amount,
        null as tolls_amount,
        null as total_amount,
        null as vendor_id,
        null as rate_code_id,
        null as payment_type,
        loaded_at
    from {{ ref('stg_fhv_trips') }}
),

unioned as (
    select * from yellow_trips
    union all
    select * from green_trips
    union all
    select * from fhv_trips
)

select * from unioned
