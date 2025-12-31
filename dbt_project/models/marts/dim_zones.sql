{{
    config(
        materialized='table'
    )
}}

with zones as (
    select * from {{ ref('stg_taxi_zones') }}
),

final as (
    select
        zone_id,
        borough,
        zone_name,
        service_zone,

        -- Derived flags
        case
            when service_zone = 'Airports' then true
            when zone_name like '%Airport%' then true
            else false
        end as is_airport,

        case
            when service_zone = 'Yellow Zone' then true
            else false
        end as is_yellow_zone,

        case
            when borough in ('Manhattan', 'Brooklyn', 'Queens', 'Bronx', 'Staten Island') then true
            else false
        end as is_nyc_borough,

        loaded_at

    from zones
    where zone_id not in (264, 265)  -- Exclude Unknown and Outside NYC
)

select * from final
