{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw', 'fhv_tripdata') }}
),

staged as (
    select
        -- Deterministic trip ID (FHV doesn't have fare, use 0)
        {{ generate_trip_id(
            'pickup_datetime',
            'dropOff_datetime',
            'PULocationID',
            'DOLocationID',
            '0'
        ) }} as trip_id,

        -- Trip type identifier
        'fhv' as trip_type,

        -- Timestamps
        pickup_datetime,
        dropOff_datetime as dropoff_datetime,

        -- Locations
        PULocationID as pickup_zone_id,
        DOLocationID as dropoff_zone_id,

        -- FHV specific fields
        dispatching_base_num,
        Affiliated_base_number as affiliated_base_num,
        case
            when SR_Flag = 1 then true
            else false
        end as is_shared_ride,

        -- Metadata
        current_timestamp as loaded_at

    from source
    where pickup_datetime is not null
)

select * from staged
