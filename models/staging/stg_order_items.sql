{{
config(
    materialized='incremental',
    unique_key='order_item_id',
    incremental_strategy='merge',
    on_schema_change='sync_all_columns'
)
}}

WITH source AS (
    SELECT
        CAST(id AS INT64) AS order_item_id,
        CAST(order_id AS INT64) AS order_id,
        CAST(user_id AS INT64) AS user_id,
        CAST(product_id AS INT64) AS product_id,
        INITCAP(TRIM(CAST(status AS STRING))) AS item_status,
        ROUND(CAST(sale_price AS NUMERIC), 2) AS sale_price,
        CAST(created_at AS TIMESTAMP) AS item_created_at,
        CAST(shipped_at AS TIMESTAMP) AS shipped_at,
        CAST(delivered_at AS TIMESTAMP) AS delivered_at,
        CAST(returned_at AS TIMESTAMP) AS returned_at
    FROM {{ source('thelook_ecommerce', 'order_items') }}

    {% if is_incremental() %}
    WHERE created_at > (SELECT MAX(item_created_at) FROM {{ this }})
    {% endif %}
),

deduped AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY order_item_id ORDER BY item_created_at DESC) AS row_num
    FROM source
)

SELECT
    order_item_id,
    order_id,
    user_id,
    product_id,
    item_status,
    sale_price,
    item_created_at,
    shipped_at,
    delivered_at,
    returned_at,
    CURRENT_TIMESTAMP() AS warehouse_created_at
FROM deduped
WHERE row_num = 1
