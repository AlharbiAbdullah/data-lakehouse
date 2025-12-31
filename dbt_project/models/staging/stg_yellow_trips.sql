{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw', 'yellow_tripdata') }}
),

with_base_hash as (
    select
        -- Base hash from key fields
        {{ generate_trip_id(
            'tpep_pickup_datetime',
            'tpep_dropoff_datetime',
            'PULocationID',
            'DOLocationID',
            'fare_amount',
            'trip_distance',
            'passenger_count'
        ) }} as base_hash,

        -- Trip type identifier
        'yellow' as trip_type,

        -- Timestamps
        tpep_pickup_datetime as pickup_datetime,
        tpep_dropoff_datetime as dropoff_datetime,

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

        -- Metadata
        current_timestamp as loaded_at

    from source
    where tpep_pickup_datetime is not null
      and tpep_dropoff_datetime is not null
),

staged as (
    select
        -- Unique trip ID: base_hash + row number for duplicates
        base_hash || '_' || cast(row_number() over (partition by base_hash order by pickup_datetime) as varchar) as trip_id,
        * exclude (base_hash)
    from with_base_hash
)

select * from staged
