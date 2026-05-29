{{
config(
    materialized='incremental',
    unique_key='user_id',
    incremental_strategy='merge',
    on_schema_change='sync_all_columns'
)
}}

WITH source AS (
    SELECT
        CAST(id AS INT64) AS user_id,
        -- PII: first_name excluded — contains personally identifiable information
        -- PII: last_name excluded — contains personally identifiable information
        -- PII: email excluded — contains personally identifiable information
        CAST(age AS INT64) AS age,
        INITCAP(TRIM(CAST(gender AS STRING))) AS gender,
        INITCAP(TRIM(CAST(country AS STRING))) AS country,
        INITCAP(TRIM(CAST(city AS STRING))) AS city,
        INITCAP(TRIM(CAST(state AS STRING))) AS state,
        -- PII: street_address excluded — contains personally identifiable information
        -- PII: postal_code excluded — contains personally identifiable information
        -- PII: latitude excluded — contains personally identifiable information
        -- PII: longitude excluded — contains personally identifiable information
        -- PII: user_geom excluded — contains personally identifiable information
        INITCAP(TRIM(CAST(traffic_source AS STRING))) AS acquisition_channel,
        CAST(created_at AS TIMESTAMP) AS user_created_at
    FROM {{ source('thelook_ecommerce', 'users') }}

    {% if is_incremental() %}
    WHERE created_at > (SELECT MAX(user_created_at) FROM {{ this }})
    {% endif %}
),

deduped AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY user_created_at DESC) AS row_num
    FROM source
)

SELECT
    user_id,
    age,
    gender,
    country,
    city,
    state,
    acquisition_channel,
    user_created_at,
    CURRENT_TIMESTAMP() AS warehouse_created_at
FROM deduped
WHERE row_num = 1
