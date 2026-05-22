{{
config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='merge',
    on_schema_change='sync_all_columns'
)
}}

WITH source AS (
    SELECT
        CAST(order_id AS INT64) AS order_id,
        CAST(user_id AS INT64) AS user_id,
        INITCAP(TRIM(CAST(status AS STRING))) AS order_status,
        CAST(num_of_item AS INT64) AS item_count,
        CAST(created_at AS TIMESTAMP) AS order_created_at,
        CAST(shipped_at AS TIMESTAMP) AS shipped_at,
        CAST(delivered_at AS TIMESTAMP) AS delivered_at,
        CAST(returned_at AS TIMESTAMP) AS returned_at
    FROM {{ source('thelook_ecommerce', 'orders') }}

    {% if is_incremental() %}
    WHERE created_at > (SELECT MAX(order_created_at) FROM {{ this }})
    {% endif %}
),

deduped AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_created_at DESC) AS row_num
    FROM source
)

SELECT
    order_id,
    user_id,
    order_status,
    item_count,
    order_created_at,
    shipped_at,
    delivered_at,
    returned_at,
    CURRENT_TIMESTAMP() AS warehouse_created_at
FROM deduped
WHERE row_num = 1
