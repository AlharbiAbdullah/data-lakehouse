{% macro generate_trip_id(pickup_datetime, dropoff_datetime, pickup_zone, dropoff_zone, extra_field_1, extra_field_2, extra_field_3) %}
    md5(
        coalesce(cast({{ pickup_datetime }} as varchar), '') ||
        '|' ||
        coalesce(cast({{ dropoff_datetime }} as varchar), '') ||
        '|' ||
        coalesce(cast({{ pickup_zone }} as varchar), '') ||
        '|' ||
        coalesce(cast({{ dropoff_zone }} as varchar), '') ||
        '|' ||
        coalesce(cast({{ extra_field_1 }} as varchar), '') ||
        '|' ||
        coalesce(cast({{ extra_field_2 }} as varchar), '') ||
        '|' ||
        coalesce(cast({{ extra_field_3 }} as varchar), '')
    )
{% endmacro %}
