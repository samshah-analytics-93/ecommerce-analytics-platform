{{
config(
    materialized='incremental',
    unique_key='product_id',
    incremental_strategy='merge',
    on_schema_change='sync_all_columns'
)
}}

WITH source AS (
    SELECT
        CAST(id AS INT64) AS product_id,
        TRIM(CAST(name AS STRING)) AS product_name,
        INITCAP(TRIM(CAST(brand AS STRING))) AS brand,
        INITCAP(TRIM(CAST(category AS STRING))) AS product_category,
        INITCAP(TRIM(CAST(department AS STRING))) AS department,
        UPPER(TRIM(CAST(sku AS STRING))) AS sku,
        ROUND(CAST(cost AS NUMERIC), 2) AS cost,
        ROUND(CAST(retail_price AS NUMERIC), 2) AS retail_price,
        CAST(distribution_center_id AS INT64) AS distribution_center_id
    FROM {{ source('thelook_ecommerce', 'products') }}
),

deduped AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY sku) AS row_num
    FROM source
)

SELECT
    product_id,
    product_name,
    brand,
    product_category,
    department,
    sku,
    cost,
    retail_price,
    distribution_center_id,
    CURRENT_TIMESTAMP() AS warehouse_created_at
FROM deduped
WHERE row_num = 1
