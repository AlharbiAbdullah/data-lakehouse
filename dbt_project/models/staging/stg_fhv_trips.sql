{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw', 'fhv_tripdata') }}
),

with_base_hash as (
    select
        -- Base hash from key fields (FHV has base numbers instead of fare)
        {{ generate_trip_id(
            'pickup_datetime',
            'dropOff_datetime',
            'PULocationID',
            'DOLocationID',
            'dispatching_base_num',
            'Affiliated_base_number',
            'SR_Flag'
        ) }} as base_hash,

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
),

staged as (
    select
        -- Unique trip ID: base_hash + row number for duplicates
        base_hash || '_' || cast(row_number() over (partition by base_hash order by pickup_datetime) as varchar) as trip_id,
        * exclude (base_hash)
    from with_base_hash
)

select * from staged
