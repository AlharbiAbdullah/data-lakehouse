{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ ref('taxi_zones') }}
),

staged as (
    select
        cast(LocationID as integer) as zone_id,
        Borough as borough,
        Zone as zone_name,
        service_zone,

        -- Metadata
        current_timestamp as loaded_at

    from source
)

select * from staged
