{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw', 'green_tripdata') }}
),

staged as (
    select
        -- Deterministic trip ID
        {{ generate_trip_id(
            'lpep_pickup_datetime',
            'lpep_dropoff_datetime',
            'PULocationID',
            'DOLocationID',
            'fare_amount'
        ) }} as trip_id,

        -- Trip type identifier
        'green' as trip_type,

        -- Timestamps
        lpep_pickup_datetime as pickup_datetime,
        lpep_dropoff_datetime as dropoff_datetime,

        -- Locations
        PULocationID as pickup_zone_id,
        DOLocationID as dropoff_zone_id,

        -- Trip details
        cast(passenger_count as integer) as passenger_count,
        cast(trip_distance as double) as trip_distance,

        -- Fare components
        cast(fare_amount as double) as fare_amount,
        cast(extra as double) as extra,
        cast(mta_tax as double) as mta_tax,
        cast(improvement_surcharge as double) as improvement_surcharge,
        cast(tip_amount as double) as tip_amount,
        cast(tolls_amount as double) as tolls_amount,
        cast(total_amount as double) as total_amount,

        -- Payment info
        cast(VendorID as integer) as vendor_id,
        cast(RatecodeID as integer) as rate_code_id,
        store_and_fwd_flag,
        cast(payment_type as integer) as payment_type,

        -- Green taxi specific
        cast(trip_type as integer) as green_trip_type,

        -- Metadata
        current_timestamp as loaded_at

    from source
    where lpep_pickup_datetime is not null
      and lpep_dropoff_datetime is not null
)

select * from staged
