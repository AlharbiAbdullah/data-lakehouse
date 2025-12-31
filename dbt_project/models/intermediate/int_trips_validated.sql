{{
    config(
        materialized='view'
    )
}}

with enriched as (
    select * from {{ ref('int_trips_enriched') }}
),

validated as (
    select *
    from enriched
    where
        -- Valid trip duration (between 1 minute and 3 hours)
        trip_duration_minutes > 0
        and trip_duration_minutes < 180

        -- For yellow/green: positive fare
        and (
            trip_type = 'fhv'
            or (fare_amount > 0 and fare_amount < 1000)
        )

        -- For yellow/green: reasonable distance
        and (
            trip_type = 'fhv'
            or (trip_distance >= 0 and trip_distance < 200)
        )

        -- For yellow/green: reasonable speed (< 100 mph average)
        and (
            trip_type = 'fhv'
            or avg_speed_mph is null
            or avg_speed_mph < 100
        )

        -- Valid zones (exclude unknown/outside NYC for analysis)
        and pickup_zone_id is not null
        and pickup_zone_id not in (264, 265)  -- Unknown, Outside of NYC
)

select * from validated
