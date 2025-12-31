{% macro generate_trip_id(pickup_datetime, dropoff_datetime, pickup_zone, dropoff_zone, fare_amount) %}
    md5(
        coalesce(cast({{ pickup_datetime }} as varchar), '') ||
        '|' ||
        coalesce(cast({{ dropoff_datetime }} as varchar), '') ||
        '|' ||
        coalesce(cast({{ pickup_zone }} as varchar), '') ||
        '|' ||
        coalesce(cast({{ dropoff_zone }} as varchar), '') ||
        '|' ||
        coalesce(cast({{ fare_amount }} as varchar), '')
    )
{% endmacro %}
