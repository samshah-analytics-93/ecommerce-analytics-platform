{% snapshot snp_users %}

{{
    config(
        target_schema='snapshots',
        unique_key='id',
        strategy='check',
        check_cols=['city', 'state', 'country', 'email'],
        invalidate_hard_deletes=True
    )
}}

/*
    SCD Type 2 snapshot of customer profile changes.

    Tracks changes to: city, state, country, email.
    Demographic fields (age, gender) and traffic_source are treated as
    immutable registration-time attributes and are NOT tracked here.

    Use cases:
    - Understand customer migration patterns (city/country changes)
    - Track email changes (may indicate account recovery or fraud)
    - Historical attribution: if a customer moves, their location at
      time of order can differ from their current location

    Strategy: `check` because the source has no updated_at column.
*/

SELECT
    id,
    first_name,
    last_name,
    email,
    age,
    gender,
    city,
    state,
    country,
    traffic_source,
    created_at
FROM {{ source('thelook_ecommerce', 'users') }}

{% endsnapshot %}
