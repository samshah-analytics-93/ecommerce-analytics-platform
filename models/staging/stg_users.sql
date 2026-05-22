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
        INITCAP(TRIM(CAST(first_name AS STRING))) AS first_name,
        INITCAP(TRIM(CAST(last_name AS STRING))) AS last_name,
        LOWER(TRIM(CAST(email AS STRING))) AS email,
        CAST(age AS INT64) AS age,
        INITCAP(TRIM(CAST(gender AS STRING))) AS gender,
        INITCAP(TRIM(CAST(country AS STRING))) AS country,
        INITCAP(TRIM(CAST(city AS STRING))) AS city,
        INITCAP(TRIM(CAST(state AS STRING))) AS state,
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
    first_name,
    last_name,
    email,
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
